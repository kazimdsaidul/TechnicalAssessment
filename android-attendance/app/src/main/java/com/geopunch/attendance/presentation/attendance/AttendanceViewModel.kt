package com.geopunch.attendance.presentation.attendance

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.geopunch.attendance.domain.model.AttendanceRules
import com.geopunch.attendance.domain.model.LocationResult
import com.geopunch.attendance.domain.repository.AttendanceRepository
import com.geopunch.attendance.domain.repository.LocationRepository
import com.geopunch.attendance.domain.usecase.CalculateDistanceUseCase
import com.geopunch.attendance.domain.usecase.MarkAttendanceUseCase
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * MVI reducer for the attendance screen. [state] is the single source of truth; every intent
 * and every location update funnels through here so the 50m-boundary transition is testable
 * as one unit (see AttendanceViewModelTest).
 */
class AttendanceViewModel(
    private val locationRepository: LocationRepository,
    private val attendanceRepository: AttendanceRepository,
    private val calculateDistance: CalculateDistanceUseCase,
    private val markAttendanceUseCase: MarkAttendanceUseCase,
) : ViewModel() {

    private val _state = MutableStateFlow(AttendanceState())
    val state: StateFlow<AttendanceState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            attendanceRepository.observeOfficeLocation().collect { office ->
                _state.update { it.copy(officeLocation = office) }
                recomputeDistance()
            }
        }
        viewModelScope.launch {
            attendanceRepository.observeTodayAttendanceMarked().collect { marked ->
                _state.update { it.copy(markedToday = marked) }
            }
        }
    }

    fun onIntent(intent: AttendanceIntent) {
        when (intent) {
            AttendanceIntent.SetOfficeLocationClicked -> setOfficeLocation()
            AttendanceIntent.MarkAttendanceClicked -> markAttendance()
            is AttendanceIntent.LocationPermissionResult -> handlePermissionResult(intent)
            AttendanceIntent.MessageShown -> _state.update { it.copy(message = null) }
        }
    }

    /**
     * Collects the continuous location stream. The caller (AttendanceScreen) is responsible for
     * invoking this inside `repeatOnLifecycle(STARTED)`, so collection — and the underlying
     * FusedLocationProviderClient updates — stop automatically once the screen is backgrounded.
     */
    suspend fun collectLiveLocation() {
        locationRepository.observeLocation().collect { result -> applyLocationResult(result) }
    }

    private fun applyLocationResult(result: LocationResult) {
        when (result) {
            is LocationResult.Success -> {
                _state.update {
                    it.copy(
                        currentLocation = result.coordinates,
                        permissionDenied = false,
                        locationServicesDisabled = false,
                    )
                }
                recomputeDistance()
            }
            LocationResult.PermissionDenied -> _state.update { it.copy(permissionDenied = true) }
            LocationResult.LocationServicesDisabled -> _state.update { it.copy(locationServicesDisabled = true) }
            is LocationResult.Unavailable -> _state.update { it.copy(message = result.message) }
        }
    }

    private fun recomputeDistance() {
        val office = _state.value.officeLocation
        val current = _state.value.currentLocation
        if (office == null || current == null) {
            _state.update { it.copy(distanceMeters = null, withinRadius = false) }
            return
        }
        val distanceMeters = calculateDistance(office, current)
        _state.update {
            it.copy(distanceMeters = distanceMeters, withinRadius = distanceMeters <= AttendanceRules.RADIUS_METERS)
        }
    }

    private fun setOfficeLocation() {
        viewModelScope.launch {
            _state.update { it.copy(isSettingOfficeLocation = true) }
            when (val result = locationRepository.fetchCurrentLocation()) {
                is LocationResult.Success -> {
                    attendanceRepository.saveOfficeLocation(result.coordinates)
                    _state.update { it.copy(message = "Office location saved") }
                }
                LocationResult.PermissionDenied -> _state.update { it.copy(permissionDenied = true) }
                LocationResult.LocationServicesDisabled -> _state.update { it.copy(locationServicesDisabled = true) }
                is LocationResult.Unavailable -> _state.update { it.copy(message = result.message) }
            }
            _state.update { it.copy(isSettingOfficeLocation = false) }
        }
    }

    private fun markAttendance() {
        val current = _state.value.currentLocation ?: return
        viewModelScope.launch {
            _state.update { it.copy(isMarkingAttendance = true) }
            val result = markAttendanceUseCase(current)
            val message = when (result) {
                MarkAttendanceUseCase.Result.Marked -> "Attendance marked!"
                MarkAttendanceUseCase.Result.OutsideRadius -> "You're outside the 50m radius"
                MarkAttendanceUseCase.Result.AlreadyMarkedToday -> "Already marked today"
                MarkAttendanceUseCase.Result.NoOfficeLocationSet -> "Set the office location first"
            }
            _state.update { it.copy(isMarkingAttendance = false, message = message) }
        }
    }

    private fun handlePermissionResult(intent: AttendanceIntent.LocationPermissionResult) {
        _state.update {
            it.copy(
                permissionDenied = !intent.granted,
                permissionPermanentlyDenied = intent.permanentlyDenied,
            )
        }
    }
}
