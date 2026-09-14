package com.sih.voicebridge.pipeline

import android.content.Context
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.lang.reflect.Constructor
import java.lang.reflect.Field
import org.json.JSONException
import org.json.JSONObject

private const val TAG = "SIH_STT"

data class SttResult(
        val partial: String?,
        val finalText: String?,
        val metrics: Map<String, Any> = emptyMap(),
        val error: String? = null,
)

interface StreamingSttSession {
    val metrics: Map<String, Any>
        get() = emptyMap()
    fun acceptAudio(samples: ShortArray, sampleRate: Int): String?
    fun finalizeText(): String
    fun close() {}
}

interface StreamingSttBackend {
    val backendName: String
    val recognitionAvailable: Boolean
        get() = true
    fun prepare() {}
    fun createSession(languageCode: String): StreamingSttSession
    fun close() {}
}

interface ModelSizedSttBackend {
    fun modelSizeBytes(): Long?
}

class FallbackSttBackend : StreamingSttBackend, ModelSizedSttBackend {
    override val backendName: String = "fallback_unavailable"
    override val recognitionAvailable = false

    override fun createSession(languageCode: String): StreamingSttSession {
        return FallbackSttSession(languageCode)
    }

    override fun modelSizeBytes(): Long? {
        return null
    }
}

class FallbackSttSession(
        private val languageCode: String,
) : StreamingSttSession {
    override val metrics: Map<String, Any>
        get() =
                mapOf(
                        "fallback" to true,
                        "recognitionValid" to false,
                        "decodeCalls" to 0,
                )
    override fun acceptAudio(samples: ShortArray, sampleRate: Int): String? = null
    override fun finalizeText(): String = ""
}

data class SttModelSpec(
        val languageCode: String,
        val type: String,
        val modelAssetPath: String?,
        val tokensAssetPath: String?,
        val encoderAssetPath: String?,
        val decoderAssetPath: String?,
        val joinerAssetPath: String?,
)

data class ResolvedSttModel(
        val languageCode: String,
        val type: String,
        val modelFile: File?,
        val tokensFile: File?,
        val encoderFile: File?,
        val decoderFile: File?,
        val joinerFile: File?,
)

