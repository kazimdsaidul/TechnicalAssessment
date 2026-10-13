package com.geopunch.attendance.domain.repository

import com.geopunch.attendance.domain.model.Coordinates
import kotlinx.coroutines.flow.Flow

interface AttendanceRepository {
    fun observeOfficeLocation(): Flow<Coordinates?>
    suspend fun saveOfficeLocation(coordinates: Coordinates)

    /** True once attendance has been marked for the current calendar day; resets on a new day. */
    fun observeTodayAttendanceMarked(): Flow<Boolean>
    suspend fun markAttendanceNow()
}
