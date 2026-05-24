package com.wareeny.wareeny

import android.content.Context
import io.flutter.embedding.engine.loader.FlutterLoader
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import kotlin.math.max
import kotlin.math.min

class YoloLiteRtDetector(
    context: Context,
    flutterLoader: FlutterLoader,
    private val config: IndoorNavigationModelConfig,
) : AutoCloseable {
    private val labels: List<String> = loadLabels(context, flutterLoader, config.labelsPath)
    private val interpreter: Interpreter = Interpreter(loadModel(context, flutterLoader, config.modelPath))
    private val inputSize = interpreter.getInputTensor(0).shape().getOrNull(1) ?: config.inputSize
    private val outputShape = interpreter.getOutputTensor(0).shape()
    private val outputChannels = outputShape.getOrNull(1) ?: labels.size + 4
    private val outputBoxes = outputShape.getOrNull(2) ?: 8400
    private val input = ByteBuffer
        .allocateDirect(inputSize * inputSize * 3 * 4)
        .order(ByteOrder.nativeOrder())
    private val output = Array(1) { Array(outputChannels) { FloatArray(outputBoxes) } }

    @Synchronized
    fun detect(frame: RgbFrame): List<NormalizedDetection> {
        input.rewind()
        val scaleX = frame.width.toFloat() / inputSize
        val scaleY = frame.height.toFloat() / inputSize

        for (y in 0 until inputSize) {
            val srcY = min(frame.height - 1, (y * scaleY).toInt())
            for (x in 0 until inputSize) {
                val srcX = min(frame.width - 1, (x * scaleX).toInt())
                val color = frame.pixels[srcY * frame.width + srcX]
                input.putFloat(((color shr 16) and 0xFF) / 255f)
                input.putFloat(((color shr 8) and 0xFF) / 255f)
                input.putFloat((color and 0xFF) / 255f)
            }
        }

        interpreter.run(input, output)
        return nonMaxSuppression(decode(scaleX, scaleY))
    }

    override fun close() {
        interpreter.close()
    }

    private fun decode(scaleX: Float, scaleY: Float): List<NormalizedDetection> {
        val detections = mutableListOf<NormalizedDetection>()
        val classCount = min(labels.size, outputChannels - 4)
        for (boxIndex in 0 until outputBoxes) {
            var bestClass = -1
            var bestScore = 0f
            for (classIndex in 0 until classCount) {
                val score = output[0][4 + classIndex][boxIndex]
                if (score > bestScore) {
                    bestScore = score
                    bestClass = classIndex
                }
            }

            if (bestScore < config.confidenceThreshold || bestClass !in labels.indices) {
                continue
            }

            val cx = output[0][0][boxIndex] * scaleX
            val cy = output[0][1][boxIndex] * scaleY
            val width = output[0][2][boxIndex] * scaleX
            val height = output[0][3][boxIndex] * scaleY
            detections += NormalizedDetection(
                label = labels[bestClass],
                confidence = bestScore,
                x1 = cx - width / 2f,
                y1 = cy - height / 2f,
                x2 = cx + width / 2f,
                y2 = cy + height / 2f,
            )
        }
        return detections
    }

    private fun nonMaxSuppression(detections: List<NormalizedDetection>): List<NormalizedDetection> {
        val result = mutableListOf<NormalizedDetection>()
        val sorted = detections.sortedByDescending { it.confidence }.toMutableList()
        while (sorted.isNotEmpty() && result.size < MAX_DETECTIONS) {
            val best = sorted.removeAt(0)
            result += best
            sorted.removeAll { other -> other.label == best.label && iou(best, other) > config.nmsThreshold }
        }
        return result
    }

    private fun iou(a: NormalizedDetection, b: NormalizedDetection): Float {
        val left = max(a.x1, b.x1)
        val top = max(a.y1, b.y1)
        val right = min(a.x2, b.x2)
        val bottom = min(a.y2, b.y2)
        val intersection = max(0f, right - left) * max(0f, bottom - top)
        val areaA = max(0f, a.x2 - a.x1) * max(0f, a.y2 - a.y1)
        val areaB = max(0f, b.x2 - b.x1) * max(0f, b.y2 - b.y1)
        return intersection / max(1f, areaA + areaB - intersection)
    }

    private fun loadModel(
        context: Context,
        flutterLoader: FlutterLoader,
        modelAsset: String,
    ): MappedByteBuffer {
        val key = flutterLoader.getLookupKeyForAsset(modelAsset)
        context.assets.openFd(key).use { descriptor ->
            FileInputStream(descriptor.fileDescriptor).channel.use { channel ->
                return channel.map(
                    FileChannel.MapMode.READ_ONLY,
                    descriptor.startOffset,
                    descriptor.declaredLength,
                )
            }
        }
    }

    private fun loadLabels(
        context: Context,
        flutterLoader: FlutterLoader,
        labelsAsset: String,
    ): List<String> {
        val key = flutterLoader.getLookupKeyForAsset(labelsAsset)
        return context.assets.open(key).bufferedReader().useLines { lines ->
            lines.map { it.trim() }.filter { it.isNotEmpty() }.toList()
        }
    }

    companion object {
        private const val MAX_DETECTIONS = 20
    }
}