class SttAssetResolver(
        private val context: Context,
        private val onStatus: (String) -> Unit,
) {
    companion object {
        private const val FLUTTER_ASSET_PREFIX = "flutter_assets/"
        private const val MANIFEST_RELATIVE_PATH = "assets/models/stt/model_manifest.json"
    }

    private var manifestCache: Map<String, SttModelSpec>? = null
    private var manifestLoaded = false

    fun resolve(languageCode: String, engineType: String = "conformer"): ResolvedSttModel? {
        val manifest = loadManifest()
        if (manifest.isEmpty()) {
            return null
        }

        val normEngine = engineType.lowercase()
        val languageKey = languageCode.lowercase()

        val spec =
                manifest["$normEngine:$languageKey"]
                        ?: manifest["$normEngine:all"] ?: manifest[languageKey]

        if (spec == null) {
            onStatus(
                    "No STT model spec found for '$languageCode' (engine: $engineType) in model_manifest.json"
            )
            return null
        }

        val modelFile = spec.modelAssetPath?.let { copyAssetToAppStorage(it) }
        val tokensFile = copyOptional(spec.tokensAssetPath)
        val encoderFile = copyOptional(spec.encoderAssetPath)
        val decoderFile = copyOptional(spec.decoderAssetPath)
        val joinerFile = copyOptional(spec.joinerAssetPath)

        if (spec.type.lowercase() == "whisper") {
            if (encoderFile == null || decoderFile == null) {
                onStatus("Missing Whisper model assets (encoder/decoder)")
                return null
            }
        } else {
            if (modelFile == null && encoderFile == null) {
                onStatus("Missing STT model asset for ${spec.languageCode}")
                return null
            }
        }

        return ResolvedSttModel(
                languageCode = spec.languageCode,
                type = spec.type,
                modelFile = modelFile,
                tokensFile = tokensFile,
                encoderFile = encoderFile,
                decoderFile = decoderFile,
                joinerFile = joinerFile,
        )
    }

    private fun loadManifest(): Map<String, SttModelSpec> {
        if (manifestLoaded) {
            return manifestCache.orEmpty()
        }

        manifestLoaded = true
        val manifestAssetPath = "$FLUTTER_ASSET_PREFIX$MANIFEST_RELATIVE_PATH"
        val payload =
                try {
                    context.assets.open(manifestAssetPath).bufferedReader().use { it.readText() }
                } catch (_: Throwable) {
                    onStatus("STT manifest not found at $MANIFEST_RELATIVE_PATH")
                    manifestCache = emptyMap()
                    return manifestCache.orEmpty()
                }

        val parsed =
                try {
                    parseManifest(payload)
                } catch (error: JSONException) {
                    onStatus("Invalid STT manifest JSON: ${error.message}")
                    emptyMap()
                }

        manifestCache = parsed
        return parsed
    }

    @Throws(JSONException::class)
    private fun parseManifest(payload: String): Map<String, SttModelSpec> {
        val root = JSONObject(payload)
        val table = mutableMapOf<String, SttModelSpec>()

        val enginesNode = root.optJSONObject("engines")
        if (enginesNode != null) {
            val engineKeys = enginesNode.keys()
            while (engineKeys.hasNext()) {
                val engineName = engineKeys.next().lowercase()
                val engineObj = enginesNode.optJSONObject(engineName) ?: continue
                val languagesNode = engineObj.optJSONObject("languages") ?: continue
                val langKeys = languagesNode.keys()
                while (langKeys.hasNext()) {
                    val langCode = langKeys.next().lowercase()
                    val specNode = languagesNode.optJSONObject(langCode) ?: continue
                    val spec = parseSpec(langCode, specNode) ?: continue
                    table["$engineName:$langCode"] = spec
                }
            }
        }

        val languagesNode =
                if (root.has("languages")) {
                    root.getJSONObject("languages")
                } else {
                    null
                }

        if (languagesNode != null) {
            val keys = languagesNode.keys()
            while (keys.hasNext()) {
                val languageCode = keys.next().lowercase()
                val specNode = languagesNode.optJSONObject(languageCode) ?: continue
                val spec = parseSpec(languageCode, specNode) ?: continue
                table[languageCode] = spec
            }
        }

        return table
    }

    private fun parseSpec(languageCode: String, node: JSONObject): SttModelSpec? {
        val type =
                pickFirstNonBlank(
                        node.optString("type", ""),
                        node.optString("modelType", ""),
                )
                        ?: "nemo_ctc"

        val modelAssetPath =
                pickFirstNonBlank(
                        node.optString("model", ""),
                        node.optString("modelAsset", ""),
                )
        val encoderAssetPath =
                pickFirstNonBlank(
                        node.optString("encoder", ""),
                        node.optString("encoderAsset", ""),
                )
        val decoderAssetPath =
                pickFirstNonBlank(
                        node.optString("decoder", ""),
                        node.optString("decoderAsset", ""),
                )
        val joinerAssetPath =
                pickFirstNonBlank(
                        node.optString("joiner", ""),
                        node.optString("joinerAsset", ""),
                )
        val tokensAssetPath =
                pickFirstNonBlank(
                        node.optString("tokens", ""),
                        node.optString("tokensAsset", ""),
                )

        if (type.lowercase() == "whisper") {
            if (encoderAssetPath.isNullOrBlank() || decoderAssetPath.isNullOrBlank()) {
                return null
            }
        } else if (modelAssetPath.isNullOrBlank() && encoderAssetPath.isNullOrBlank()) {
            return null
        }

        return SttModelSpec(
                languageCode = languageCode.lowercase(),
                type = type,
                modelAssetPath = modelAssetPath,
                tokensAssetPath = tokensAssetPath,
                encoderAssetPath = encoderAssetPath,
                decoderAssetPath = decoderAssetPath,
                joinerAssetPath = joinerAssetPath,
        )
    }

    private fun copyOptional(assetPath: String?): File? {
        if (assetPath.isNullOrBlank()) {
            return null
        }
        return copyAssetToAppStorage(assetPath)
    }

    private fun copyAssetToAppStorage(assetPath: String): File? {
        val normalizedAssetPath = assetPath.trim().removePrefix("/")
        val flutterAssetPath = "$FLUTTER_ASSET_PREFIX$normalizedAssetPath"

        val target = File(context.filesDir, "stt_models/$normalizedAssetPath")
        if (target.exists() && target.length() > 0L) {
            return target
        }

        try {
            target.parentFile?.mkdirs()
            context.assets.open(flutterAssetPath).use { input ->
                FileOutputStream(target).use { output -> input.copyTo(output) }
            }
            return target
        } catch (error: Throwable) {
            onStatus("Failed copying STT asset $normalizedAssetPath: ${error.message}")
            return null
        }
    }

    private fun pickFirstNonBlank(vararg values: String?): String? {
        for (value in values) {
            if (!value.isNullOrBlank()) {
                return value
            }
        }
        return null
    }
}

