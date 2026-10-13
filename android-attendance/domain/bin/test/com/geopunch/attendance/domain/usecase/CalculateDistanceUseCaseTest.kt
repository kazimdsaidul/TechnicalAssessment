package com.geopunch.attendance.domain.usecase

import com.geopunch.attendance.domain.model.Coordinates
import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class CalculateDistanceUseCaseTest {

    private val calculateDistance = CalculateDistanceUseCase()

    @Test
    fun `same point is zero meters`() {
        val point = Coordinates(40.7128, -74.0060)
        assertEquals(0.0, calculateDistance(point, point), 0.0001)
    }

    @Test
    fun `known distance between two NYC points is approximately correct`() {
        // Times Square to Central Park, ~3.3km apart.
        val timesSquare = Coordinates(40.7580, -73.9855)
        val centralPark = Coordinates(40.7829, -73.9654)

        val distance = calculateDistance(timesSquare, centralPark)

        assertTrue(distance in 3000.0..3700.0, "Expected ~3.3km, got ${distance}m")
    }

    @Test
    fun `49point99 meters is within the 50m radius`() {
        val office = Coordinates(40.7128, -74.0060)
        val nearby = offsetNorthBy(office, metersNorth = 49.99)

        assertTrue(calculateDistance(office, nearby) <= 50.0)
    }

    @Test
    fun `exactly 50 meters is within the inclusive radius`() {
        val office = Coordinates(40.7128, -74.0060)
        val nearby = offsetNorthBy(office, metersNorth = 50.0)

        val distance = calculateDistance(office, nearby)
        assertTrue(abs(distance - 50.0) < 0.5, "Expected ~50.0m, got ${distance}m")
    }

    @Test
    fun `50point01 meters is outside the radius`() {
        val office = Coordinates(40.7128, -74.0060)
        val tooFar = offsetNorthBy(office, metersNorth = 50.01)

        assertTrue(calculateDistance(office, tooFar) > 50.0)
    }

    /**
     * Offsets a coordinate north by [metersNorth]. Uses the same spherical-Earth radius as
     * [CalculateDistanceUseCase] itself, so fine-grained boundary offsets (e.g. 50.01m) round-trip
     * through Haversine without model-mismatch error.
     */
    private fun offsetNorthBy(origin: Coordinates, metersNorth: Double): Coordinates {
        val metersPerDegreeLatitude = Math.PI / 180.0 * 6_371_000.0
        return origin.copy(latitude = origin.latitude + metersNorth / metersPerDegreeLatitude)
    }
}
