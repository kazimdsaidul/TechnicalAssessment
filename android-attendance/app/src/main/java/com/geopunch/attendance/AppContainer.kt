package com.geopunch.attendance

import android.app.Application
import com.geopunch.attendance.data.attendance.AttendanceRepositoryImpl
import com.geopunch.attendance.data.location.LocationDataSourceImpl
import com.geopunch.attendance.data.location.LocationSettingsChecker
import com.geopunch.attendance.domain.repository.AttendanceRepository
import com.geopunch.attendance.domain.repository.LocationRepository
import com.geopunch.attendance.domain.usecase.CalculateDistanceUseCase
import com.geopunch.attendance.domain.usecase.MarkAttendanceUseCase

/** Manual dependency wiring (no Hilt): keeps build simple and fast for this scope. */
class AppContainer(application: Application) {
    val locationRepository: LocationRepository = LocationDataSourceImpl(application)
    val attendanceRepository: AttendanceRepository = AttendanceRepositoryImpl(application)
    val locationSettingsChecker = LocationSettingsChecker(application)

    val calculateDistanceUseCase = CalculateDistanceUseCase()
    val markAttendanceUseCase = MarkAttendanceUseCase(attendanceRepository, calculateDistanceUseCase)
}
