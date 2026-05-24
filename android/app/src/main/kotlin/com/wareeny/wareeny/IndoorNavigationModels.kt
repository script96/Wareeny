package com.wareeny.wareeny

data class NormalizedDetection(
    val label: String,
    val confidence: Float,
    val x1: Float,
    val y1: Float,
    val x2: Float,
    val y2: Float,
)

data class PathState(
    val code: String,
    val severity: String,
    val score: Double,
    val stateText: String,
    val objectLabel: String? = null,
)

data class RgbFrame(
    val width: Int,
    val height: Int,
    val pixels: IntArray,
)

data class CameraPlane(
    val bytes: ByteArray,
    val bytesPerRow: Int,
    val bytesPerPixel: Int,
)
