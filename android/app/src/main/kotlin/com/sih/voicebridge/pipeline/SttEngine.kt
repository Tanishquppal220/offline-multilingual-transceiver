
package com.sih.voicebridge.pipeline

import android.content.Context
import org.json.JSONException
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.lang.reflect.Constructor
import java.lang.reflect.Field
import java.lang.reflect.Method
import android.util.Log
private const val TAG = "SIH_STT"
data class SttResult(
    val partial: String?,
    val finalText: String?,
    val metrics: Map<String, Any> = emptyMap(),
    val error: String? = null,
)

interface StreamingSttSession {
    val metrics: Map<String, Any> get() = emptyMap()
    fun acceptAudio(samples: ShortArray, sampleRate: Int): String?
    fun finalizeText(): String
    fun close() {}
}

interface StreamingSttBackend {
    val backendName: String
    val recognitionAvailable: Boolean get() = true
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
    override val metrics: Map<String, Any> get() = mapOf(
        "fallback" to true, "recognitionValid" to false, "decodeCalls" to 0,
    )
    override fun acceptAudio(samples: ShortArray, sampleRate: Int): String? = null
    override fun finalizeText(): String = ""
}

data class SttModelSpec(
    val languageCode: String,
    val type: String,
    val modelAssetPath: String,
    val tokensAssetPath: String?,
    val encoderAssetPath: String?,
    val decoderAssetPath: String?,
    val joinerAssetPath: String?,
)

