package com.sih.voicebridge.pipeline

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.util.ArrayDeque
import java.util.Locale

private enum class AndroidTtsInitState {
    INITIALIZING,
    READY,
    FAILED,
}

private data class PendingTtsRequest(
    val text: String,
    val languageCode: String,
    val emergency: Boolean,
    val messageId: String,
    val onPlaybackFinished: (() -> Unit)?,
)

internal data class SpeechResolution(
    val locale: Locale,
    val spokenText: String,
    val resolvedLanguageCode: String,
)

internal fun resolveSpeechLocaleAndText(rawText: String, requestedLangCode: String): SpeechResolution {
    // 1. Sanitize text for clean speech synthesis:
    // Strip technical GPS coordinate brackets like [GPS: 31.2526, 75.7025]
    var clean = rawText
        .replace(Regex("\\[GPS:[^\\]]*\\]", RegexOption.IGNORE_CASE), "")
        .replace(Regex("[\\p{So}\\p{Cn}]"), "") // Strip emoji symbols (👍, 🆘, 📍, etc.)
        .replace(Regex("\\s+"), " ")
        .trim()

    if (clean.isBlank()) {
        clean = rawText
    }

    // 2. Count Unicode script characters
    var latinCount = 0
    var devanagariCount = 0
    var tamilCount = 0
    var teluguCount = 0
    var kannadaCount = 0
    var gujaratiCount = 0
    var malayalamCount = 0
    var bengaliCount = 0
    var odiaCount = 0

    for (ch in clean) {
        when (ch) {
            in 'A'..'Z', in 'a'..'z' -> latinCount++
            in '\u0900'..'\u097F' -> devanagariCount++
            in '\u0B80'..'\u0BFF' -> tamilCount++
            in '\u0C00'..'\u0C7F' -> teluguCount++
            in '\u0C80'..'\u0CFF' -> kannadaCount++
            in '\u0A80'..'\u0AFF' -> gujaratiCount++
            in '\u0D00'..'\u0D7F' -> malayalamCount++
            in '\u0980'..'\u09FF' -> bengaliCount++
            in '\u0B00'..'\u0B7F' -> odiaCount++
        }
    }

    val totalIndic = devanagariCount + tamilCount + teluguCount + kannadaCount +
        gujaratiCount + malayalamCount + bengaliCount + odiaCount

    // 3. Resolve target locale based on actual script content:
    return when {
        // Pure or predominant Latin/ASCII text: MUST use English voice
        // (Android Marathi/Hindi TTS fails or mutes when fed Latin ASCII text)
        latinCount > 0 && totalIndic == 0 -> {
            SpeechResolution(
                locale = Locale.US,
                spokenText = clean,
                resolvedLanguageCode = "en",
            )
        }
        devanagariCount > 0 -> {
            if (requestedLangCode.equals("mr", ignoreCase = true)) {
                SpeechResolution(
                    locale = Locale("mr", "IN"),
                    spokenText = clean,
                    resolvedLanguageCode = "mr",
                )
            } else {
                SpeechResolution(
                    locale = Locale("hi", "IN"),
                    spokenText = clean,
                    resolvedLanguageCode = "hi",
                )
            }
        }
        tamilCount > 0 -> SpeechResolution(Locale("ta", "IN"), clean, "ta")
        teluguCount > 0 -> SpeechResolution(Locale("te", "IN"), clean, "te")
        kannadaCount > 0 -> SpeechResolution(Locale("kn", "IN"), clean, "kn")
        gujaratiCount > 0 -> SpeechResolution(Locale("gu", "IN"), clean, "gu")
        malayalamCount > 0 -> SpeechResolution(Locale("ml", "IN"), clean, "ml")
        bengaliCount > 0 -> SpeechResolution(Locale("bn", "IN"), clean, "bn")
        odiaCount > 0 -> SpeechResolution(Locale("or", "IN"), clean, "or")
        else -> {
            SpeechResolution(
                locale = localeForCode(requestedLangCode),
                spokenText = clean,
                resolvedLanguageCode = requestedLangCode.lowercase(),
            )
        }
    }
}

