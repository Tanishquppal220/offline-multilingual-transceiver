package com.sih.voicebridge.pipeline

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import org.json.JSONObject
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

class VoicePipelineOrchestrator(
    context: Context,
    private val emitEvent: (Map<String, Any?>) -> Unit,
) {
    private class CaptureRequest(
        val id: String,
        val ptt: Boolean,
        val pressedAtEpochMs: Long,
    ) {
        val stopRequested = AtomicBoolean(false)
        val failure = AtomicReference<String?>(null)
        val preRoll = AudioPreRoll()
        var languageCode = "en"
        var firstFrameSeen = false
        var firstFrameLatencyMs: Long? = null
        var utteranceActive = false
        var utteranceIndex = 0
        var utteranceStartMs: Long? = null
        var utteranceEndMs: Long? = null
        var deliveredSamples = 0L
        var decodeCalls = 0
        val messageId: String get() = if (utteranceIndex == 0) id else "$id-$utteranceIndex"
    }

    private val appContext = context.applicationContext
    private val audioCaptureManager = AudioCaptureManager()
    private val vadProcessor = VadProcessor()
    private val sttEngine = SttEngine(appContext, ::emitStatus)
    private val sentenceManager = SentenceManager()
    private val emergencyAudioController = EmergencyAudioController(appContext)
    private val ttsEngine = TtsEngine(appContext, emitEvent, ::emitStatus)
    private val resourceMonitor = ResourceMonitor(appContext, emitEvent)
    private val pipelineExecutor = Executors.newSingleThreadExecutor()

    private var languageCode: String = "en"
    private var mode: String = "walkie_talkie"
    private var activeMessageId: String? = null

    private val listening = AtomicBoolean(false)
    private val initialized = AtomicBoolean(false)

    private var pttMode = true
    private val preSpeechRingBuffer = java.util.ArrayDeque<AudioFrame>(18)
    private var inSpeechState = false
    private var consecutiveSilenceFrames = 0
    private val maxSilenceFramesForWhisper = 15 // 300ms at 20ms/frame
    private val utteranceAudioBuffer = java.io.ByteArrayOutputStream()

    fun initialize(languageCode: String, engineType: String = "conformer") {
        this.languageCode = languageCode

        emitStatus("Initializing voice pipelines ($engineType)...")

        pipelineExecutor.execute {
            try {
                /*
                 * STT model/backend initialization.
                 * This can involve asset/model loading, so it stays
                 * on the background executor.
                 */
                sttEngine.initialize(languageCode, engineType)

                /*
                 * Model-size calculation can scan files and therefore
                 * also stays away from the UI thread.
                 */
                val sttSize = sttEngine.currentModelSizeMb()
                val ttsSize = ttsEngine.currentModelSizeMb(languageCode)

                resourceMonitor.setPhase(ResourcePhase.IDLE)

                resourceMonitor.updateModelSizes(
                    sttModelSizeMb = sttSize,
                    ttsModelSizeMb = ttsSize,
                )

                resourceMonitor.start()

                initialized.set(true)

                emitEvent(
                    mapOf(
                        "type" to "status",
                        "text" to "Pipelines ready for $languageCode (${sttEngine.backendName})",
                    ),
                )
            } catch (error: Throwable) {
                initialized.set(false)

                emitError(
                    "Pipeline initialization failed: ${error.message ?: error.javaClass.simpleName}"
                )
            }
        }
    }

    fun setSttEngine(engineType: String) {
        pipelineExecutor.execute {
            try {
                sttEngine.setEngineType(engineType)

                val sttSize = sttEngine.currentModelSizeMb()
                val ttsSize = ttsEngine.currentModelSizeMb(languageCode)

                resourceMonitor.updateModelSizes(
                    sttModelSizeMb = sttSize,
                    ttsModelSizeMb = ttsSize,
                )

                emitEvent(
                    mapOf(
                        "type" to "status",
                        "text" to "STT engine switched to $engineType (${sttEngine.backendName})",
                    ),
                )
            } catch (error: Throwable) {
                emitError(
                    "STT engine switch failed: ${error.message ?: error.javaClass.simpleName}"
                )
            }
        }
    }

    fun setLanguage(languageCode: String) {
        if (disposed.get()) return
        pipelineExecutor.execute {
            try {
                this.languageCode = languageCode

                /*
                 * Language/model switching can also be expensive.
                 */
                sttEngine.setLanguage(languageCode)

                val sttSize = sttEngine.currentModelSizeMb()
                val ttsSize = ttsEngine.currentModelSizeMb(languageCode)

                resourceMonitor.updateModelSizes(
                    sttModelSizeMb = sttSize,
                    ttsModelSizeMb = ttsSize,
                )

                emitStatus("Language switched to $languageCode (${sttEngine.backendName})")
            } catch (error: Throwable) {
                emitError(
                    "Language switch failed: ${error.message ?: error.javaClass.simpleName}"
                )
            }
        }
    }

    fun setOperationMode(mode: String) {
        if (disposed.get()) return
        pipelineExecutor.execute {
            this.mode = mode
            emitStatus("Operation mode set to $mode")
        }
    }

    fun startListening(
        ptt: Boolean,
        messageId: String?,
        pressedAtEpochMs: Long? = null,
        requestedLanguage: String? = null,
    ) {
        if (disposed.get()) return
        val capture = CaptureRequest(
            messageId ?: "native-${System.nanoTime()}", ptt,
            pressedAtEpochMs ?: System.currentTimeMillis(),
        )
        if (!captureRequest.compareAndSet(null, capture)) {
            emitError("Previous recording is still recording or finalizing", capture)
            return
        }

        pttMode = ptt
        inSpeechState = ptt
        preSpeechRingBuffer.clear()
        consecutiveSilenceFrames = 0
        synchronized(utteranceAudioBuffer) {
            utteranceAudioBuffer.reset()
        }
        activeMessageId =
            messageId ?: "native-${System.currentTimeMillis()}"

        vadProcessor.reset()

        /*
         * Session creation may initialize native STT objects.
         * Keep it away from the UI thread.
         */
        pipelineExecutor.execute {
            try {
                if (disposed.get() || capture.stopRequested.get()) {
                    completeWithoutRecording(capture)
                    return@execute
                }

                sttEngine.beginSession()
                listening.set(true)

                resourceMonitor.setPhase(ResourcePhase.STT)

                val started = audioCaptureManager.start(
                    onFrame = ::handleAudioFrame,
                    onError = ::handleAudioError,
                )

                if (!started) {
                    listening.set(false)
                    inSpeechState = false
                    preSpeechRingBuffer.clear()
                    sttEngine.resetSession()
                    resourceMonitor.setPhase(ResourcePhase.IDLE)

                    emitError("Unable to start microphone capture")
                    return@execute
                }
                resourceMonitor.setPhase(ResourcePhase.STT)
                audioCaptureManager.start(
                    stopRequested = capture.stopRequested,
                    onFrame = { frame ->
                        if (disposed.get() || capture.failure.get() != null) {
                            false
                        } else {
                            val accepted = frameQueue.offer(frame) { queuedFrame ->
                                if (!disposed.get() && capture.failure.get() == null) {
                                    try { handleAudioFrame(capture, queuedFrame) }
                                    catch (error: Throwable) { failCapture(capture, error.message ?: "Audio delivery failed") }
                                }
                            }
                            if (!accepted) failCapture(capture, "Audio queue exceeded 5 seconds; utterance discarded")
                            accepted
                        }
                    },
                    onError = { failure -> failCapture(capture, failure) },
                    onCompleted = { metrics ->
                        pipelineExecutor.execute { finishCapture(capture, metrics) }
                    },
                )
            } catch (error: Throwable) {
                listening.set(false)
                inSpeechState = false
                preSpeechRingBuffer.clear()
                sttEngine.resetSession()
                resourceMonitor.setPhase(ResourcePhase.IDLE)

                emitError(
                    "Unable to start listening: ${error.message ?: error.javaClass.simpleName}"
                )
            }
        }
    }

    fun stopListening() {
        if (!listening.get()) {
            return
        }

        /*
         * Stop the microphone immediately.
         */
        listening.set(false)
        inSpeechState = false
        preSpeechRingBuffer.clear()
        consecutiveSilenceFrames = 0
        audioCaptureManager.stop()

        /*
         * Final STT decoding can be expensive, so do it in the
         * background pipeline executor.
         */
        pipelineExecutor.execute {
            try {
                finalizeUtterance(reason = "manual_stop")
            } catch (error: Throwable) {
                emitError(
                    "Failed to finalize speech: ${error.message ?: error.javaClass.simpleName}"
                )
            } finally {
                resourceMonitor.setPhase(ResourcePhase.IDLE)
            }
        }
    }

    fun dispose() {
        listening.set(false)
        inSpeechState = false
        preSpeechRingBuffer.clear()
        consecutiveSilenceFrames = 0

        audioCaptureManager.stop()

        pipelineExecutor.execute {
            try {
                sttEngine.shutdown()
                ttsEngine.shutdown()
                resourceMonitor.stop()
            } catch (_: Throwable) {
            }
        }

        pipelineExecutor.shutdownNow()
    }

    private fun handleAudioFrame(frame: AudioFrame) {
        if (!listening.get()) {
            return
        }

        val decision = vadProcessor.process(frame)

        if (!inSpeechState) {
            if (preSpeechRingBuffer.size >= 18) {
                preSpeechRingBuffer.removeFirst()
            }
            preSpeechRingBuffer.addLast(frame)
        }

        if (decision.speechStarted && !inSpeechState) {
            inSpeechState = true
            emitEvent(
                mapOf(
                    "type" to "status",
                    "text" to "Speech started",
                    "messageId" to activeMessageId,
                ),
            )
            while (preSpeechRingBuffer.isNotEmpty()) {
                val buffered = preSpeechRingBuffer.removeFirst()
                bufferAudio(buffered.samples)
                sttEngine.acceptAudio(buffered.samples, buffered.sampleRate)
            }
        }

        if (inSpeechState || pttMode || decision.isSpeech) {
            // Silence compression for Whisper in PTT mode:
            // Cap continuous silence to 300ms to prevent autoregressive decoder
            // hallucination on dead air. NeMo CTC uses <blank> tokens and is immune.
            if (pttMode && !decision.isSpeech) {
                consecutiveSilenceFrames++
                if (sttEngine.isWhisperEngine() && consecutiveSilenceFrames > maxSilenceFramesForWhisper) {
                    return // Skip this silence frame — don't feed dead air to Whisper
                }
            } else {
                consecutiveSilenceFrames = 0
            }

            bufferAudio(frame.samples)
            val sttResult = sttEngine.acceptAudio(
                frame.samples,
                frame.sampleRate,
            )

            val partial = sttResult.partial

            if (!partial.isNullOrBlank()) {
                emitEvent(
                    mapOf(
                        "type" to "partial",
                        "text" to partial,
                        "messageId" to activeMessageId,
                    ),
                )
            }
        }

        if (!pttMode && decision.pauseDetected && inSpeechState) {
            inSpeechState = false
            preSpeechRingBuffer.clear()

            /*
             * We are already on the audio background thread.
             * Finalization is relatively expensive, so schedule it
             * on the pipeline executor.
             */
            pipelineExecutor.execute {
                if (!listening.get()) {
                    return@execute
                }

                try {
                    finalizeUtterance(reason = "vad_pause")

                    sttEngine.beginSession()

                    activeMessageId =
                        "native-${System.currentTimeMillis()}"
                } catch (error: Throwable) {
                    emitError(
                        "VAD sentence finalization failed: ${error.message}"
                    )
                }
            }
        }
    }

    fun dispose() {
        if (!disposed.compareAndSet(false, true)) return
        captureRequest.get()?.stopRequested?.set(true)
        pipelineExecutor.execute {
            if (captureRequest.get() == null) closeResources()
        }
    }

    private fun finalizeUtterance(reason: String) {
        val result = sttEngine.finalizeSession()

        val finalText =
            sentenceManager.finalizeSentence(
                result.finalText.orEmpty()
            )

        val messageId = activeMessageId

        if (messageId != null && finalText.isNotBlank()) {
            emitEvent(
                mapOf(
                    "type" to "final_sentence",
                    "text" to finalText,
                    "messageId" to messageId,
                    "reason" to reason,
                ),
            )
        }

        saveDiagnosticWav()

        if (pttMode || reason == "manual_stop") {
            activeMessageId = null
        }
    }

    private fun bufferAudio(samples: ShortArray) {
        synchronized(utteranceAudioBuffer) {
            val byteBuf = java.nio.ByteBuffer.allocate(samples.size * 2).order(java.nio.ByteOrder.LITTLE_ENDIAN)
            for (s in samples) {
                byteBuf.putShort(s)
            }
            utteranceAudioBuffer.write(byteBuf.array())
        }
    }

    private fun saveDiagnosticWav() {
        val pcmData = synchronized(utteranceAudioBuffer) {
            val data = utteranceAudioBuffer.toByteArray()
            utteranceAudioBuffer.reset()
            data
        }
        if (pcmData.isEmpty()) return

        try {
            val dir = appContext.getExternalFilesDir(null) ?: appContext.filesDir
            val wavFile = java.io.File(dir, "last_recording.wav")
            val totalAudioLen = pcmData.size.toLong()
            val totalDataLen = totalAudioLen + 36
            val sampleRate = AudioCaptureManager.SAMPLE_RATE.toLong()
            val channels = 1
            val byteRate = 16L * sampleRate * channels / 8

            java.io.FileOutputStream(wavFile).use { out ->
                val header = ByteArray(44)
                header[0] = 'R'.code.toByte()
                header[1] = 'I'.code.toByte()
                header[2] = 'F'.code.toByte()
                header[3] = 'F'.code.toByte()
                header[4] = (totalDataLen and 0xffL).toByte()
                header[5] = ((totalDataLen shr 8) and 0xffL).toByte()
                header[6] = ((totalDataLen shr 16) and 0xffL).toByte()
                header[7] = ((totalDataLen shr 24) and 0xffL).toByte()
                header[8] = 'W'.code.toByte()
                header[9] = 'A'.code.toByte()
                header[10] = 'V'.code.toByte()
                header[11] = 'E'.code.toByte()
                header[12] = 'f'.code.toByte()
                header[13] = 'm'.code.toByte()
                header[14] = 't'.code.toByte()
                header[15] = ' '.code.toByte()
                header[16] = 16
                header[17] = 0
                header[18] = 0
                header[19] = 0
                header[20] = 1
                header[21] = 0
                header[22] = channels.toByte()
                header[23] = 0
                header[24] = (sampleRate and 0xffL).toByte()
                header[25] = ((sampleRate shr 8) and 0xffL).toByte()
                header[26] = ((sampleRate shr 16) and 0xffL).toByte()
                header[27] = ((sampleRate shr 24) and 0xffL).toByte()
                header[28] = (byteRate and 0xffL).toByte()
                header[29] = ((byteRate shr 8) and 0xffL).toByte()
                header[30] = ((byteRate shr 16) and 0xffL).toByte()
                header[31] = ((byteRate shr 24) and 0xffL).toByte()
                header[32] = (channels * 16 / 8).toByte()
                header[33] = 0
                header[34] = 16
                header[35] = 0
                header[36] = 'd'.code.toByte()
                header[37] = 'a'.code.toByte()
                header[38] = 't'.code.toByte()
                header[39] = 'a'.code.toByte()
                header[40] = (totalAudioLen and 0xffL).toByte()
                header[41] = ((totalAudioLen shr 8) and 0xffL).toByte()
                header[42] = ((totalAudioLen shr 16) and 0xffL).toByte()
                header[43] = ((totalAudioLen shr 24) and 0xffL).toByte()
                out.write(header, 0, 44)
                out.write(pcmData)
            }
            android.util.Log.d("VoicePipeline", "Saved diagnostic WAV: ${wavFile.absolutePath} (${pcmData.size / 32000.0}s)")
        } catch (e: Throwable) {
            android.util.Log.w("VoicePipeline", "Failed to save diagnostic WAV", e)
        }
    }

    fun speakText(
        text: String,
        languageCode: String,
        emergency: Boolean,
        messageId: String?,
    ) {
        val resolvedMessageId =
            messageId ?: "tts-${System.currentTimeMillis()}"

        /*
         * TTS itself already handles Android TTS initialization on
         * the main Android handler internally.
         *
         * We only avoid doing model-size/file work here.
         */
        if (emergency) {
            emergencyAudioController.prepareMaxVolume()
        }

        resourceMonitor.setPhase(ResourcePhase.TTS)
        ttsEngine.speak(
            text = text, languageCode = languageCode, emergency = emergency, messageId = resolvedMessageId,
            onPlaybackFinished = {
                if (emergency) emergencyAudioController.restoreVolume()
                resourceMonitor.setPhase(ResourcePhase.IDLE)
            },
        )
    }

    fun setEmergencyOverride(enabled: Boolean) {
        if (enabled) emergencyAudioController.prepareMaxVolume() else emergencyAudioController.restoreVolume()
    }

    private fun hasRecordPermission(): Boolean =
        appContext.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    private fun logMetrics(event: Map<String, Any?>) {
        Log.i("ITANTRA_STT", JSONObject(event).toString())
        emitEvent(event)
    }

    private fun emitStatus(text: String) { emitEvent(mapOf("type" to "status", "text" to text)) }

    private fun emitError(text: String, capture: CaptureRequest? = null) {
        emitEvent(mapOf(
            "type" to "error", "text" to text, "messageId" to capture?.id,
            "captureId" to capture?.id, "captureError" to (capture != null),
        ))
    }
}
