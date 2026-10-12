package com.geopunch.attendance.domain.usecase

import com.geopunch.attendance.domain.model.Coordinates
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/** Great-circle distance between two coordinates, in meters (Haversine formula). */
class CalculateDistanceUseCase {
    operator fun invoke(from: Coordinates, to: Coordinates): Double {
        val lat1 = Math.toRadians(from.latitude)
        val lat2 = Math.toRadians(to.latitude)
        val dLat = Math.toRadians(to.latitude - from.latitude)
        val dLon = Math.toRadians(to.longitude - from.longitude)

        val sinDLat = sin(dLat / 2)
        val sinDLon = sin(dLon / 2)
        val a = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLon * sinDLon
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return EARTH_RADIUS_METERS * c
    }

    private companion object {
        const val EARTH_RADIUS_METERS = 6_371_000.0
    }
}
