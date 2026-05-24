package com.wareeny.wareeny

import android.content.Context
import io.flutter.embedding.engine.loader.FlutterLoader
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class IndoorNavigationEngine(
    context: Context,
    flutterLoader: FlutterLoader,
    private val emitState: (PathState) -> Unit,
) : AutoCloseable {
    private val appContext = context.applicationContext
    private val loader = flutterLoader
    private val executor = Executors.newSingleThreadExecutor()
    private val busy = AtomicBoolean(false)
    private val planner = IndoorPathPlanner()
    private var running = false
    private var detector: YoloLiteRtDetector? = null
    private var detectorLoadFailed = false

    fun start() {
        running = true
        executor.execute {
            try {
                if (detector == null && !detectorLoadFailed) {
                    val config = IndoorNavigationModelConfig.load(appContext, loader)
                    detector = YoloLiteRtDetector(appContext, loader, config)
                }
            } catch (_: Throwable) {
                detectorLoadFailed = true
                emitState(IndoorPathPlanner.state("LOW LIGHT - UNCERTAIN", 0.58))
            }
        }
    }

    fun stop() {
        running = false
        busy.set(false)
    }

    fun processFrame(arguments: Map<*, *>?) {
        if (!running || arguments == null || !busy.compareAndSet(false, true)) {
            return
        }

        executor.execute {
            try {
                val converted = IndoorCameraFrameConverter.fromArguments(arguments) ?: return@execute
                val frame = converted.first
                val brightness = converted.second
                val state = if (brightness < IndoorPathPlanner.DARK_FRAME_MEAN_THRESHOLD) {
                    IndoorPathPlanner.state("LOW LIGHT - UNCERTAIN", 0.82)
                } else {
                    val activeDetector = detector ?: return@execute
                    val detections = activeDetector.detect(frame)
                    planner.analyze(detections, frame.width, frame.height, brightness)
                }
                emitState(state)
            } catch (_: Throwable) {
                emitState(IndoorPathPlanner.state("LOW LIGHT - UNCERTAIN", 0.58))
            } finally {
                busy.set(false)
            }
        }
    }

    override fun close() {
        running = false
        detector?.close()
        detector = null
        executor.shutdownNow()
    }
}
