package com.wareeny.wareeny

import kotlin.math.max
import kotlin.math.min

object IndoorCameraFrameConverter {
    fun fromArguments(arguments: Map<*, *>): Pair<RgbFrame, Double>? {
        val width = arguments["width"] as? Int ?: return null
        val height = arguments["height"] as? Int ?: return null
        val planes = (arguments["planes"] as? List<*>)?.mapNotNull { item ->
            val map = item as? Map<*, *> ?: return@mapNotNull null
            CameraPlane(
                bytes = map["bytes"] as? ByteArray ?: return@mapNotNull null,
                bytesPerRow = map["bytesPerRow"] as? Int ?: return@mapNotNull null,
                bytesPerPixel = map["bytesPerPixel"] as? Int ?: 1,
            )
        } ?: return null

        if (planes.isEmpty()) return null
        val brightness = brightness(planes[0].bytes)
        val pixels = if (planes.size >= 3) {
            yuv420ToRgb(width, height, planes)
        } else {
            grayscaleToRgb(width, height, planes[0])
        }
        return RgbFrame(width, height, pixels) to brightness
    }

    private fun brightness(bytes: ByteArray): Double {
        if (bytes.isEmpty()) return 0.0
        var sum = 0L
        var count = 0
        val stride = max(1, bytes.size / 2048)
        var index = 0
        while (index < bytes.size) {
            sum += bytes[index].toInt() and 0xFF
            count += 1
            index += stride
        }
        return if (count == 0) 0.0 else sum.toDouble() / count.toDouble()
    }

    private fun grayscaleToRgb(width: Int, height: Int, plane: CameraPlane): IntArray {
        return IntArray(width * height) { index ->
            val y = index / width
            val x = index % width
            val value = plane.bytes.getOrNull(y * plane.bytesPerRow + x)?.toInt()?.and(0xFF) ?: 0
            (value shl 16) or (value shl 8) or value
        }
    }

    private fun yuv420ToRgb(width: Int, height: Int, planes: List<CameraPlane>): IntArray {
        val yPlane = planes[0]
        val uPlane = planes[1]
        val vPlane = planes[2]
        val pixels = IntArray(width * height)

        for (y in 0 until height) {
            for (x in 0 until width) {
                val yValue = yPlane.bytes.getOrNull(y * yPlane.bytesPerRow + x)?.toInt()?.and(0xFF) ?: 0
                val uvX = x / 2
                val uvY = y / 2
                val uIndex = uvY * uPlane.bytesPerRow + uvX * uPlane.bytesPerPixel
                val vIndex = uvY * vPlane.bytesPerRow + uvX * vPlane.bytesPerPixel
                val uValue = (uPlane.bytes.getOrNull(uIndex)?.toInt()?.and(0xFF) ?: 128) - 128
                val vValue = (vPlane.bytes.getOrNull(vIndex)?.toInt()?.and(0xFF) ?: 128) - 128
                val r = (yValue + 1.402f * vValue).toInt().coerceIn(0, 255)
                val g = (yValue - 0.344136f * uValue - 0.714136f * vValue).toInt().coerceIn(0, 255)
                val b = (yValue + 1.772f * uValue).toInt().coerceIn(0, 255)
                pixels[y * width + x] = (r shl 16) or (g shl 8) or b
            }
        }

        return pixels
    }
}