class SherpaOnnxBackendFactory(
        private val context: Context,
        private val onStatus: (String) -> Unit,
) {
    private val assetResolver = SttAssetResolver(context, onStatus)
    private var classProbeDone = false
    private var sherpaAvailable = false
    private var reportedMissingLibrary = false
    private var activeLanguageCode: String = "en"

    // fun createBackend(languageCode: String): StreamingSttBackend? {
    //     if (!isSherpaAvailable()) {
    //         if (!reportedMissingLibrary) {
    //             onStatus("Sherpa-ONNX classes unavailable. Add Sherpa dependency, then restart
    // app.")
    //             reportedMissingLibrary = true
    //         }
    //         return null
    //     }

    //     val model = assetResolver.resolve(languageCode)
    //     if (model == null) {
    //         onStatus("No usable STT model found for '$languageCode'. Falling back.")
    //         return null
    //     }

    //     return try {
    //         SherpaOnnxReflectiveBackend(context, model, onStatus)
    //     } catch (error: Throwable) {
    //         onStatus("Sherpa backend init failed: ${error.message}")
    //         null
    //     }
    // }

    fun createBackend(
            languageCode: String,
            engineType: String = "conformer"
    ): StreamingSttBackend? {
        Log.e("SIH_STT", "========== STT BACKEND START ==========")
        Log.e("SIH_STT", "Language: $languageCode, Engine: $engineType")
        activeLanguageCode = languageCode

        if (!isSherpaAvailable()) {
            Log.e("SIH_STT", "❌ Sherpa classes NOT available")
            onStatus("STT: Sherpa classes unavailable")
            return null
        }

        Log.e("SIH_STT", "✅ Sherpa classes are available")

        val model = assetResolver.resolve(languageCode, engineType)

        if (model == null) {
            Log.e("SIH_STT", "❌ Model resolution FAILED for: $languageCode (engine: $engineType)")
            onStatus("STT: Model resolution failed for $languageCode ($engineType)")
            return null
        }

        Log.e("SIH_STT", "✅ Model resolved: type=${model.type}")
        model.modelFile?.let {
            Log.e("SIH_STT", "Model path: ${it.absolutePath}, size: ${it.length()}")
        }
        model.encoderFile?.let {
            Log.e("SIH_STT", "Encoder path: ${it.absolutePath}, size: ${it.length()}")
        }
        model.decoderFile?.let {
            Log.e("SIH_STT", "Decoder path: ${it.absolutePath}, size: ${it.length()}")
        }
        Log.e("SIH_STT", "Tokens path: ${model.tokensFile?.absolutePath}")

        return try {
            Log.e("SIH_STT", "Creating SherpaOnnxReflectiveBackend...")

            val backend =
                    SherpaOnnxReflectiveBackend(
                            context = context,
                            model = model,
                            activeLanguageCode = languageCode,
                            onStatus = onStatus,
                    )

            Log.e("SIH_STT", "✅ Sherpa backend CREATED successfully: ${backend.backendName}")
            Log.e("SIH_STT", "========== STT BACKEND SUCCESS ==========")

            onStatus("STT backend active: ${backend.backendName}")

            backend
        } catch (error: Throwable) {
            Log.e(
                    "SIH_STT",
                    "❌ Sherpa backend creation FAILED",
                    error,
            )

            onStatus("STT backend failed: " + "${error.javaClass.simpleName}: ${error.message}")

            null
        }
    }

    private fun isSherpaAvailable(): Boolean {
        if (classProbeDone) {
            return sherpaAvailable
        }

        classProbeDone = true

        sherpaAvailable =
                try {
                    Log.e("SIH_STT", "Checking Sherpa Java classes...")

                    Class.forName("com.k2fsa.sherpa.onnx.OfflineRecognizer")

                    Log.e("SIH_STT", "✅ OfflineRecognizer found")

                    Class.forName("com.k2fsa.sherpa.onnx.OfflineRecognizerConfig")

                    Log.e("SIH_STT", "✅ OfflineRecognizerConfig found")

                    true
                } catch (error: Throwable) {
                    Log.e(
                            "SIH_STT",
                            "❌ Sherpa class check FAILED",
                            error,
                    )

                    false
                }

        return sherpaAvailable
    }
}

