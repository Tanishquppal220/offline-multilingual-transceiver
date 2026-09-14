package com.sih.voicebridge.pipeline

import kotlin.math.sqrt

data class VadDecision(
    val isSpeech: Boolean,
    val speechStarted: Boolean,
    val pauseDetected: Boolean,
    val silenceDurationMs: Long,
    val energy: Double,
)

class VadProcessor(
    private var silenceThresholdMs: Long = 700,
    private var minSpeechDurationMs: Long = 250,
    private var baseEnergyThreshold: Double = 0.008,
    private val hangoverMs: Long = 150,
) {
    private var inSpeech = false
    private var speechStartedAtMs: Long? = null
    private var lastSpeechAtMs: Long? = null
    private var noiseFloor = 0.002
    private var hangoverCountdown = 0L

    fun configureSilenceThreshold(valueMs: Long) {
        silenceThresholdMs = valueMs.coerceIn(300, 2000)
    }

    fun configureSpeechThreshold(energy: Double) {
        baseEnergyThreshold = energy.coerceIn(0.001, 0.08)
    }

    fun reset() {
        processedSamples = 0
        inSpeech = false
        speechStartedAtMs = null
        lastSpeechAtMs = null
        hangoverCountdown = 0L
    }

    fun silenceThresholdMs(): Long {
        return silenceThresholdMs
    }

    fun process(frame: AudioFrame): VadDecision {
        processedSamples += frame.samples.size
        val audioTimeMs = processedSamples * 1000L / frame.sampleRate
        val rmsEnergy = calculateRmsEnergy(frame.samples)
        val dynamicThreshold = maxOf(baseEnergyThreshold, noiseFloor * 3.2)
        val rawSpeech = rmsEnergy >= dynamicThreshold

        // Hangover: hold speech=true for hangoverMs after energy drops.
        // This prevents mid-word flickering on weak phonemes and unvoiced consonants.
        val speech: Boolean
        if (rawSpeech) {
            hangoverCountdown = hangoverMs
            speech = true
        } else if (hangoverCountdown > 0) {
            hangoverCountdown -= 20 // FRAME_MS = 20ms
            speech = true
        } else {
            speech = false
        }

        if (!rawSpeech) {
            noiseFloor = (noiseFloor * 0.98) + (rmsEnergy * 0.02)
        }

        var speechStarted = false
        var pauseDetected = false
        var silenceMs = 0L

        if (speech) {
            if (!inSpeech) {
                speechStarted = true
                speechStartedAtMs = audioTimeMs
                inSpeech = true
            }
            lastSpeechAtMs = audioTimeMs
        } else if (inSpeech) {
            val lastSpeech = lastSpeechAtMs ?: audioTimeMs
            silenceMs = (audioTimeMs - lastSpeech).coerceAtLeast(0)

            val speechStartedAt = speechStartedAtMs
            val speechDuration = if (speechStartedAt == null) {
                0L
            } else {
                (lastSpeech - speechStartedAt).coerceAtLeast(0)
            }

            if (silenceMs >= silenceThresholdMs && speechDuration >= minSpeechDurationMs) {
                pauseDetected = true
                inSpeech = false
                speechStartedAtMs = null
                lastSpeechAtMs = null
            }
        }

        return VadDecision(
            isSpeech = speech,
            speechStarted = speechStarted,
            pauseDetected = pauseDetected,
            silenceDurationMs = silenceMs,
            energy = rmsEnergy,
        )
    }

    private fun calculateRmsEnergy(samples: ShortArray): Double {
        if (samples.isEmpty()) {
            return 0.0
        }

        var sumSquares = 0.0
        for (sample in samples) {
            val normalized = sample / 32768.0
            sumSquares += normalized * normalized
        }

        return sqrt(sumSquares / samples.size)
    }
}
