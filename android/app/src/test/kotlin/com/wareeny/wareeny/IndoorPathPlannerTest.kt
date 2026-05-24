package com.wareeny.wareeny

import org.junit.Assert.assertEquals
import org.junit.Test

class IndoorPathPlannerTest {
    @Test
    fun clearPathWhenNoDetections() {
        val state = IndoorPathPlanner().analyze(emptyList(), 640, 480, 120.0)

        assertEquals("CLEAR PATH", state.stateText)
    }

    @Test
    fun lowLightReturnsUncertainText() {
        val state = IndoorPathPlanner().analyze(emptyList(), 640, 480, 12.0)

        assertEquals("LOW LIGHT - UNCERTAIN", state.stateText)
    }

    @Test
    fun fullTriangleReturnsPathBlocked() {
        val state = IndoorPathPlanner().analyze(
            listOf(
                NormalizedDetection(
                    label = "chair",
                    confidence = 0.9f,
                    x1 = 150f,
                    y1 = 260f,
                    x2 = 500f,
                    y2 = 470f,
                ),
            ),
            640,
            480,
            120.0,
        )

        assertEquals("PATH BLOCKED", state.stateText)
    }

    @Test
    fun partialLeftObstacleSuggestsRight() {
        val planner = IndoorPathPlanner()
        val detection = NormalizedDetection(
            label = "chair",
            confidence = 0.9f,
            x1 = 150f,
            y1 = 250f,
            x2 = 300f,
            y2 = 360f,
        )

        val first = planner.analyze(listOf(detection), 640, 480, 120.0)
        val second = planner.analyze(listOf(detection), 640, 480, 120.0)

        assertEquals(first.stateText, second.stateText)
        assertEquals("FORWARD THEN SLIGHT RIGHT", second.stateText)
    }

    @Test
    fun twoSideObjectsReturnNarrowPath() {
        val detections = listOf(
            NormalizedDetection("chair", 0.9f, 90f, 320f, 230f, 470f),
            NormalizedDetection("chair", 0.9f, 410f, 320f, 550f, 470f),
        )

        val state = IndoorPathPlanner().analyze(detections, 640, 480, 120.0)

        assertEquals("NARROW PATH", state.stateText)
    }
}