data class ResolvedSttModel(
    val languageCode: String,
    val type: String,
    val modelFile: File,
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

    fun resolve(languageCode: String): ResolvedSttModel? {
        val manifest = loadManifest()
        if (manifest.isEmpty()) {
            return null
        }

        val languageKey = languageCode.lowercase()
        val spec = manifest[languageKey]
        if (spec == null) {
            onStatus("No STT model spec found for '$languageCode' in model_manifest.json")
            return null
        }

        val modelFile = copyAssetToAppStorage(spec.modelAssetPath)
        if (modelFile == null) {
            onStatus("Missing STT model asset: ${spec.modelAssetPath}")
            return null
        }

        val tokensFile = copyOptional(spec.tokensAssetPath)
        val encoderFile = copyOptional(spec.encoderAssetPath)
        val decoderFile = copyOptional(spec.decoderAssetPath)
        val joinerFile = copyOptional(spec.joinerAssetPath)

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
        val payload = try {
            context.assets.open(manifestAssetPath).bufferedReader().use { it.readText() }
        } catch (_: Throwable) {
            onStatus("STT manifest not found at $MANIFEST_RELATIVE_PATH")
            manifestCache = emptyMap()
            return manifestCache.orEmpty()
        }

        val parsed = try {
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
        val languagesNode = if (root.has("languages")) {
            root.getJSONObject("languages")
        } else {
            root
        }

        val table = mutableMapOf<String, SttModelSpec>()
        val keys = languagesNode.keys()
        while (keys.hasNext()) {
            val languageCode = keys.next()
            val specNode = languagesNode.optJSONObject(languageCode) ?: continue
            val spec = parseSpec(languageCode, specNode) ?: continue
            table[languageCode.lowercase()] = spec
        }

        return table
    }

    private fun parseSpec(languageCode: String, node: JSONObject): SttModelSpec? {
        val modelAssetPath = pickFirstNonBlank(
            node.optString("model", ""),
            node.optString("modelAsset", ""),
        )

        if (modelAssetPath.isNullOrBlank()) {
            return null
        }

        return SttModelSpec(
            languageCode = languageCode.lowercase(),
            type = pickFirstNonBlank(
                node.optString("type", ""),
                node.optString("modelType", ""),
            ) ?: "nemo_ctc",
            modelAssetPath = modelAssetPath,
            tokensAssetPath = pickFirstNonBlank(
                node.optString("tokens", ""),
                node.optString("tokensAsset", ""),
            ),
            encoderAssetPath = pickFirstNonBlank(
                node.optString("encoder", ""),
                node.optString("encoderAsset", ""),
            ),
            decoderAssetPath = pickFirstNonBlank(
                node.optString("decoder", ""),
                node.optString("decoderAsset", ""),
            ),
            joinerAssetPath = pickFirstNonBlank(
                node.optString("joiner", ""),
                node.optString("joinerAsset", ""),
            ),
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
                FileOutputStream(target).use { output ->
                    input.copyTo(output)
                }
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

    // fun createBackend(languageCode: String): StreamingSttBackend? {
    //     if (!isSherpaAvailable()) {
    //         if (!reportedMissingLibrary) {
    //             onStatus("Sherpa-ONNX classes unavailable. Add Sherpa dependency, then restart app.")
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

    fun createBackend(languageCode: String): StreamingSttBackend? {
        Log.e("SIH_STT", "========== STT BACKEND START ==========")
        Log.e("SIH_STT", "Language: $languageCode")

        if (!isSherpaAvailable()) {
            Log.e("SIH_STT", "❌ Sherpa classes NOT available")
            onStatus("STT: Sherpa classes unavailable")
            return null
        }

        Log.e("SIH_STT", "✅ Sherpa classes are available")

        val model = assetResolver.resolve(languageCode)

        if (model == null) {
            Log.e("SIH_STT", "❌ Model resolution FAILED for: $languageCode")
            onStatus("STT: Model resolution failed for $languageCode")
            return null
        }

        Log.e("SIH_STT", "✅ Model resolved")
        Log.e("SIH_STT", "Model path: ${model.modelFile.absolutePath}")
        Log.e("SIH_STT", "Model exists: ${model.modelFile.exists()}")
        Log.e("SIH_STT", "Model size: ${model.modelFile.length()} bytes")
        Log.e("SIH_STT", "Tokens path: ${model.tokensFile?.absolutePath}")
        Log.e("SIH_STT", "Tokens exists: ${model.tokensFile?.exists()}")

        return try {
            Log.e("SIH_STT", "Creating SherpaOnnxReflectiveBackend...")

            val backend = SherpaOnnxReflectiveBackend(
                context,
                model,
                onStatus,
            )

            Log.e("SIH_STT", "✅ Sherpa backend CREATED successfully")
            Log.e("SIH_STT", "========== STT BACKEND SUCCESS ==========")

            onStatus("STT backend active: ${backend.backendName}")

            backend
        } catch (error: Throwable) {
            Log.e(
                "SIH_STT",
                "❌ Sherpa backend creation FAILED",
                error,
            )

            onStatus(
                "STT backend failed: " +
                    "${error.javaClass.simpleName}: ${error.message}"
            )

            null
        }
    }

    private fun isSherpaAvailable(): Boolean {
        if (classProbeDone) {
            return sherpaAvailable
        }

        classProbeDone = true

        sherpaAvailable = try {
            Log.e("SIH_STT", "Checking Sherpa Java classes...")

            Class.forName(
                "com.k2fsa.sherpa.onnx.OfflineRecognizer"
            )

            Log.e(
                "SIH_STT",
                "✅ OfflineRecognizer found"
            )

            Class.forName(
                "com.k2fsa.sherpa.onnx.OfflineRecognizerConfig"
            )

            Log.e(
                "SIH_STT",
                "✅ OfflineRecognizerConfig found"
            )

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
    private val onStatus: (String) -> Unit,
) : StreamingSttBackend, ModelSizedSttBackend {
    override val backendName: String = "sherpa_reflective_${model.languageCode}"

    private val recognizerDelegate = lazy {
        val recognizerConfig = buildRecognizerConfig(model)
            ?: throw IllegalStateException("Unable to build Sherpa recognizer config")
        createRecognizer(recognizerConfig)
    }
    private val recognizer: Any get() = recognizerDelegate.value
    private val apiDelegate = lazy { OfflineRecognizerApi(recognizer) }
    private var released = false

    override fun prepare() {
        check(!released) { "Sherpa backend has been released" }
        apiDelegate.value
    }

    override fun createSession(languageCode: String): StreamingSttSession {
        if (languageCode.lowercase() != model.languageCode.lowercase()) {
            throw IllegalStateException(
                "Sherpa backend prepared for ${model.languageCode}, requested $languageCode",
            )
        }

        onStatus("Sherpa STT session started (${model.languageCode})")
        return SherpaOnnxReflectiveSession(apiDelegate.value)
    }

    override fun close() {
        if (!released && recognizerDelegate.isInitialized()) {
            released = true
            recognizer.javaClass.getMethod("release").invoke(recognizer)
        }
    }

    override fun modelSizeBytes(): Long? {
        val files = listOf(
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
        Log.e(
            TAG,
            "Recognizer model is being loaded from filesystem"
        )

        Log.e(
            TAG,
            "Model: ${model.modelFile.absolutePath}"
        )

        Log.e(
            TAG,
            "Tokens: ${model.tokensFile?.absolutePath}"
        )
        val recognizerClass = Class.forName("com.k2fsa.sherpa.onnx.OfflineRecognizer")

        val constructors = recognizerClass.constructors.sortedBy { it.parameterCount }
        for (constructor in constructors) {
            val instance = tryConstructRecognizer(constructor, recognizerConfig)
            if (instance != null) {
                return instance
            }
        }

        val factoryCreated = invokeBestMatch(
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

        Log.e(
            "SIH_STT",
            "Trying constructor: $constructor"
        )

        Log.e(
            "SIH_STT",
            "Parameter count: ${params.size}"
        )

        val args = mutableListOf<Any?>()

        for (param in params) {

            Log.e(
                "SIH_STT",
                "Parameter type: ${param.name}"
            )

            when {

                // OfflineRecognizerConfig
                param.isAssignableFrom(
                    recognizerConfig.javaClass
                ) -> {

                    Log.e(
                        "SIH_STT",
                        " -> Using OfflineRecognizerConfig"
                    )

                    args.add(recognizerConfig)
                }

                // IMPORTANT:
                // Our models are loaded from absolute filesystem paths.
                // Therefore AssetManager MUST be null.
                param.name ==
                    "android.content.res.AssetManager" -> {

                    Log.e(
                        "SIH_STT",
                        " -> Using NULL AssetManager because model paths are absolute"
                    )

                    args.add(null)
                }

                // Android Context, if required by this constructor.
                param.isAssignableFrom(
                    Context::class.java
                ) -> {

                    Log.e(
                        "SIH_STT",
                        " -> Using Android Context"
                    )

                    args.add(context)
                }

                else -> {

                    Log.e(
                        "SIH_STT",
                        " -> ❌ Unsupported constructor parameter: ${param.name}"
                    )

                    return null
                }
            }
        }

        return try {

            constructor.isAccessible = true

            Log.e(
                "SIH_STT",
                "Invoking constructor..."
            )

            val instance =
                constructor.newInstance(
                    *args.toTypedArray()
                )

            Log.e(
                "SIH_STT",
                "✅ Constructor invocation succeeded"
            )

            instance

        } catch (error: Throwable) {

            Log.e(
                "SIH_STT",
                "❌ Constructor invocation FAILED",
                error
            )

            null
        }
    }

    private fun buildRecognizerConfig(model: ResolvedSttModel): Any? {
        val recognizerConfigClass = classOrNull("com.k2fsa.sherpa.onnx.OfflineRecognizerConfig")
            ?: return null
        val modelConfigClass = classOrNull("com.k2fsa.sherpa.onnx.OfflineModelConfig")
            ?: return null

        val recognizerConfig = instantiate(recognizerConfigClass) ?: return null
        val modelConfig = instantiate(modelConfigClass) ?: return null

        configureModelConfig(modelConfig, model)
        requireProperty(recognizerConfig, listOf("modelConfig", "offlineModelConfig"), modelConfig)
        requireProperty(recognizerConfig, listOf("decodingMethod"), "greedy_search")
        requireProperty(recognizerConfig, listOf("maxActivePaths"), 4)

        val featureConfig = classOrNull("com.k2fsa.sherpa.onnx.FeatureConfig")?.let { instantiate(it) }
            ?: error("Sherpa FeatureConfig is unavailable")
        requireProperty(featureConfig, listOf("sampleRate"), 16000f)
        requireProperty(featureConfig, listOf("featureDim", "numBins"), 80)
        requireProperty(recognizerConfig, listOf("featConfig", "featureConfig"), featureConfig)

        return recognizerConfig
    }

    private fun configureModelConfig(modelConfig: Any, model: ResolvedSttModel) {
        requireProperty(modelConfig, listOf("numThreads"), 2)
        requireProperty(modelConfig, listOf("provider"), "cpu")
        requireProperty(modelConfig, listOf("debug"), false)

        when (model.type.lowercase()) {
            "transducer" -> configureTransducerModel(modelConfig, model)
            else -> configureNemoCtcModel(modelConfig, model)
        }
    }

    private fun configureNemoCtcModel(
        modelConfig: Any,
        model: ResolvedSttModel
    ) {
        val nemoClass =
            classOrNull("com.k2fsa.sherpa.onnx.OfflineNemoEncDecCtcModelConfig")
                ?: error("Sherpa NeMo CTC configuration is unavailable")
    
        val nemoConfig = instantiate(nemoClass) ?: error("Cannot create Sherpa NeMo CTC configuration")
    
        // NeMo CTC model path
        requireProperty(
            nemoConfig,
            listOf("model"),
            model.modelFile.absolutePath
        )
    
        // IMPORTANT:
        // OfflineModelConfig uses "nemo", not "nemoCtc"
        requireProperty(
            modelConfig,
            listOf("nemo", "nemoCtc"),
            nemoConfig
        )
    
        // tokens.txt belongs directly to OfflineModelConfig
        val tokensFile = model.tokensFile ?: error("NeMo CTC tokens are missing")
        requireProperty(modelConfig, listOf("tokens", "tokensPath"), tokensFile.absolutePath)
    
        // Tell Sherpa explicitly that this is a NeMo CTC model.
        requireProperty(
            modelConfig,
            listOf("modelType"),
            "nemo_ctc"
        )
    }

    private fun configureTransducerModel(modelConfig: Any, model: ResolvedSttModel) {
        val transducerClass = classOrNull("com.k2fsa.sherpa.onnx.OfflineTransducerModelConfig")
            ?: return

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

class SttEngine(
    context: Context,
    private val onStatus: (String) -> Unit = {},
) {
    private var languageCode: String = "en"
    private var activeSession: StreamingSttSession? = null

    private val fallbackBackend = FallbackSttBackend()
    private val sizeResolver = SttAssetResolver(context, onStatus)
    private val sherpaFactory = SherpaOnnxBackendFactory(context, onStatus)
    private var backend: StreamingSttBackend = fallbackBackend

    val backendName: String
        get() = backend.backendName
    val recognitionAvailable: Boolean
        get() = backend.recognitionAvailable

    fun currentModelSizeMb(): Double? {
        val sizedBackend = backend as? ModelSizedSttBackend
        val bytes = sizedBackend?.modelSizeBytes()
        if (bytes != null && bytes > 0L) {
            return bytes / (1024.0 * 1024.0)
        }

        val resolvedModel = sizeResolver.resolve(languageCode) ?: return null
        val resolvedBytes = listOf(
            resolvedModel.modelFile,
            resolvedModel.tokensFile,
            resolvedModel.encoderFile,
            resolvedModel.decoderFile,
            resolvedModel.joinerFile,
        ).sumOf { file ->
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

    fun activeModelName(code: String = languageCode): String {
        val resolved = sizeResolver.resolve(code)
        return when {
            resolved != null && resolved.type.equals("nemo_ctc", ignoreCase = true) ->
                "NeMo CTC int8 (${code.uppercase()})"
            resolved != null && resolved.type.equals("transducer", ignoreCase = true) ->
                "Sherpa Transducer (${code.uppercase()})"
            resolved != null ->
                "Sherpa STT (${code.uppercase()})"
            else ->
                "Offline STT (${code.uppercase()})"
        }
    }

    @Synchronized
    fun initialize(languageCode: String) {
        this.languageCode = languageCode
        selectBackend(languageCode)
    }

    @Synchronized
    fun setLanguage(languageCode: String) {
        this.languageCode = languageCode
        selectBackend(languageCode)
    }

    @Synchronized
    fun beginSession() {
        check(recognitionAvailable) { "STT unavailable for $languageCode; fallback transcripts are disabled" }
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
                partial = null, finalText = null, metrics = session.metrics,
                error = error.message ?: error.javaClass.simpleName,
            )
        } finally {
            session.close()
            activeSession = null
        }
    }

    @Synchronized
    fun currentSessionMetrics(): Map<String, Any> = activeSession?.metrics.orEmpty()

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

        runCatching { backend.close() }.onFailure { onStatus("STT release failed: ${it.message}") }
        backend = fallbackBackend
        val nextBackend = sherpaFactory.createBackend(languageCode)
        if (nextBackend != null) {
            try {
                nextBackend.prepare()
                backend = nextBackend
            } catch (error: Throwable) {
                onStatus("STT preparation failed: ${error.message}")
                runCatching { nextBackend.close() }
            }
        }
        onStatus(if (recognitionAvailable) "STT ready: ${backend.backendName}"
            else "STT UNAVAILABLE: fallback mode flagged; no fabricated transcript will be emitted")
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
    val methods = target.javaClass.methods.filter { method ->
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
        } catch (_: Throwable) {
        }
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
        val candidates = methods.filter { method ->
            method.name.equals(methodName, ignoreCase = true) &&
                (!staticOnly || java.lang.reflect.Modifier.isStatic(method.modifiers)) &&
                method.parameterTypes.size == args.size
        }

        for (method in candidates) {
            val invocationTarget = if (java.lang.reflect.Modifier.isStatic(method.modifiers)) null else target
            if (!areArgumentsCompatible(method.parameterTypes, args)) {
                continue
            }
            try {
                method.isAccessible = true
                val adapted = method.parameterTypes.mapIndexed { index, type ->
                    adaptValue(type, args[index])
                }
                return method.invoke(invocationTarget, *adapted.toTypedArray())
            } catch (_: Throwable) {
            }
        }
    }

    return null
}

private fun invokeNoArg(target: Any, methodName: String): Any? {
    val methods = target.javaClass.methods + target.javaClass.declaredMethods
    val candidate = methods.firstOrNull { method ->
        method.name.equals(methodName, ignoreCase = true) && method.parameterTypes.isEmpty()
    } ?: return null

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
        expectedType == Int::class.javaPrimitiveType || expectedType == Int::class.java -> value is Number
        expectedType == Long::class.javaPrimitiveType || expectedType == Long::class.java -> value is Number
        expectedType == Float::class.javaPrimitiveType || expectedType == Float::class.java -> value is Number
        expectedType == Double::class.javaPrimitiveType || expectedType == Double::class.java -> value is Number
        expectedType == Boolean::class.javaPrimitiveType || expectedType == Boolean::class.java -> value is Boolean
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
