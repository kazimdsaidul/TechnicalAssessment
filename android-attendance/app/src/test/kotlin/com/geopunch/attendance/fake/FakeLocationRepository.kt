package com.geopunch.attendance.fake

import com.geopunch.attendance.domain.model.LocationResult
import com.geopunch.attendance.domain.repository.LocationRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow

class FakeLocationRepository : LocationRepository {
    val locationUpdates = MutableSharedFlow<LocationResult>(replay = 0, extraBufferCapacity = 10)
    var fetchCurrentLocationResult: LocationResult = LocationResult.Unavailable("not configured")

    override suspend fun fetchCurrentLocation(): LocationResult = fetchCurrentLocationResult

    override fun observeLocation(): Flow<LocationResult> = locationUpdates
}
