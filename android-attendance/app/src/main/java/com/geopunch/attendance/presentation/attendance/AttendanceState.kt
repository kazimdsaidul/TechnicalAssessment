package com.geopunch.attendance.presentation.attendance

import com.geopunch.attendance.domain.model.Coordinates

data class AttendanceState(
    val officeLocation: Coordinates? = null,
    val currentLocation: Coordinates? = null,
    val distanceMeters: Double? = null,
    val withinRadius: Boolean = false,
    val markedToday: Boolean = false,
    val isSettingOfficeLocation: Boolean = false,
    val isMarkingAttendance: Boolean = false,
    val permissionDenied: Boolean = false,
    val permissionPermanentlyDenied: Boolean = false,
    val locationServicesDisabled: Boolean = false,
    val message: String? = null,
) {
    val canMarkAttendance: Boolean
        get() = officeLocation != null &&
            withinRadius &&
            !markedToday &&
            !isMarkingAttendance &&
            !permissionDenied &&
            !locationServicesDisabled
}