class SherpaOnnxReflectiveBackend(
        private val context: Context,
        private val model: ResolvedSttModel,
        private val activeLanguageCode: String = "en",
        private val onStatus: (String) -> Unit,
) : StreamingSttBackend, ModelSizedSttBackend {
    override val backendName: String = "sherpa_${model.type}_${model.languageCode}"

    private val recognizerDelegate = lazy {
        val recognizerConfig =
                buildRecognizerConfig(model)
                        ?: throw IllegalStateException("Unable to build Sherpa recognizer config")
        createRecognizer(recognizerConfig)
    }
    private val recognizer: Any
        get() = recognizerDelegate.value
    private val apiDelegate = lazy { OfflineRecognizerApi(recognizer) }
    private var released = false

    override fun prepare() {
        check(!released) { "Sherpa backend has been released" }
        apiDelegate.value
    }

    override fun createSession(languageCode: String): StreamingSttSession {
        if (model.type.lowercase() != "whisper" &&
                        languageCode.lowercase() != model.languageCode.lowercase()
        ) {
            throw IllegalStateException(
                    "Sherpa backend prepared for ${model.languageCode}, requested $languageCode",
            )
        }

        onStatus("Sherpa STT session started (${model.type}, ${model.languageCode})")
        return SherpaOnnxReflectiveSession(recognizer, stream, model.type.lowercase() == "whisper")
    }

    override fun close() {
        if (!released && recognizerDelegate.isInitialized()) {
            released = true
            recognizer.javaClass.getMethod("release").invoke(recognizer)
        }
    }

    override fun modelSizeBytes(): Long? {
        val files =
                listOf(
                        model.modelFile,
                        model.tokensFile,
                        model.encoderFile,
                        model.decoderFile,
                        model.joinerFile,
                )

        var bytes = 0L
        for (file in files) {
            if (file != null && file.exists()) {
                bytes += file.length()
            }
        }

        return if (bytes > 0L) bytes else null
    }

    private fun createRecognizer(recognizerConfig: Any): Any {
        Log.e(TAG, "Recognizer model is being loaded from filesystem")

        val modelDesc =
                model.modelFile?.absolutePath
                        ?: "encoder=${model.encoderFile?.absolutePath}, decoder=${model.decoderFile?.absolutePath}"
        Log.e(TAG, "Model: $modelDesc")

        Log.e(TAG, "Tokens: ${model.tokensFile?.absolutePath}")
        val recognizerClass = Class.forName("com.k2fsa.sherpa.onnx.OfflineRecognizer")

        val constructors = recognizerClass.constructors.sortedBy { it.parameterCount }
        for (constructor in constructors) {
            val instance = tryConstructRecognizer(constructor, recognizerConfig)
            if (instance != null) {
                return instance
            }
        }

        val factoryCreated =
                invokeBestMatch(
                        target = recognizerClass,
                        methodNames = listOf("create", "fromConfig"),
                        args = listOf(recognizerConfig),
                        staticOnly = true,
                )
        if (factoryCreated != null) {
            return factoryCreated
        }

        throw IllegalStateException("No compatible OfflineRecognizer constructor found")
    }

    private fun tryConstructRecognizer(
            constructor: Constructor<*>,
            recognizerConfig: Any,
    ): Any? {

        val params = constructor.parameterTypes

        Log.e("SIH_STT", "Trying constructor: $constructor")

        Log.e("SIH_STT", "Parameter count: ${params.size}")

        val args = mutableListOf<Any?>()

        for (param in params) {

            Log.e("SIH_STT", "Parameter type: ${param.name}")

            when {

                // OfflineRecognizerConfig
                param.isAssignableFrom(recognizerConfig.javaClass) -> {

                    Log.e("SIH_STT", " -> Using OfflineRecognizerConfig")

                    args.add(recognizerConfig)
                }

                // IMPORTANT:
                // Our models are loaded from absolute filesystem paths.
                // Therefore AssetManager MUST be null.
                param.name == "android.content.res.AssetManager" -> {

                    Log.e("SIH_STT", " -> Using NULL AssetManager because model paths are absolute")

                    args.add(null)
                }

                // Android Context, if required by this constructor.
                param.isAssignableFrom(Context::class.java) -> {

                    Log.e("SIH_STT", " -> Using Android Context")

                    args.add(context)
                }
                else -> {

                    Log.e("SIH_STT", " -> ❌ Unsupported constructor parameter: ${param.name}")

                    return null
                }
            }
        }

        return try {

            constructor.isAccessible = true

            Log.e("SIH_STT", "Invoking constructor...")

            val instance = constructor.newInstance(*args.toTypedArray())

            Log.e("SIH_STT", "✅ Constructor invocation succeeded")

            instance
        } catch (error: Throwable) {

            Log.e("SIH_STT", "❌ Constructor invocation FAILED", error)

            null
        }
    }

    private fun buildRecognizerConfig(model: ResolvedSttModel): Any? {
        val recognizerConfigClass =
                classOrNull("com.k2fsa.sherpa.onnx.OfflineRecognizerConfig") ?: return null
        val modelConfigClass =
                classOrNull("com.k2fsa.sherpa.onnx.OfflineModelConfig") ?: return null

        val recognizerConfig = instantiate(recognizerConfigClass) ?: return null
        val modelConfig = instantiate(modelConfigClass) ?: return null

        configureModelConfig(modelConfig, model)
        setProperty(recognizerConfig, listOf("modelConfig", "offlineModelConfig"), modelConfig)
        // Hotwords require modified_beam_search. Whisper only supports greedy_search in
        // Sherpa-ONNX.
        val isWhisper = model.type.lowercase() == "whisper"
        if (isWhisper) {
            setProperty(recognizerConfig, listOf("decodingMethod"), "greedy_search")
            setProperty(recognizerConfig, listOf("maxActivePaths"), 1)
        } else {
            setProperty(recognizerConfig, listOf("decodingMethod"), "modified_beam_search")
            setProperty(recognizerConfig, listOf("maxActivePaths"), 4)
            // Penalize blank emissions to reduce deletion errors (dropped syllables)
            setProperty(recognizerConfig, listOf("blankPenalty", "blank_penalty"), 1.2f)
        }

        val featureConfig =
                classOrNull("com.k2fsa.sherpa.onnx.FeatureConfig")?.let { instantiate(it) }
        if (featureConfig != null) {
            setProperty(featureConfig, listOf("sampleRate"), 16000)
            setProperty(featureConfig, listOf("featureDim", "numBins"), 80)
            setProperty(recognizerConfig, listOf("featConfig", "featureConfig"), featureConfig)
        }

        // Hotwords boosting for tactical emergency keywords (CTC/Transducer only)
        if (!isWhisper) {
            val hotwordsFile = ensureEmergencyHotwordsFile()
            if (hotwordsFile != null && hotwordsFile.exists()) {
                setProperty(
                        recognizerConfig,
                        listOf("hotwordsFile", "hotwords_file"),
                        hotwordsFile.absolutePath
                )
                setProperty(recognizerConfig, listOf("hotwordsScore", "hotwords_score"), 1.5f)
            }
        }

        return recognizerConfig
    }

    private fun ensureEmergencyHotwordsFile(): File? {
        return try {
            val file = File(context.filesDir, "emergency_hotwords.txt")
            val hotwords =
                    listOf(
                            // English
                            "emergency",
                            "sector",
                            "doctor",
                            "police",
                            "ambulance",
                            "help",
                            "assistance",
                            "evacuate",
                            "injured",
                            "fire",
                            "hospital",
                            "danger",
                            "medical",
                            "rescue",
                            "alert",
                            // Hindi
                            "\u0906\u092A\u0924\u0915\u093E\u0932",
                            "\u0921\u0949\u0915\u094D\u091F\u0930",
                            "\u092A\u0941\u0932\u093F\u0938",
                            "\u090F\u092E\u094D\u092C\u0941\u0932\u0947\u0902\u0938",
                            "\u092E\u0926\u0926",
                            "\u0905\u0938\u094D\u092A\u0924\u093E\u0932",
                            "\u0916\u0924\u0930\u093E",
                            "\u0906\u0917",
                            "\u092C\u091A\u093E\u0935",
                            "\u0918\u093E\u092F\u0932",
                            // Gujarati
                            "\u0A95\u0A9F\u0ACB\u0A95\u0A9F\u0AC0",
                            "\u0AA1\u0ACB\u0A95\u0ACD\u0A9F\u0AB0",
                            "\u0AAA\u0ACB\u0AB2\u0AC0\u0AB8",
                            "\u0AAE\u0AA6\u0AA6",
                            "\u0AB9\u0ACB\u0AB8\u0ACD\u0AAA\u0ABF\u0A9F\u0AB2",
                            // Marathi
                            "\u0906\u0923\u0940\u092C\u093E\u0923\u0940",
                            "\u0921\u0949\u0915\u094D\u091F\u0930",
                            "\u092A\u094B\u0932\u0940\u0938",
                            "\u092E\u0926\u0924",
                            "\u0930\u0941\u0917\u094D\u0923\u093E\u0932\u092F",
                            // Tamil
                            "\u0B85\u0BB5\u0B9A\u0BB0\u0BAE\u0BCD",
                            "\u0BAE\u0BB0\u0BC1\u0BA4\u0BCD\u0BA4\u0BC1\u0BB5\u0BB0\u0BCD",
                            "\u0B95\u0BBE\u0BB5\u0BB2\u0BCD",
                            "\u0B89\u0BA4\u0BB5\u0BBF",
                            "\u0BAE\u0BB0\u0BC1\u0BA4\u0BCD\u0BA4\u0BC1\u0BB5\u0BAE\u0BA9\u0BC8",
                            // Telugu
                            "\u0C05\u0C24\u0C4D\u0C2F\u0C35\u0C38\u0C30\u0C02",
                            "\u0C21\u0C3E\u0C15\u0C4D\u0C1F\u0C30\u0C4D",
                            "\u0C2A\u0C4B\u0C32\u0C40\u0C38\u0C41",
                            "\u0C38\u0C39\u0C3E\u0C2F\u0C02",
                            "\u0C06\u0C38\u0C41\u0C2A\u0C24\u0C4D\u0C30\u0C3F",
                            // Bengali
                            "\u099C\u09B0\u09C1\u09B0\u09BF",
                            "\u09A1\u09BE\u0995\u09CD\u09A4\u09BE\u09B0",
                            "\u09AA\u09C1\u09B2\u09BF\u09B6",
                            "\u09B8\u09BE\u09B9\u09BE\u09AF\u09CD\u09AF",
                            "\u09B9\u09BE\u09B8\u09AA\u09BE\u09A4\u09BE\u09B2",
                            // Kannada
                            "\u0CA4\u0CC1\u0CB0\u0CCD\u0CA4\u0CC1",
                            "\u0CB5\u0CC8\u0CA6\u0CCD\u0CAF\u0CB0\u0CC1",
                            "\u0CAA\u0CCA\u0CB2\u0CC0\u0CB8\u0CCD",
                            "\u0CB8\u0CB9\u0CBE\u0CAF",
                            "\u0C86\u0CB8\u0CCD\u0CAA\u0CA4\u0CCD\u0CB0\u0CC6",
                            // Malayalam
                            "\u0D05\u0D1F\u0D3F\u0D2F\u0D28\u0D4D\u0D24\u0D30\u0D02",
                            "\u0D21\u0D4B\u0D15\u0D4D\u0D1F\u0D7C",
                            "\u0D2A\u0D4B\u0D32\u0D40\u0D38\u0D4D",
                            "\u0D38\u0D39\u0D3E\u0D2F\u0D02",
                            "\u0D06\u0D36\u0D41\u0D2A\u0D24\u0D4D\u0D30\u0D3F",
                            // Odia
                            "\u0B1C\u0B30\u0B41\u0B30\u0B40",
                            "\u0B21\u0B3E\u0B15\u0B4D\u0B24\u0B30",
                            "\u0B2A\u0B4B\u0B32\u0B3F\u0B38",
                            "\u0B38\u0B3E\u0B39\u0B3E\u0B2F\u0B4D\u0B2F",
                            "\u0B21\u0B3E\u0B15\u0B4D\u0B24\u0B30\u0B16\u0B3E\u0B28\u0B3E",
                    )
            file.writeText(hotwords.joinToString("\n"))
            file
        } catch (_: Throwable) {
            null
        }
    }

    private fun configureModelConfig(modelConfig: Any, model: ResolvedSttModel) {
        requireProperty(modelConfig, listOf("numThreads"), 2)
        requireProperty(modelConfig, listOf("provider"), "cpu")
        requireProperty(modelConfig, listOf("debug"), false)

        when (model.type.lowercase()) {
            "transducer" -> configureTransducerModel(modelConfig, model)
            "whisper" -> configureWhisperModel(modelConfig, model)
            else -> configureNemoCtcModel(modelConfig, model)
        }
    }

    private fun configureWhisperModel(modelConfig: Any, model: ResolvedSttModel) {
        val whisperClass = classOrNull("com.k2fsa.sherpa.onnx.OfflineWhisperModelConfig") ?: return

        val whisper = instantiate(whisperClass) ?: return
        setProperty(whisper, listOf("encoder", "encoderPath"), model.encoderFile?.absolutePath)
        setProperty(whisper, listOf("decoder", "decoderPath"), model.decoderFile?.absolutePath)
        // Use the user's selected language instead of hardcoding "en".
        // Whisper supports: en, hi, gu, mr, kn, ml, ta, te, bn, or
        val whisperLang =
                if (model.languageCode == "all" || model.languageCode.isBlank()) {
                    activeLanguageCode
                } else {
                    model.languageCode
                }
        setProperty(whisper, listOf("language"), whisperLang)
        setProperty(whisper, listOf("task"), "transcribe")
        setProperty(whisper, listOf("tailPaddings"), -1)

        if (model.tokensFile != null) {
            setProperty(modelConfig, listOf("tokens", "tokensPath"), model.tokensFile.absolutePath)
        }

        setProperty(modelConfig, listOf("whisper"), whisper)
        setProperty(modelConfig, listOf("modelType"), "whisper")
    }

    private fun configureNemoCtcModel(modelConfig: Any, model: ResolvedSttModel) {
        val nemoClass =
                classOrNull("com.k2fsa.sherpa.onnx.OfflineNemoEncDecCtcModelConfig")
                        ?: error("Sherpa NeMo CTC configuration is unavailable")

        val nemoConfig =
                instantiate(nemoClass) ?: error("Cannot create Sherpa NeMo CTC configuration")

        // NeMo CTC model path
        requireProperty(nemoConfig, listOf("model"), model.modelFile?.absolutePath ?: "")

        // IMPORTANT:
        // OfflineModelConfig uses "nemo", not "nemoCtc"
        requireProperty(modelConfig, listOf("nemo", "nemoCtc"), nemoConfig)

        // tokens.txt belongs directly to OfflineModelConfig
        val tokensFile = model.tokensFile ?: error("NeMo CTC tokens are missing")
        requireProperty(modelConfig, listOf("tokens", "tokensPath"), tokensFile.absolutePath)

        // Tell Sherpa explicitly that this is a NeMo CTC model.
        requireProperty(modelConfig, listOf("modelType"), "nemo_ctc")
    }

    private fun configureTransducerModel(modelConfig: Any, model: ResolvedSttModel) {
        val transducerClass =
                classOrNull("com.k2fsa.sherpa.onnx.OfflineTransducerModelConfig") ?: return

        val transducer = instantiate(transducerClass) ?: return
        setProperty(transducer, listOf("encoder", "encoderPath"), model.encoderFile?.absolutePath)
        setProperty(transducer, listOf("decoder", "decoderPath"), model.decoderFile?.absolutePath)
        setProperty(transducer, listOf("joiner", "joinerPath"), model.joinerFile?.absolutePath)

        if (model.tokensFile != null) {
            setProperty(transducer, listOf("tokens", "tokensPath"), model.tokensFile.absolutePath)
            setProperty(modelConfig, listOf("tokens", "tokensPath"), model.tokensFile.absolutePath)
        }

        setProperty(modelConfig, listOf("transducer"), transducer)
    }
}

