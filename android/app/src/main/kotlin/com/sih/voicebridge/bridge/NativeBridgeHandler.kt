// package com.sih.voicebridge.bridge

// import android.content.Context
// import android.os.Handler
// import android.os.Looper
// import com.sih.voicebridge.pipeline.VoicePipelineOrchestrator
// import io.flutter.plugin.common.EventChannel
// import io.flutter.plugin.common.MethodCall
// import io.flutter.plugin.common.MethodChannel

// class NativeBridgeHandler(
//     context: Context,
// ) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

//     private val appContext = context.applicationContext
//     private val mainHandler = Handler(Looper.getMainLooper())
//     private var eventSink: EventChannel.EventSink? = null

//     private val orchestrator = VoicePipelineOrchestrator(context) { event ->
//         mainHandler.post {
//             eventSink?.success(event)
//         }
//     }

//     override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
//         try {
//             when (call.method) {
//                 "initializePipelines" -> {
//                     val languageCode = call.argument<String>("languageCode") ?: "en"
//                     orchestrator.initialize(languageCode)
//                     result.success(null)
//                 }

//                 "setLanguage" -> {
//                     val languageCode = call.argument<String>("languageCode") ?: "en"
//                     orchestrator.setLanguage(languageCode)
//                     result.success(null)
//                 }

//                 "setOperationMode" -> {
//                     val mode = call.argument<String>("mode") ?: "walkie_talkie"
//                     orchestrator.setOperationMode(mode)
//                     result.success(null)
//                 }

//                 "startListening" -> {
//                     val ptt = call.argument<Boolean>("ptt") ?: true
//                     val messageId = call.argument<String>("messageId")
//                     orchestrator.startListening(ptt, messageId)
//                     result.success(null)
//                 }

//                 "stopListening" -> {
//                     orchestrator.stopListening()
//                     result.success(null)
//                 }

//                 "speakText" -> {
//                     val text = call.argument<String>("text") ?: ""
//                     val languageCode = call.argument<String>("languageCode") ?: "en"
//                     val emergency = call.argument<Boolean>("emergency") ?: false
//                     val messageId = call.argument<String>("messageId")
//                     orchestrator.speakText(text, languageCode, emergency, messageId)
//                     result.success(null)
//                 }

//                 "setEmergencyOverride" -> {
//                     val enabled = call.argument<Boolean>("enabled") ?: false
//                     orchestrator.setEmergencyOverride(enabled)
//                     result.success(null)
//                 }

//                 "getAppDataDirectory" -> {
//                     result.success(appContext.filesDir.absolutePath)
//                 }

//                 else -> result.notImplemented()
//             }
//         } catch (error: Throwable) {
//             result.error("native_bridge_error", error.message, null)
//         }
//     }

//     override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
//         eventSink = events
//     }

//     override fun onCancel(arguments: Any?) {
//         orchestrator.dispose()
//         eventSink = null
//     }
// }
package com.sih.voicebridge.bridge

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.sih.voicebridge.location.LocationHelper
import com.sih.voicebridge.network.NetworkHelper
import com.sih.voicebridge.pipeline.VoicePipelineOrchestrator
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NativeBridgeHandler(
    context: Context,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val appContext = context.applicationContext

    private val locationHelper = LocationHelper(appContext)
    private val networkHelper = NetworkHelper(appContext)

    private val mainHandler =
        Handler(Looper.getMainLooper())

    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    @Volatile
    private var disposed = false

    private val orchestrator =
        VoicePipelineOrchestrator(appContext) { event ->
            /*
             * VoicePipelineOrchestrator can generate events from
             * background threads.
             *
             * Flutter EventChannel MUST receive events on the
             * Android main thread.
             */
            mainHandler.post {
                if (disposed) {
                    return@post
                }

                eventSink?.success(event)
            }
        }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        if (disposed) {
            result.error(
                "native_bridge_disposed",
                "Native bridge has already been disposed.",
                null,
            )
            return
        }

        try {
            when (call.method) {

                "initializePipelines" -> {
                    val languageCode =
                        call.argument<String>("languageCode")
                            ?: "en"

                    /*
                     * The orchestrator performs expensive initialization
                     * on its background executor.
                     */
                    orchestrator.initialize(languageCode)

                    /*
                     * Return immediately to Flutter.
                     */
                    result.success(null)
                }

                "setLanguage" -> {
                    val languageCode =
                        call.argument<String>("languageCode")
                            ?: "en"

                    orchestrator.setLanguage(languageCode)

                    result.success(null)
                }

                "setOperationMode" -> {
                    val mode =
                        call.argument<String>("mode")
                            ?: "walkie_talkie"

                    orchestrator.setOperationMode(mode)

                    result.success(null)
                }

                "startListening" -> {
                    val ptt =
                        call.argument<Boolean>("ptt")
                            ?: true

                    val messageId =
                        call.argument<String>("messageId")

                    orchestrator.startListening(
                        ptt = ptt,
                        messageId = messageId,
                        pressedAtEpochMs = call.argument<Number>("pressedAtEpochMs")?.toLong(),
                        requestedLanguage = call.argument<String>("languageCode"),
                    )

                    result.success(null)
                }

                "stopListening" -> {
                    orchestrator.stopListening(call.argument<String>("messageId"))

                    result.success(null)
                }

                "speakText" -> {
                    val text =
                        call.argument<String>("text")
                            ?: ""

                    val languageCode =
                        call.argument<String>("languageCode")
                            ?: "en"

                    val emergency =
                        call.argument<Boolean>("emergency")
                            ?: false

                    val messageId =
                        call.argument<String>("messageId")

                    orchestrator.speakText(
                        text = text,
                        languageCode = languageCode,
                        emergency = emergency,
                        messageId = messageId,
                    )

                    result.success(null)
                }

                "setEmergencyOverride" -> {
                    val enabled =
                        call.argument<Boolean>("enabled")
                            ?: false

                    orchestrator.setEmergencyOverride(enabled)

                    result.success(null)
                }

                "getAppDataDirectory" -> {
                    result.success(
                        appContext.filesDir.absolutePath
                    )
                }

                "getLocation" -> {
                    result.success(locationHelper.getCurrentLocation())
                }

                "hasLocationPermission" -> {
                    result.success(locationHelper.hasLocationPermission())
                }

                "startLocationUpdates" -> {
                    locationHelper.startListening()
                    result.success(true)
                }

                "stopLocationUpdates" -> {
                    locationHelper.stopListening()
                    result.success(true)
                }

                "getWifiGatewayIp" -> {
                    result.success(networkHelper.getWifiGatewayIp())
                }

                else -> {
                    result.notImplemented()
                }
            }
        } catch (error: Throwable) {
            result.error(
                "native_bridge_error",
                error.message
                    ?: error.javaClass.simpleName,
                null,
            )
        }
    }

    override fun onListen(
        arguments: Any?,
        events: EventChannel.EventSink?,
    ) {
        if (disposed) {
            return
        }

        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        /*
         * Cancel the Flutter event subscription, but do not
         * destroy the complete voice pipeline.
         */
        eventSink = null
    }

    fun dispose() {
        if (disposed) {
            return
        }

        disposed = true

        /*
         * Stop location updates.
         */
        locationHelper.stopListening()

        /*
         * Stop future events from reaching Flutter.
         */
        eventSink = null

        /*
         * Remove events that haven't executed yet.
         */
        mainHandler.removeCallbacksAndMessages(null)

        /*
         * Dispose native pipeline resources.
         */
        orchestrator.dispose()
    }
}
