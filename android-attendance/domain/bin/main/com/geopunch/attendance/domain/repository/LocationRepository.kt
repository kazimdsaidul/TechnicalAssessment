package com.geopunch.attendance.domain.repository

import com.geopunch.attendance.domain.model.LocationResult
import kotlinx.coroutines.flow.Flow

interface LocationRepository {
    /** One-shot fetch, used by "Set Office Location". */
    suspend fun fetchCurrentLocation(): LocationResult

    /** Continuous stream, collected only while the attendance screen is visible. */
    fun observeLocation(): Flow<LocationResult>
}
