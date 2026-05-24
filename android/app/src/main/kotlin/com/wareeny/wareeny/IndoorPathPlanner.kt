package com.wareeny.wareeny

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

class IndoorPathPlanner {
    private val recentStates = ArrayDeque<String>()

    fun analyze(
        detections: List<NormalizedDetection>,
        frameWidth: Int,
        frameHeight: Int,
        brightness: Double,
    ): PathState {
        val raw = analyzeRaw(detections, frameWidth, frameHeight, brightness)
        recentStates.addLast(raw.stateText)
        while (recentStates.size > SMOOTHING_WINDOW) {
            recentStates.removeFirst()
        }

        val smoothed = smoothedState(raw.stateText)
        return if (smoothed == raw.stateText) raw else state(smoothed)
    }

    private fun analyzeRaw(
        detections: List<NormalizedDetection>,
        frameWidth: Int,
        frameHeight: Int,
        brightness: Double,
    ): PathState {
        if (brightness < DARK_FRAME_MEAN_THRESHOLD) {
            return state("LOW LIGHT - UNCERTAIN", 0.82)
        }

        val grid = buildOccupancyGrid(detections, frameWidth, frameHeight)
        val centerBounds = centerLaneBounds(frameWidth)
        var bestText = "CLEAR PATH"
        var bestDetection: NormalizedDetection? = null
        var bestScore = 0.0

        detections.forEach { detection ->
            val classified = classifyDetection(
                detection,
                frameWidth,
                frameHeight,
                centerBounds.first,
                centerBounds.second,
            )
            if (classified.first != "CLEAR PATH" &&
                (priority(classified.first) > priority(bestText) ||
                    (classified.first == bestText && classified.second > bestScore))
            ) {
                bestText = classified.first
                bestDetection = detection
                bestScore = classified.second
            }
        }

        val narrowPathScore = narrowPathScore(detections, frameWidth, frameHeight)
        val detection = bestDetection
        if (narrowPathScore > 0.0 &&
            (bestText in setOf(
                "CLEAR PATH",
                "CAUTION LEFT",
                "CAUTION RIGHT",
                "OBSTACLE AHEAD",
                "TRIP HAZARD CENTER",
            ) || (bestText == "PATH BLOCKED" && detection != null &&
                !fillsVirtualPath(detection, frameWidth, frameHeight)))
        ) {
            return state("NARROW PATH", narrowPathScore)
        }

        if (detection != null && bestText in setOf(
                "OBSTACLE AHEAD",
                "TRIP HAZARD CENTER",
                "PATH BLOCKED",
            )
        ) {
            val planned = planLocalRoute(grid, detection, frameWidth, frameHeight)
            return state(planned, bestScore, detection.label)
        }

        return state(bestText, bestScore, detection?.label)
    }

