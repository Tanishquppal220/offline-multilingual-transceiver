package com.sih.voicebridge.pipeline

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max

data class AudioFrame(
    val samples: ShortArray,
    val sampleRate: Int,
    val timestampMs: Long,
)

/**
 * Adaptive software AGC: fast-attack, slow-decay gain normalizer.
 * Scales raw microphone audio to a consistent peak level (~22,000 / 32,767 ≈ -3.5 dBFS).
 * This compensates for quiet mic levels on Android devices where raw input peaks at only
 * 1,500–4,000 out of 32,767, causing faint syllables to fall below the STT model's
 * log-mel filterbank threshold.
 */
class AudioNormalizer {
    private var currentGain = 1.0f

    fun process(samples: ShortArray): ShortArray {
        var maxVal = 0
        for (sample in samples) {
            val abs = kotlin.math.abs(sample.toInt())
            if (abs > maxVal) maxVal = abs
        }

        // Target peak: ~22,000 out of 32,767 (~ -3.5 dBFS)
        val targetGain = if (maxVal > 500) {
            (22000.0f / maxVal).coerceIn(1.0f, 6.0f)
        } else {
            currentGain // Frame is near-silence, hold current gain
        }

        // Smooth transition: fast attack (0.3), slow decay (0.05)
        val alpha = if (targetGain < currentGain) 0.3f else 0.05f
        currentGain = (currentGain * (1.0f - alpha)) + (targetGain * alpha)

        val boosted = ShortArray(samples.size)
        for (i in samples.indices) {
            val amplified = (samples[i] * currentGain).toInt()
            boosted[i] = amplified.coerceIn(-32767, 32767).toShort()
        }
        return boosted
    }
}

class AudioCaptureManager {
    companion object {
        const val SAMPLE_RATE = PcmUtteranceBuffer.SAMPLE_RATE
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val ENCODING = AudioFormat.ENCODING_PCM_16BIT
        private const val FRAME_SIZE = SAMPLE_RATE / 50
        private const val BYTES_PER_SAMPLE = 2
    }

    private val readExecutor = Executors.newSingleThreadExecutor()
    private val capturing = AtomicBoolean(false)
    private val normalizer = AudioNormalizer()
    @Volatile private var stopSignal: AtomicBoolean? = null

    val isCapturing: Boolean get() = capturing.get()

    @SuppressLint("MissingPermission")
    fun start(
        stopRequested: AtomicBoolean,
        onFrame: (AudioFrame) -> Boolean,
        onError: (String) -> Unit,
    ): Boolean {
        if (capturing.get()) {
            return true
        }

        val minBufferSize = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            CHANNEL_CONFIG,
            ENCODING,
        )

        if (minBufferSize <= 0) {
            onError("AudioRecord min buffer size unavailable: $minBufferSize")
            return false
        }

        // Expand buffer size to at least 2 seconds (64KB) to prevent buffer overrun
        val bufferSize = max(minBufferSize * 4, SAMPLE_RATE * 4)
        val record = AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            SAMPLE_RATE, CHANNEL_CONFIG, ENCODING, bufferSize,
        )
        try {
            check(record.state == AudioRecord.STATE_INITIALIZED) { "AudioRecord initialization failed" }
            check(record.sampleRate == SAMPLE_RATE && record.channelCount == 1 && record.audioFormat == ENCODING) {
                "Unexpected capture format: ${record.sampleRate} Hz, ${record.channelCount} channels, ${record.audioFormat}"
            }
            val actualSampleRate = record.sampleRate
            val actualBufferSizeFrames = record.bufferSizeInFrames
            stopSignal = stopRequested
            record.startRecording()
            check(record.recordingState == AudioRecord.RECORDSTATE_RECORDING) { "AudioRecord did not start recording" }
            val recordingStartedAt = System.currentTimeMillis()
            capturing.set(true)
            readExecutor.execute {
                val levels = AudioLevels()
                var queuedSamples = 0L
                var firstFrameAt: Long? = null
                var failure: String? = null
                val frameBuffer = ShortArray(FRAME_SIZE)
                while (capturing.get()) {
                    val samplesRead = record.read(frameBuffer, 0, frameBuffer.size)
                    if (samplesRead > 0) {
                        val normalized = normalizer.process(frameBuffer.copyOf(samplesRead))
                        onFrame(
                            AudioFrame(
                                samples = normalized,
                                sampleRate = SAMPLE_RATE,
                                timestampMs = System.currentTimeMillis(),
                            ),
                        )
                    } else if (samplesRead < 0) {
                        onError("AudioRecord read error: $samplesRead")
                        break
                    }
                }
            } catch (error: Throwable) {
                if (capturing.get()) {
                    onError("Audio capture failure: ${error.message}")
                }
            }
        }

        return true
    }

    fun stop() {
        if (!capturing.getAndSet(false)) {
            return
        }

        readTask?.cancel(true)
        readTask = null

        val record = audioRecord
        audioRecord = null

        if (record != null) {
            try {
                record.stop()
            } catch (_: IllegalStateException) {
            }
            record.release()
            throw error
        }
    }

    fun stop() { stopSignal?.set(true) }

    fun shutdown() {
        stop()
        readExecutor.shutdown()
    }
}