class SherpaOnnxReflectiveSession(
        private val recognizer: Any,
        private val stream: Any,
        private val isWhisper: Boolean = false,
) : StreamingSttSession {
    private var frameCounter = 0
    private var lastText = ""
    private val isDecodingPartial = java.util.concurrent.atomic.AtomicBoolean(false)
    private val partialExecutor = java.util.concurrent.Executors.newSingleThreadExecutor()

    override fun acceptAudio(samples: ShortArray, sampleRate: Int): String? {
        val accepted = acceptWaveform(samples, sampleRate)
        if (!accepted) {
            return null
        }

        // Run partial decode asynchronously on background worker.
        // NEVER run decodeOnce() synchronously on the audio capture thread!
        frameCounter += 1
        val throttleFrames = if (isWhisper) 40 else 15 // ~800ms for Whisper, ~300ms for Conformer
        if (frameCounter >= throttleFrames) {
            frameCounter = 0
            if (isDecodingPartial.compareAndSet(false, true)) {
                partialExecutor.execute {
                    try {
                        decodeOnce()
                        val text = readResultText().trim()
                        if (text.isNotBlank() && text != lastText) {
                            lastText = text
                        }
                    } catch (_: Throwable) {} finally {
                        isDecodingPartial.set(false)
                    }
                }
            }
        }

        return if (lastText.isNotBlank()) lastText else null
    }

    override fun finalizeText(): String {
        try {
            partialExecutor.shutdown()
        } catch (_: Throwable) {}

        invokeNoArg(stream, "inputFinished")
        invokeNoArg(stream, "setInputFinished")

        decodeOnce()
        val text = readResultText().trim()
        if (text.isNotBlank()) {
            lastText = text
        }
        return lastText
    }

    override fun close() {
        try {
            partialExecutor.shutdownNow()
        } catch (_: Throwable) {}
        invokeNoArg(stream, "close")
        invokeNoArg(stream, "release")
    }

    private fun acceptWaveform(samples: ShortArray, sampleRate: Int): Boolean {
        val floatSamples = FloatArray(samples.size) { idx -> samples[idx] / 32768.0f }

        val result =
                invokeBestMatch(
                        target = stream,
                        methodNames = listOf("acceptWaveform", "acceptSamples"),
                        args = listOf(floatSamples, sampleRate),
                )
                        ?: invokeBestMatch(
                                target = stream,
                                methodNames = listOf("acceptWaveform", "acceptSamples"),
                                args = listOf(sampleRate, floatSamples),
                        )
                                ?: invokeBestMatch(
                                target = stream,
                                methodNames = listOf("acceptWaveform", "acceptSamples"),
                                args = listOf(samples, sampleRate),
                        )
                                ?: invokeBestMatch(
                                target = stream,
                                methodNames = listOf("acceptWaveform", "acceptSamples"),
                                args = listOf(sampleRate, samples),
                        )

        return result != null || hasMethod(stream, "acceptWaveform")
    }

    private fun decodeOnce() {
        invokeBestMatch(
                target = recognizer,
                methodNames = listOf("decode", "decodeStream"),
                args = listOf(stream),
        )
                ?: invokeNoArg(recognizer, "decode")
    }

    private fun readResultText(): String {
        val result =
                invokeBestMatch(
                        target = recognizer,
                        methodNames = listOf("getResult", "getResults"),
                        args = listOf(stream),
                )
                        ?: invokeNoArg(recognizer, "getResult")

        if (result == null) {
            return ""
        }

        if (result is String) {
            return result
        }

        val textFromMethod = invokeNoArg(result, "getText")
        if (textFromMethod is String) {
            return textFromMethod
        }

        val textField = getFieldValue(result, "text")
        if (textField is String) {
            return textField
        }

        return ""
    }
}