    private fun classifyDetection(
        detection: NormalizedDetection,
        frameWidth: Int,
        frameHeight: Int,
        centerLeft: Double,
        centerRight: Double,
    ): Pair<String, Double> {
        val width = max(0.0, (detection.x2 - detection.x1).toDouble())
        val height = max(0.0, (detection.y2 - detection.y1).toDouble())
        val areaRatio = (width * height) / (frameWidth.toDouble() * frameHeight.toDouble())
        val boxCenterX = (detection.x1 + detection.x2) / 2.0
        val bottomRatio = detection.y2 / frameHeight.toDouble()
        val depthBand = depthBand(bottomRatio)
        val lowerFrame = bottomRatio >= LOWER_FRAME_START_RATIO
        val nearFloor = bottomRatio >= NEAR_BOTTOM_RATIO
        val veryNear = bottomRatio >= VERY_NEAR_BOTTOM_RATIO
        val triangle = pathTriangle(frameWidth, frameHeight)
        val triangleOverlap = triangleBoxOverlapRatio(detection, triangle)
        val triangleFill = triangleFillRatio(detection, triangle, frameHeight)
        val centerOverlap = overlapRatio(detection.x1.toDouble(), detection.x2.toDouble(), centerLeft, centerRight)
        val inCenterLane = centerOverlap >= CENTER_OVERLAP_RATIO ||
            triangleOverlap >= TRIANGLE_WARNING_OVERLAP_RATIO
        val tripClass = TRIP_HAZARD_CLASSES.contains(detection.label.lowercase())
        val largeObject = areaRatio >= LARGE_BOX_AREA_RATIO
        val meaningfulTripSize = areaRatio >= MIN_TRIP_AREA_RATIO
        val riskScore = (
            detection.confidence * 0.35 +
                min(areaRatio / LARGE_BOX_AREA_RATIO, 1.0) * 0.25 +
                bottomRatio * 0.25 +
                max(centerOverlap, triangleOverlap) * 0.15
            ).coerceIn(0.0, 1.0)
        val fillsVirtualPath = (
            depthBand != DepthBand.FAR &&
                triangleFill >= TRIANGLE_FILL_BLOCKED_RATIO
            ) || (
            nearFloor &&
                triangleFill >= TRIANGLE_NEAR_FILL_BLOCKED_RATIO
            )
        val collisionOverlap = triangleOverlap >= TRIANGLE_COLLISION_OVERLAP_RATIO

        if (inCenterLane &&
            (veryNear || fillsVirtualPath || (largeObject && lowerFrame && collisionOverlap))
        ) {
            return "PATH BLOCKED" to riskScore
        }

        if (inCenterLane && tripClass && nearFloor && meaningfulTripSize && collisionOverlap) {
            return "TRIP HAZARD CENTER" to riskScore
        }

        if (inCenterLane && (largeObject || (tripClass && lowerFrame) || collisionOverlap)) {
            return "OBSTACLE AHEAD" to riskScore
        }

        if (lowerFrame && (tripClass || largeObject)) {
            if (boxCenterX < centerLeft) return "CAUTION LEFT" to riskScore
            if (boxCenterX > centerRight) return "CAUTION RIGHT" to riskScore
        }

        return "CLEAR PATH" to riskScore
    }

    private fun smoothedState(fallback: String): String {
        if (recentStates.size < REQUIRED_VOTES) return fallback
        val counts = recentStates.groupingBy { it }.eachCount()
        val candidates = counts.filterValues { it >= REQUIRED_VOTES }.keys
        if (candidates.isEmpty()) return fallback
        return candidates.maxBy { priority(it) }
    }

    private fun planLocalRoute(
        grid: Map<DepthBand, Map<Lane, Double>>,
        blockingDetection: NormalizedDetection,
        frameWidth: Int,
        frameHeight: Int,
    ): String {
        if (fillsVirtualPath(blockingDetection, frameWidth, frameHeight)) {
            return "PATH BLOCKED"
        }

        val obstacleBand = depthBand(blockingDetection.y2 / frameHeight.toDouble())
        val nearCenter = grid.getValue(DepthBand.NEAR).getValue(Lane.CENTER)
        val leftNear = grid.getValue(DepthBand.NEAR).getValue(Lane.LEFT)
        val rightNear = grid.getValue(DepthBand.NEAR).getValue(Lane.RIGHT)
        val leftRoute = routeScore(grid, Lane.LEFT)
        val rightRoute = routeScore(grid, Lane.RIGHT)
        val leftIsClear = leftNear < SIDE_CLEAR_SCORE_THRESHOLD
        val rightIsClear = rightNear < SIDE_CLEAR_SCORE_THRESHOLD
        val centerIsClearNow = nearCenter < CENTER_CLEAR_SCORE_THRESHOLD
        val blockerCenter = (blockingDetection.x1 + blockingDetection.x2) / 2.0

        if (obstacleBand in setOf(DepthBand.FAR, DepthBand.MID) && centerIsClearNow) {
            return delayedTurnState(leftRoute, rightRoute, blockerCenter, frameWidth)
        }

        if (leftIsClear && rightIsClear) {
            return immediateTurnState(leftRoute, rightRoute, blockerCenter, frameWidth)
        }

        if (leftIsClear) return "MOVE LEFT"
        if (rightIsClear) return "MOVE RIGHT"
        return "PATH BLOCKED"
    }

