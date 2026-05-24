package com.wareeny.wareeny

import android.os.Bundle
import android.speech.tts.TextToSpeech
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private var textToSpeech: TextToSpeech? = null
    private var pendingSpeech: String? = null
    private var indoorEvents: EventChannel.EventSink? = null
    private var indoorNavigationRunning = false
    private var indoorNavigationEngine: IndoorNavigationEngine? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        textToSpeech = TextToSpeech(this, this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AUDIO_HAPTICS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "audio.speak" -> {
                    val text = call.argument<String>("text").orEmpty()
                    val interrupt = call.argument<Boolean>("interrupt") ?: true
                    speak(text, interrupt)
                    result.success(null)
                }
                "audio.stopSpeech" -> {
                    textToSpeech?.stop()
                    result.success(null)
                }
                "haptics.play" -> result.success(null)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INDOOR_NAVIGATION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "indoorNav.start" -> {
                    indoorNavigationRunning = true
                    ensureIndoorNavigationEngine().start()
                    result.success(null)
                }
                "indoorNav.stop" -> {
                    indoorNavigationRunning = false
                    indoorNavigationEngine?.stop()
                    result.success(null)
                }
                "indoorNav.processFrame" -> {
                    indoorNavigationEngine?.processFrame(call.arguments as? Map<*, *>)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INDOOR_NAVIGATION_EVENTS_CHANNEL,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    indoorEvents = events
                }

                override fun onCancel(arguments: Any?) {
                    indoorEvents = null
                }
            },
        )
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            val egyptianArabic = Locale("ar", "EG")
            val result = textToSpeech?.setLanguage(egyptianArabic)
            if (result == TextToSpeech.LANG_MISSING_DATA ||
                result == TextToSpeech.LANG_NOT_SUPPORTED
            ) {
                textToSpeech?.language = Locale("ar")
            }
            pendingSpeech?.let { speak(it, interrupt = true) }
            pendingSpeech = null
        }
    }

    override fun onDestroy() {
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        indoorNavigationEngine?.close()
        indoorNavigationEngine = null
        super.onDestroy()
    }

    private fun speak(text: String, interrupt: Boolean) {
        val engine = textToSpeech
        if (engine == null) {
            pendingSpeech = text
            return
        }

        if (interrupt) {
            engine.stop()
        }
        val queueMode = if (interrupt) TextToSpeech.QUEUE_FLUSH else TextToSpeech.QUEUE_ADD
        engine.speak(text, queueMode, null, "wareeny-indoor-nav")
    }

    private fun ensureIndoorNavigationEngine(): IndoorNavigationEngine {
        val existing = indoorNavigationEngine
        if (existing != null) {
            return existing
        }

        val created = IndoorNavigationEngine(
            context = this,
            flutterLoader = FlutterInjector.instance().flutterLoader(),
            emitState = { state ->
                runOnUiThread {
                    emitPathState(
                        code = state.code,
                        severity = state.severity,
                        score = state.score,
                        stateText = state.stateText,
                        objectLabel = state.objectLabel,
                    )
                }
            },
        )
        indoorNavigationEngine = created
        return created
    }

    @Suppress("unused")
    private fun emitPathState(
        code: String,
        severity: String,
        score: Double,
        stateText: String,
        objectLabel: String? = null,
    ) {
        if (!indoorNavigationRunning) {
            return
        }

        indoorEvents?.success(
            mapOf(
                "code" to code,
                "severity" to severity,
                "score" to score,
                "stateText" to stateText,
                "objectLabel" to objectLabel,
                "timestampMillis" to System.currentTimeMillis(),
            ),
        )
    }

    private companion object {
        const val AUDIO_HAPTICS_CHANNEL = "com.wareeny.bridge/audio_haptics"
        const val INDOOR_NAVIGATION_CHANNEL = "com.wareeny.bridge/indoor_navigation"
        const val INDOOR_NAVIGATION_EVENTS_CHANNEL =
            "com.wareeny.bridge/indoor_navigation/events"
    }
}