class SttEngine(
        context: Context,
        private val onStatus: (String) -> Unit = {},
) {
    private var languageCode: String = "en"
    private var engineType: String = "conformer"
    private var activeSession: StreamingSttSession? = null

    private val fallbackBackend = FallbackSttBackend()
    private val sizeResolver = SttAssetResolver(context, onStatus)
    private val sherpaFactory = SherpaOnnxBackendFactory(context, onStatus)
    private var backend: StreamingSttBackend = fallbackBackend

    val backendName: String
        get() = backend.backendName

    val currentEngineType: String
        get() = engineType

    fun isWhisperEngine(): Boolean {
        return engineType.lowercase() == "whisper"
    }

    fun currentModelSizeMb(): Double? {
        val sizedBackend = backend as? ModelSizedSttBackend
        val bytes = sizedBackend?.modelSizeBytes()
        if (bytes != null && bytes > 0L) {
            return bytes / (1024.0 * 1024.0)
        }

        val resolvedModel = sizeResolver.resolve(languageCode, engineType) ?: return null
        val resolvedBytes =
                listOf(
                                resolvedModel.modelFile,
                                resolvedModel.tokensFile,
                                resolvedModel.encoderFile,
                                resolvedModel.decoderFile,
                                resolvedModel.joinerFile,
                        )
                        .sumOf { file ->
                            if (file != null && file.exists()) {
                                file.length()
                            } else {
                                0L
                            }
                        }

        if (resolvedBytes <= 0L) {
            return null
        }

        return resolvedBytes / (1024.0 * 1024.0)
    }

    fun initialize(languageCode: String, engineType: String = "conformer") {
        this.languageCode = languageCode
        this.engineType = engineType.lowercase()
        selectBackend(languageCode)
    }

    @Synchronized
    fun setLanguage(languageCode: String) {
        this.languageCode = languageCode
        selectBackend(languageCode)
    }

    fun setEngineType(engineType: String) {
        this.engineType = engineType.lowercase()
        selectBackend(languageCode)
    }

    fun beginSession() {
        check(recognitionAvailable) {
            "STT unavailable for $languageCode; fallback transcripts are disabled"
        }
        resetSession()
        activeSession = backend.createSession(languageCode)
    }

    @Synchronized
    fun acceptAudio(samples: ShortArray, sampleRate: Int): SttResult {
        val session = activeSession ?: error("No active STT session to receive audio")
        val partial = session.acceptAudio(samples, sampleRate)
        return SttResult(partial = partial, finalText = null)
    }

    @Synchronized
    fun finalizeSession(): SttResult {
        val session = activeSession
        if (session == null) {
            return SttResult(partial = null, finalText = "")
        }

        return try {
            val text = session.finalizeText()
            SttResult(partial = null, finalText = text, metrics = session.metrics)
        } catch (error: Throwable) {
            SttResult(
                    partial = null,
                    finalText = null,
                    metrics = session.metrics,
                    error = error.message ?: error.javaClass.simpleName,
            )
        } finally {
            session.close()
            activeSession = null
        }
    }

    @Synchronized fun currentSessionMetrics(): Map<String, Any> = activeSession?.metrics.orEmpty()

    @Synchronized
    fun resetSession() {
        activeSession?.close()
        activeSession = null
    }

    @Synchronized
    fun shutdown() {
        resetSession()
        backend.close()
        backend = fallbackBackend
    }

    private fun selectBackend(languageCode: String) {
        resetSession()

        val nextBackend = sherpaFactory.createBackend(languageCode, engineType) ?: fallbackBackend
        val changed = backend.backendName != nextBackend.backendName
        if (changed) {
            backend.close()
            backend = nextBackend
            onStatus("STT backend active: ${backend.backendName}")
        } else {
            backend = nextBackend
        }
    }
}