    private fun fillsVirtualPath(
        detection: NormalizedDetection,
        frameWidth: Int,
        frameHeight: Int,
    ): Boolean {
        val bottomRatio = detection.y2 / frameHeight.toDouble()
        if (depthBand(bottomRatio) == DepthBand.FAR) return false
        val triangleFill = triangleFillRatio(detection, pathTriangle(frameWidth, frameHeight), frameHeight)
        return triangleFill >= TRIANGLE_FILL_BLOCKED_RATIO ||
            (bottomRatio >= NEAR_BOTTOM_RATIO && triangleFill >= TRIANGLE_NEAR_FILL_BLOCKED_RATIO)
    }

    private fun delayedTurnState(
        leftRoute: Double,
        rightRoute: Double,
        blockerCenter: Double,
        frameWidth: Int,
    ): String {
        if (abs(leftRoute - rightRoute) <= ROUTE_BALANCE_MARGIN) {
            if (blockerCenter < frameWidth / 2.0) return "FORWARD THEN SLIGHT RIGHT"
            if (blockerCenter > frameWidth / 2.0) return "FORWARD THEN SLIGHT LEFT"
            return "FORWARD A LITTLE"
        }
        if (leftRoute < rightRoute) return "FORWARD THEN SLIGHT LEFT"
        if (rightRoute < leftRoute) return "FORWARD THEN SLIGHT RIGHT"
        return "PATH BLOCKED"
    }

    private fun immediateTurnState(
        leftRoute: Double,
        rightRoute: Double,
        blockerCenter: Double,
        frameWidth: Int,
    ): String {
        if (abs(leftRoute - rightRoute) <= ROUTE_BALANCE_MARGIN) {
            if (blockerCenter < frameWidth / 2.0) return "MOVE RIGHT"
            if (blockerCenter > frameWidth / 2.0) return "MOVE LEFT"
            return "PATH BLOCKED"
        }
        if (leftRoute < rightRoute) return "MOVE LEFT"
        if (rightRoute < leftRoute) return "MOVE RIGHT"
        return "PATH BLOCKED"
    }

    private fun buildOccupancyGrid(
        detections: List<NormalizedDetection>,
        frameWidth: Int,
        frameHeight: Int,
    ): Map<DepthBand, Map<Lane, Double>> {
        val grid = DepthBand.values().associateWith {
            mutableMapOf(Lane.LEFT to 0.0, Lane.CENTER to 0.0, Lane.RIGHT to 0.0)
        }
        val lanes = mapOf(
            Lane.LEFT to (0.0 to frameWidth / 3.0),
            Lane.CENTER to (frameWidth / 3.0 to frameWidth * 2.0 / 3.0),
            Lane.RIGHT to (frameWidth * 2.0 / 3.0 to frameWidth.toDouble()),
        )

        detections.forEach { detection ->
            val bottomRatio = detection.y2 / frameHeight.toDouble()
            if (bottomRatio < FAR_BAND_START_RATIO) return@forEach

            val width = max(0.0, (detection.x2 - detection.x1).toDouble())
            val height = max(0.0, (detection.y2 - detection.y1).toDouble())
            val areaRatio = (width * height) / (frameWidth.toDouble() * frameHeight.toDouble())
            val band = depthBand(bottomRatio)
            val classWeight = if (TRIP_HAZARD_CLASSES.contains(detection.label.lowercase())) 1.0 else 0.55
            val baseScore = detection.confidence *
                classWeight *
                (0.45 + min(areaRatio / LARGE_BOX_AREA_RATIO, 1.0)) *
                bottomRatio

            lanes.forEach { (lane, bounds) ->
                val overlap = overlapRatio(
                    detection.x1.toDouble(),
                    detection.x2.toDouble(),
                    bounds.first,
                    bounds.second,
                )
                if (overlap > 0.0) {
                    val laneGrid = grid.getValue(band)
                    laneGrid[lane] = laneGrid.getValue(lane) + baseScore * overlap
                }
            }
        }

        return grid
    }