internal fun localeForCode(languageCode: String): Locale {
    return when (languageCode.lowercase()) {
        "en" -> Locale.US
        "hi" -> Locale("hi", "IN")
        "gu" -> Locale("gu", "IN")
        "mr" -> Locale("mr", "IN")
        "kn" -> Locale("kn", "IN")
        "ml" -> Locale("ml", "IN")
        "ta" -> Locale("ta", "IN")
        "te" -> Locale("te", "IN")
        "bn" -> Locale("bn", "IN")
        "or" -> Locale("or", "IN")
        else -> Locale.forLanguageTag(languageCode)
    }
}

private class AndroidSystemTtsBackend(
    private val context: Context,
    private val emitEvent: (Map<String, Any?>) -> Unit,
    private val emitStatus: (String) -> Unit,
    private val emitError: (String?, String) -> Unit,
) {
    val backendName: String = "android_tts"

    private val mainHandler = Handler(Looper.getMainLooper())
    private val pendingQueue = ArrayDeque<PendingTtsRequest>()
    private val activeByUtteranceId = mutableMapOf<String, PendingTtsRequest>()

    private var initState = AndroidTtsInitState.INITIALIZING
    private var textToSpeech: TextToSpeech? = null

    init {
        mainHandler.post {
            initialize()
        }
    }

    fun speak(request: PendingTtsRequest): Boolean {
        mainHandler.post {
            when (initState) {
                AndroidTtsInitState.READY -> speakInternal(request)
                AndroidTtsInitState.INITIALIZING -> pendingQueue.addLast(request)
                AndroidTtsInitState.FAILED -> {
                    emitError(request.messageId, "Android TextToSpeech unavailable")
                    request.onPlaybackFinished?.invoke()
                }
            }
        }
        return true
    }

    fun shutdown() {
        mainHandler.post {
            for (request in activeByUtteranceId.values) {
                request.onPlaybackFinished?.invoke()
            }
            activeByUtteranceId.clear()

            while (pendingQueue.isNotEmpty()) {
                pendingQueue.removeFirst().onPlaybackFinished?.invoke()
            }

            textToSpeech?.stop()
            textToSpeech?.shutdown()
            textToSpeech = null
            initState = AndroidTtsInitState.FAILED
        }
    }

    private fun initialize() {
        if (textToSpeech != null) {
            return
        }

        textToSpeech = TextToSpeech(context) { status ->
            if (status == TextToSpeech.SUCCESS) {
                initState = AndroidTtsInitState.READY
                textToSpeech?.setOnUtteranceProgressListener(progressListener())
                emitStatus("Native Android TTS initialized")
                flushPending()
            } else {
                initState = AndroidTtsInitState.FAILED
                emitError(null, "TTS initialization failed (status=$status)")
                while (pendingQueue.isNotEmpty()) {
                    pendingQueue.removeFirst().onPlaybackFinished?.invoke()
                }
            }
        }
    }

    private fun flushPending() {
        while (pendingQueue.isNotEmpty()) {
            speakInternal(pendingQueue.removeFirst())
        }
    }

    private fun speakInternal(request: PendingTtsRequest) {
        val tts = textToSpeech
        if (tts == null || initState != AndroidTtsInitState.READY) {
            pendingQueue.addLast(request)
            return
        }

        // Play tactical attention chime for emergency SOS
        if (request.emergency) {
            try {
                val toneGen = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
                toneGen.startTone(ToneGenerator.TONE_PROP_BEEP2, 250)
            } catch (_: Throwable) {
                // Ignore audio hardware error
            }
        }

        // Script-aware locale and text resolution
        val resolution = resolveSpeechLocaleAndText(request.text, request.languageCode)
        val localeStatus = tts.setLanguage(resolution.locale)
        if (localeStatus == TextToSpeech.LANG_NOT_SUPPORTED ||
            localeStatus == TextToSpeech.LANG_MISSING_DATA
        ) {
            tts.setLanguage(Locale.US)
            emitStatus("TTS locale ${resolution.locale} unavailable, falling back to en-US")
        }

        emitEvent(
            mapOf(
                "type" to "tts_started",
                "text" to resolution.spokenText,
                "languageCode" to resolution.resolvedLanguageCode,
                "messageId" to request.messageId,
                "emergency" to request.emergency,
                "backend" to backendName,
            ),
        )

        val utteranceId = "utt-${request.messageId}-${System.nanoTime()}"
        activeByUtteranceId[utteranceId] = request

        val params = Bundle().apply {
            putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, if (request.emergency) 1.0f else 0.9f)
        }
        val queueMode = if (request.emergency) TextToSpeech.QUEUE_FLUSH else TextToSpeech.QUEUE_ADD

        val result = tts.speak(resolution.spokenText, queueMode, params, utteranceId)
        if (result == TextToSpeech.ERROR) {
            activeByUtteranceId.remove(utteranceId)
            emitError(request.messageId, "TTS speak() returned error")
            request.onPlaybackFinished?.invoke()
        }
    }

    private fun progressListener(): UtteranceProgressListener {
        return object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {
                val request = getRequest(utteranceId) ?: return
                emitEvent(
                    mapOf(
                        "type" to "audio_started",
                        "text" to request.text,
                        "messageId" to request.messageId,
                        "emergency" to request.emergency,
                        "backend" to backendName,
                    ),
                )
            }

            override fun onDone(utteranceId: String?) {
                removeRequest(utteranceId)?.onPlaybackFinished?.invoke()
            }

            override fun onStop(utteranceId: String?, interrupted: Boolean) {
                if (interrupted) {
                    emitStatus("TTS playback interrupted")
                }
                removeRequest(utteranceId)?.onPlaybackFinished?.invoke()
            }

            override fun onError(utteranceId: String?) {
                val request = removeRequest(utteranceId)
                emitError(request?.messageId, "TTS playback error")
                request?.onPlaybackFinished?.invoke()
            }

            override fun onError(utteranceId: String?, errorCode: Int) {
                val request = removeRequest(utteranceId)
                emitError(request?.messageId, "TTS playback error code=$errorCode")
                request?.onPlaybackFinished?.invoke()
            }
        }
    }

    private fun getRequest(utteranceId: String?): PendingTtsRequest? {
        if (utteranceId.isNullOrBlank()) {
            return null
        }
        return activeByUtteranceId[utteranceId]
    }

    private fun removeRequest(utteranceId: String?): PendingTtsRequest? {
        if (utteranceId.isNullOrBlank()) {
            return null
        }
        return activeByUtteranceId.remove(utteranceId)
    }
}