private fun classOrNull(className: String): Class<*>? {
    return try {
        Class.forName(className)
    } catch (_: Throwable) {
        null
    }
}

private fun instantiate(clazz: Class<*>): Any? {
    val constructors = clazz.declaredConstructors.sortedBy { it.parameterCount }
    for (constructor in constructors) {
        val instance = instantiate(constructor)
        if (instance != null) {
            return instance
        }
    }
    return null
}

private fun instantiate(constructor: Constructor<*>): Any? {
    return try {
        constructor.isAccessible = true
        val args = constructor.parameterTypes.map { defaultValueFor(it) }.toTypedArray()
        constructor.newInstance(*args)
    } catch (_: Throwable) {
        null
    }
}

private fun defaultValueFor(type: Class<*>): Any? {
    return when {
        type == Boolean::class.javaPrimitiveType || type == Boolean::class.java -> false
        type == Int::class.javaPrimitiveType || type == Int::class.java -> 0
        type == Long::class.javaPrimitiveType || type == Long::class.java -> 0L
        type == Float::class.javaPrimitiveType || type == Float::class.java -> 0f
        type == Double::class.javaPrimitiveType || type == Double::class.java -> 0.0
        type == Short::class.javaPrimitiveType || type == Short::class.java -> 0.toShort()
        type == Byte::class.javaPrimitiveType || type == Byte::class.java -> 0.toByte()
        type == Char::class.javaPrimitiveType || type == Char::class.java -> 0.toChar()
        type == String::class.java -> ""
        type.isEnum -> type.enumConstants?.firstOrNull()
        else -> null
    }
}

private fun requireProperty(target: Any, candidateNames: List<String>, value: Any?) {
    check(setProperty(target, candidateNames, value)) {
        "Cannot configure ${target.javaClass.simpleName}.${candidateNames.joinToString("/")}"
    }
}