    private fun narrowPathScore(
        detections: List<NormalizedDetection>,
        frameWidth: Int,
        frameHeight: Int,
    ): Double {
        val triangle = pathTriangle(frameWidth, frameHeight)
        var leftFill = 0.0
        var rightFill = 0.0
        var centerFill = 0.0

        detections.forEach { detection ->
            val bottomRatio = detection.y2 / frameHeight.toDouble()
            if (bottomRatio < MID_BAND_START_RATIO) return@forEach

            val side = triangleSideFill(detection, triangle, frameHeight)
            if (fillsVirtualPath(detection, frameWidth, frameHeight)) {
                centerFill = max(centerFill, side.getValue(Lane.CENTER))
                return@forEach
            }

            leftFill = max(leftFill, side.getValue(Lane.LEFT))
            rightFill = max(rightFill, side.getValue(Lane.RIGHT))
            centerFill = max(centerFill, side.getValue(Lane.CENTER))
        }

        val leftPresent = leftFill >= NARROW_PATH_SIDE_FILL_RATIO
        val rightPresent = rightFill >= NARROW_PATH_SIDE_FILL_RATIO
        val centerOpen = centerFill <= NARROW_PATH_CENTER_FILL_MAX_RATIO
        return if (leftPresent && rightPresent && centerOpen) {
            min(leftFill, rightFill) + (1.0 - centerFill) * 0.25
        } else {
            0.0
        }
    }

    private fun triangleSideFill(
        detection: NormalizedDetection,
        triangle: PathTriangle,
        frameHeight: Int,
    ): Map<Lane, Double> {
        val y1 = max(detection.y1.toDouble(), triangle.apexY)
        val y2 = min(detection.y2.toDouble(), triangle.bottomY)
        if (y2 <= y1) return mapOf(Lane.LEFT to 0.0, Lane.CENTER to 0.0, Lane.RIGHT to 0.0)

        val fills = mutableMapOf(Lane.LEFT to 0.0, Lane.CENTER to 0.0, Lane.RIGHT to 0.0)
        repeat(TRIANGLE_SAMPLE_ROWS) { index ->
            val y = y1 + ((index + 0.5) / TRIANGLE_SAMPLE_ROWS) * (y2 - y1)
            val bounds = triangleBoundsAtY(triangle, y)
            val pathWidth = max(1.0, bounds.second - bounds.first)
            val laneWidth = pathWidth / 3.0
            val lanes = mapOf(
                Lane.LEFT to (bounds.first to bounds.first + laneWidth),
                Lane.CENTER to (bounds.first + laneWidth to bounds.second - laneWidth),
                Lane.RIGHT to (bounds.second - laneWidth to bounds.second),
            )
            lanes.forEach { (lane, laneBounds) ->
                val overlap = max(
                    0.0,
                    min(detection.x2.toDouble(), laneBounds.second) -
                        max(detection.x1.toDouble(), laneBounds.first),
                )
                fills[lane] = fills.getValue(lane) + overlap / max(1.0, laneBounds.second - laneBounds.first)
            }
        }

        val depthWeight = when (depthBand(detection.y2 / frameHeight.toDouble())) {
            DepthBand.FAR -> 0.65
            DepthBand.MID -> 0.85
            DepthBand.NEAR -> 1.0
        }
        return fills.mapValues { it.value / TRIANGLE_SAMPLE_ROWS * depthWeight }
    }

    private fun pathTriangle(frameWidth: Int, frameHeight: Int): PathTriangle {
        val center = frameWidth / 2.0
        val topY = frameHeight * PATH_TRIANGLE_TOP_Y_RATIO
        val bottomY = frameHeight.toDouble()
        val topHalfWidth = frameWidth * PATH_TRIANGLE_TOP_WIDTH_RATIO / 2.0
        val bottomHalfWidth = frameWidth * PATH_TRIANGLE_BOTTOM_WIDTH_RATIO / 2.0
        return PathTriangle(
            apexY = topY,
            topLeftX = center - topHalfWidth,
            topRightX = center + topHalfWidth,
            bottomLeftX = center - bottomHalfWidth,
            bottomRightX = center + bottomHalfWidth,
            bottomY = bottomY,
        )
    }

    private fun triangleBoundsAtY(triangle: PathTriangle, y: Double): Pair<Double, Double> {
        if (y <= triangle.apexY) return triangle.topLeftX to triangle.topRightX
        val progress = ((y - triangle.apexY) / (triangle.bottomY - triangle.apexY)).coerceIn(0.0, 1.0)
        val left = triangle.topLeftX + (triangle.bottomLeftX - triangle.topLeftX) * progress
        val right = triangle.topRightX + (triangle.bottomRightX - triangle.topRightX) * progress
        return left to right
    }

