package com.geopunch.attendance.fake

import com.geopunch.attendance.domain.model.Coordinates
import com.geopunch.attendance.domain.repository.AttendanceRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

class FakeAttendanceRepository(
    initialOfficeLocation: Coordinates? = null,
    initialMarkedToday: Boolean = false,
) : AttendanceRepository {

    val officeLocationFlow = MutableStateFlow(initialOfficeLocation)
    val markedTodayFlow = MutableStateFlow(initialMarkedToday)

    override fun observeOfficeLocation(): StateFlow<Coordinates?> = officeLocationFlow

    override suspend fun saveOfficeLocation(coordinates: Coordinates) {
        officeLocationFlow.value = coordinates
    }

    override fun observeTodayAttendanceMarked(): StateFlow<Boolean> = markedTodayFlow

    override suspend fun markAttendanceNow() {
        markedTodayFlow.value = true
    }
}
