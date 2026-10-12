package com.geopunch.attendance.presentation.attendance

sealed interface AttendanceIntent {
    data object SetOfficeLocationClicked : AttendanceIntent
    data object MarkAttendanceClicked : AttendanceIntent
    data class LocationPermissionResult(val granted: Boolean, val permanentlyDenied: Boolean) : AttendanceIntent
    data object MessageShown : AttendanceIntent
}
