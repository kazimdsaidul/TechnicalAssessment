package com.geopunch.attendance.domain.model

/**
 * Models location acquisition outcomes explicitly, including hardware/permission
 * failure modes, so the presentation layer never has to guess why a fetch failed.
 */
sealed interface LocationResult {
    data class Success(val coordinates: Coordinates, val accuracyMeters: Float) : LocationResult
    data object PermissionDenied : LocationResult
    data object LocationServicesDisabled : LocationResult
    data class Unavailable(val message: String) : LocationResult
}