    private fun triangleBoxOverlapRatio(
        detection: NormalizedDetection,
        triangle: PathTriangle,
    ): Double {
        val y1 = max(detection.y1.toDouble(), triangle.apexY)
        val y2 = min(detection.y2.toDouble(), triangle.bottomY)
        if (y2 <= y1) return 0.0

        var total = 0.0
        repeat(TRIANGLE_SAMPLE_ROWS) { index ->
            val y = y1 + ((index + 0.5) / TRIANGLE_SAMPLE_ROWS) * (y2 - y1)
            val bounds = triangleBoundsAtY(triangle, y)
            total += overlapRatio(
                detection.x1.toDouble(),
                detection.x2.toDouble(),
                bounds.first,
                bounds.second,
            )
        }
        return total / TRIANGLE_SAMPLE_ROWS
    }

    private fun triangleFillRatio(
        detection: NormalizedDetection,
        triangle: PathTriangle,
        frameHeight: Int,
    ): Double {
        val y1 = max(detection.y1.toDouble(), triangle.apexY)
        val y2 = min(detection.y2.toDouble(), triangle.bottomY)
        if (y2 <= y1) return 0.0

        var total = 0.0
        repeat(TRIANGLE_SAMPLE_ROWS) { index ->
            val y = y1 + ((index + 0.5) / TRIANGLE_SAMPLE_ROWS) * (y2 - y1)
            val bounds = triangleBoundsAtY(triangle, y)
            val pathWidth = max(1.0, bounds.second - bounds.first)
            val overlap = max(
                0.0,
                min(detection.x2.toDouble(), bounds.second) -
                    max(detection.x1.toDouble(), bounds.first),
            )
            total += overlap / pathWidth
        }

        val depthWeight = when (depthBand(detection.y2 / frameHeight.toDouble())) {
            DepthBand.FAR -> 0.65
            DepthBand.MID -> 0.85
            DepthBand.NEAR -> 1.0
        }
        return total / TRIANGLE_SAMPLE_ROWS * depthWeight
    }

    private fun routeScore(grid: Map<DepthBand, Map<Lane, Double>>, lane: Lane): Double {
        return grid.getValue(DepthBand.NEAR).getValue(lane) * 1.0 +
            grid.getValue(DepthBand.MID).getValue(lane) * 0.7 +
            grid.getValue(DepthBand.FAR).getValue(lane) * 0.45
    }

    private fun depthBand(bottomRatio: Double): DepthBand {
        if (bottomRatio >= NEAR_BAND_START_RATIO) return DepthBand.NEAR
        if (bottomRatio >= MID_BAND_START_RATIO) return DepthBand.MID
        return DepthBand.FAR
    }

    private fun centerLaneBounds(frameWidth: Int): Pair<Double, Double> {
        val laneWidth = frameWidth * CENTER_LANE_WIDTH_RATIO
        val center = frameWidth / 2.0
        return center - laneWidth / 2.0 to center + laneWidth / 2.0
    }

    private fun overlapRatio(x1: Double, x2: Double, laneX1: Double, laneX2: Double): Double {
        val overlap = max(0.0, min(x2, laneX2) - max(x1, laneX1))
        val boxWidth = max(1.0, x2 - x1)
        return overlap / boxWidth
    }

    private enum class Lane { LEFT, CENTER, RIGHT }

    private enum class DepthBand { FAR, MID, NEAR }

    private data class PathTriangle(
        val apexY: Double,
        val topLeftX: Double,
        val topRightX: Double,
        val bottomLeftX: Double,
        val bottomRightX: Double,
        val bottomY: Double,
    )

