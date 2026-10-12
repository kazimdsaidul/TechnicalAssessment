package com.geopunch.attendance.domain.fake

import com.geopunch.attendance.domain.model.Coordinates
import com.geopunch.attendance.domain.repository.AttendanceRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

class FakeAttendanceRepository(
    initialOfficeLocation: Coordinates? = null,
    initialMarkedToday: Boolean = false,
) : AttendanceRepository {

    private val officeLocationFlow = MutableStateFlow(initialOfficeLocation)
    private val markedTodayFlow = MutableStateFlow(initialMarkedToday)

    var markAttendanceNowCallCount: Int = 0
        private set

    override fun observeOfficeLocation(): StateFlow<Coordinates?> = officeLocationFlow

    override suspend fun saveOfficeLocation(coordinates: Coordinates) {
        officeLocationFlow.value = coordinates
    }

    override fun observeTodayAttendanceMarked(): StateFlow<Boolean> = markedTodayFlow

    override suspend fun markAttendanceNow() {
        markAttendanceNowCallCount++
        markedTodayFlow.value = true
    }

    fun setMarkedToday(marked: Boolean) {
        markedTodayFlow.value = marked
    }
}
