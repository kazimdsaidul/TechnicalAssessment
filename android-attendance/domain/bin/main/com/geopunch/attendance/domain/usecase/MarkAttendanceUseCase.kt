package com.geopunch.attendance.domain.usecase

import com.geopunch.attendance.domain.model.AttendanceRules
import com.geopunch.attendance.domain.model.Coordinates
import com.geopunch.attendance.domain.repository.AttendanceRepository
import kotlinx.coroutines.flow.first

class MarkAttendanceUseCase(
    private val attendanceRepository: AttendanceRepository,
    private val calculateDistance: CalculateDistanceUseCase = CalculateDistanceUseCase(),
) {
    sealed interface Result {
        data object Marked : Result
        data object OutsideRadius : Result
        data object AlreadyMarkedToday : Result
        data object NoOfficeLocationSet : Result
    }

    suspend operator fun invoke(currentLocation: Coordinates): Result {
        val officeLocation = attendanceRepository.observeOfficeLocation().first()
            ?: return Result.NoOfficeLocationSet

        if (attendanceRepository.observeTodayAttendanceMarked().first()) {
            return Result.AlreadyMarkedToday
        }

        val distanceMeters = calculateDistance(officeLocation, currentLocation)
        if (distanceMeters > AttendanceRules.RADIUS_METERS) {
            return Result.OutsideRadius
        }

        attendanceRepository.markAttendanceNow()
        return Result.Marked
    }
}