    companion object {
        const val DARK_FRAME_MEAN_THRESHOLD = 30.0

        private const val CENTER_LANE_WIDTH_RATIO = 0.42
        private const val PATH_TRIANGLE_TOP_Y_RATIO = 0.28
        private const val PATH_TRIANGLE_TOP_WIDTH_RATIO = 0.12
        private const val PATH_TRIANGLE_BOTTOM_WIDTH_RATIO = 0.82
        private const val TRIANGLE_SAMPLE_ROWS = 7
        private const val TRIANGLE_COLLISION_OVERLAP_RATIO = 0.28
        private const val TRIANGLE_WARNING_OVERLAP_RATIO = 0.1
        private const val TRIANGLE_FILL_BLOCKED_RATIO = 0.46
        private const val TRIANGLE_NEAR_FILL_BLOCKED_RATIO = 0.32
        private const val NARROW_PATH_SIDE_FILL_RATIO = 0.18
        private const val NARROW_PATH_CENTER_FILL_MAX_RATIO = 0.28
        private const val LOWER_FRAME_START_RATIO = 0.48
        private const val NEAR_BOTTOM_RATIO = 0.78
        private const val VERY_NEAR_BOTTOM_RATIO = 0.9
        private const val LARGE_BOX_AREA_RATIO = 0.13
        private const val CENTER_OVERLAP_RATIO = 0.18
        private const val MIN_TRIP_AREA_RATIO = 0.015
        private const val FAR_BAND_START_RATIO = 0.48
        private const val MID_BAND_START_RATIO = 0.66
        private const val NEAR_BAND_START_RATIO = 0.82
        private const val SIDE_CLEAR_SCORE_THRESHOLD = 0.55
        private const val CENTER_CLEAR_SCORE_THRESHOLD = 0.35
        private const val ROUTE_BALANCE_MARGIN = 0.12
        private const val SMOOTHING_WINDOW = 5
        private const val REQUIRED_VOTES = 2

        private val TRIP_HAZARD_CLASSES = setOf(
            "chair",
            "couch",
            "bench",
            "dining table",
            "table",
            "person",
            "backpack",
            "handbag",
            "suitcase",
            "sports ball",
            "potted plant",
            "bed",
            "toilet",
            "tv",
            "refrigerator",
            "microwave",
            "oven",
            "sink",
            "laptop",
            "keyboard",
            "book",
            "box",
            "bottle",
        )

        fun state(stateText: String, score: Double = 0.0, objectLabel: String? = null): PathState {
            return PathState(
                code = codeFor(stateText),
                severity = severityFor(stateText),
                score = score.coerceIn(0.0, 1.0),
                stateText = stateText,
                objectLabel = objectLabel,
            )
        }

        private fun priority(stateText: String): Int {
            return when (stateText) {
                "CLEAR PATH" -> 0
                "CAUTION LEFT", "CAUTION RIGHT" -> 1
                "OBSTACLE AHEAD", "FORWARD A LITTLE", "KEEP LEFT", "KEEP RIGHT", "NARROW PATH" -> 2
                "TRIP HAZARD CENTER",
                "MOVE LEFT",
                "MOVE RIGHT",
                "FORWARD THEN SLIGHT LEFT",
                "FORWARD THEN SLIGHT RIGHT",
                -> 3
                "PATH BLOCKED" -> 4
                "LOW LIGHT - UNCERTAIN" -> 5
                else -> 5
            }
        }

        private fun codeFor(stateText: String): String {
            return when (stateText) {
                "CLEAR PATH" -> "clear_path"
                "CAUTION LEFT" -> "caution_left"
                "CAUTION RIGHT" -> "caution_right"
                "OBSTACLE AHEAD" -> "obstacle_ahead"
                "TRIP HAZARD CENTER" -> "trip_hazard_center"
                "MOVE LEFT" -> "move_left"
                "MOVE RIGHT" -> "move_right"
                "FORWARD A LITTLE" -> "forward_keep_center"
                "FORWARD THEN SLIGHT LEFT" -> "forward_then_slight_left"
                "FORWARD THEN SLIGHT RIGHT" -> "forward_then_slight_right"
                "KEEP LEFT" -> "keep_left"
                "KEEP RIGHT" -> "keep_right"
                "NARROW PATH" -> "narrow_path"
                "PATH BLOCKED" -> "path_blocked"
                "LOW LIGHT - UNCERTAIN" -> "low_light_uncertain"
                else -> "low_light_uncertain"
            }
        }

        private fun severityFor(stateText: String): String {
            return when (stateText) {
                "CLEAR PATH" -> "clear"
                "OBSTACLE AHEAD", "TRIP HAZARD CENTER" -> "obstacle"
                "PATH BLOCKED" -> "danger"
                "LOW LIGHT - UNCERTAIN" -> "uncertain"
                else -> "navigationCue"
            }
        }
    }
}