private fun setProperty(target: Any, candidateNames: List<String>, value: Any?): Boolean {
    if (value == null) {
        return false
    }

    for (name in candidateNames) {
        if (setViaSetter(target, name, value)) {
            return true
        }
    }

    for (name in candidateNames) {
        if (setViaField(target, name, value)) {
            return true
        }
    }

    return false
}

private fun setViaSetter(target: Any, propertyName: String, value: Any): Boolean {
    val setterName = "set${propertyName.replaceFirstChar { it.uppercase() }}"
    val methods =
            target.javaClass.methods.filter { method ->
                method.name.equals(setterName, ignoreCase = true) && method.parameterTypes.size == 1
            }

    for (method in methods) {
        if (!isArgumentCompatible(method.parameterTypes[0], value)) {
            continue
        }

        try {
            method.isAccessible = true
            method.invoke(target, adaptValue(method.parameterTypes[0], value))
            return true
        } catch (_: Throwable) {}
    }

    return false
}

private fun setViaField(target: Any, fieldName: String, value: Any): Boolean {
    val field = findField(target.javaClass, fieldName) ?: return false
    return try {
        if (!isArgumentCompatible(field.type, value)) {
            return false
        }
        field.isAccessible = true
        field.set(target, adaptValue(field.type, value))
        true
    } catch (_: Throwable) {
        false
    }
}

private fun invokeBestMatch(
        target: Any,
        methodNames: List<String>,
        args: List<Any?>,
        staticOnly: Boolean = false,
): Any? {
    val clazz = if (target is Class<*>) target else target.javaClass
    val methods = clazz.methods + clazz.declaredMethods

    for (methodName in methodNames) {
        val candidates =
                methods.filter { method ->
                    method.name.equals(methodName, ignoreCase = true) &&
                            (!staticOnly ||
                                    java.lang.reflect.Modifier.isStatic(method.modifiers)) &&
                            method.parameterTypes.size == args.size
                }

        for (method in candidates) {
            val invocationTarget =
                    if (java.lang.reflect.Modifier.isStatic(method.modifiers)) null else target
            if (!areArgumentsCompatible(method.parameterTypes, args)) {
                continue
            }
            try {
                method.isAccessible = true
                val adapted =
                        method.parameterTypes.mapIndexed { index, type ->
                            adaptValue(type, args[index])
                        }
                return method.invoke(invocationTarget, *adapted.toTypedArray())
            } catch (_: Throwable) {}
        }
    }

    return null
}

private fun invokeNoArg(target: Any, methodName: String): Any? {
    val methods = target.javaClass.methods + target.javaClass.declaredMethods
    val candidate =
            methods.firstOrNull { method ->
                method.name.equals(methodName, ignoreCase = true) && method.parameterTypes.isEmpty()
            }
                    ?: return null

    return try {
        candidate.isAccessible = true
        candidate.invoke(target)
    } catch (_: Throwable) {
        null
    }
}

private fun hasMethod(target: Any, methodName: String): Boolean {
    val methods = target.javaClass.methods + target.javaClass.declaredMethods
    return methods.any { it.name.equals(methodName, ignoreCase = true) }
}

private fun getFieldValue(target: Any, fieldName: String): Any? {
    val field = findField(target.javaClass, fieldName) ?: return null
    return try {
        field.isAccessible = true
        field.get(target)
    } catch (_: Throwable) {
        null
    }
}

private fun findField(clazz: Class<*>, name: String): Field? {
    var current: Class<*>? = clazz
    while (current != null) {
        val field = current.declaredFields.firstOrNull { it.name.equals(name, ignoreCase = true) }
        if (field != null) {
            return field
        }
        current = current.superclass
    }
    return null
}

private fun areArgumentsCompatible(parameterTypes: Array<Class<*>>, args: List<Any?>): Boolean {
    if (parameterTypes.size != args.size) {
        return false
    }

    for (index in parameterTypes.indices) {
        val arg = args[index]
        val type = parameterTypes[index]
        if (arg == null) {
            if (type.isPrimitive) {
                return false
            }
            continue
        }
        if (!isArgumentCompatible(type, arg)) {
            return false
        }
    }

    return true
}

private fun isArgumentCompatible(expectedType: Class<*>, value: Any): Boolean {
    if (expectedType.isAssignableFrom(value.javaClass)) {
        return true
    }

    return when {
        expectedType == Int::class.javaPrimitiveType || expectedType == Int::class.java ->
                value is Number
        expectedType == Long::class.javaPrimitiveType || expectedType == Long::class.java ->
                value is Number
        expectedType == Float::class.javaPrimitiveType || expectedType == Float::class.java ->
                value is Number
        expectedType == Double::class.javaPrimitiveType || expectedType == Double::class.java ->
                value is Number
        expectedType == Boolean::class.javaPrimitiveType || expectedType == Boolean::class.java ->
                value is Boolean
        expectedType == String::class.java -> true
        else -> false
    }
}

private fun adaptValue(expectedType: Class<*>, value: Any?): Any? {
    if (value == null) {
        return null
    }

    return when {
        expectedType.isAssignableFrom(value.javaClass) -> value
        expectedType == Int::class.javaPrimitiveType || expectedType == Int::class.java ->
                (value as Number).toInt()
        expectedType == Long::class.javaPrimitiveType || expectedType == Long::class.java ->
                (value as Number).toLong()
        expectedType == Float::class.javaPrimitiveType || expectedType == Float::class.java ->
                (value as Number).toFloat()
        expectedType == Double::class.javaPrimitiveType || expectedType == Double::class.java ->
                (value as Number).toDouble()
        expectedType == String::class.java -> value.toString()
        else -> value
    }
}