class TtsEngine(
    context: Context,
    private val emitEvent: (Map<String, Any?>) -> Unit,
    private val emitStatus: (String) -> Unit,
) {
    private val appContext = context.applicationContext

    private val androidBackend = AndroidSystemTtsBackend(
        context = appContext,
        emitEvent = emitEvent,
        emitStatus = emitStatus,
        emitError = ::emitError,
    )

    fun currentModelSizeMb(languageCode: String): Double? {
        return null
    }

    fun activeEngineName(languageCode: String): String {
        val locale = localeForCode(languageCode)
        return "Android System TTS (${locale.toLanguageTag()})"
    }

    fun speak(
        text: String,
        languageCode: String,
        emergency: Boolean,
        messageId: String,
        onPlaybackFinished: (() -> Unit)? = null,
    ) {
        val request = PendingTtsRequest(
            text = text,
            languageCode = languageCode,
            emergency = emergency,
            messageId = messageId,
            onPlaybackFinished = onPlaybackFinished,
        )

        androidBackend.speak(request)
    }

    fun shutdown() {
        androidBackend.shutdown()
    }

    private fun emitError(messageId: String?, text: String) {
        emitEvent(
            mapOf(
                "type" to "error",
                "text" to text,
                "messageId" to messageId,
            ),
        )
    }
}
