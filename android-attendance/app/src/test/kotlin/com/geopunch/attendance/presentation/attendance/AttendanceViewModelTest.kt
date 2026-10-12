package com.geopunch.attendance.presentation.attendance

import com.geopunch.attendance.domain.model.Coordinates
import com.geopunch.attendance.domain.model.LocationResult
import com.geopunch.attendance.domain.usecase.CalculateDistanceUseCase
import com.geopunch.attendance.domain.usecase.MarkAttendanceUseCase
import com.geopunch.attendance.fake.FakeAttendanceRepository
import com.geopunch.attendance.fake.FakeLocationRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Exercises the MVI reducer end-to-end against fakes, independent of Android location APIs —
 * see design.md ("Domain logic ... fully unit-testable"). Covers the full sequence from
 * design.md's boundary scenario and the permission/GPS-disabled failure paths from the spec.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class AttendanceViewModelTest {

    private val testDispatcher = StandardTestDispatcher()
    private val office = Coordinates(40.7128, -74.0060)

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun buildViewModel(
        locationRepository: FakeLocationRepository = FakeLocationRepository(),
        attendanceRepository: FakeAttendanceRepository = FakeAttendanceRepository(initialOfficeLocation = office),
    ): Pair<AttendanceViewModel, FakeLocationRepository> {
        val calculateDistance = CalculateDistanceUseCase()
        val markAttendanceUseCase = MarkAttendanceUseCase(attendanceRepository, calculateDistance)
        val viewModel = AttendanceViewModel(
            locationRepository = locationRepository,
            attendanceRepository = attendanceRepository,
            calculateDistance = calculateDistance,
            markAttendanceUseCase = markAttendanceUseCase,
        )
        return viewModel to locationRepository
    }

    private fun offsetNorth(origin: Coordinates, metersNorth: Double): Coordinates {
        val metersPerDegreeLatitude = Math.PI / 180.0 * 6_371_000.0
        return origin.copy(latitude = origin.latitude + metersNorth / metersPerDegreeLatitude)
    }

    @Test
    fun `full sequence far to approaching to within radius to marked`() = runTest {
        val (viewModel, locationRepository) = buildViewModel()
        val job = launch { viewModel.collectLiveLocation() }
        testDispatcher.scheduler.runCurrent()

        // Far away (~1km north).
        locationRepository.locationUpdates.emit(
            LocationResult.Success(offsetNorth(office, 1000.0), accuracyMeters = 5f),
        )
        testDispatcher.scheduler.runCurrent()
        assertFalse(viewModel.state.value.withinRadius)
        assertFalse(viewModel.state.value.canMarkAttendance)

        // Approaching (~80m) — still outside the 50m radius.
        locationRepository.locationUpdates.emit(
            LocationResult.Success(offsetNorth(office, 80.0), accuracyMeters = 5f),
        )
        testDispatcher.scheduler.runCurrent()
        assertFalse(viewModel.state.value.withinRadius)

        // Within 50m.
        locationRepository.locationUpdates.emit(
            LocationResult.Success(offsetNorth(office, 30.0), accuracyMeters = 5f),
        )
        testDispatcher.scheduler.runCurrent()
        assertTrue(viewModel.state.value.withinRadius)
        assertTrue(viewModel.state.value.canMarkAttendance)

        // Mark attendance.
        viewModel.onIntent(AttendanceIntent.MarkAttendanceClicked)
        testDispatcher.scheduler.runCurrent()

        assertTrue(viewModel.state.value.markedToday)
        assertFalse(viewModel.state.value.canMarkAttendance)

        job.cancel()
    }

    @Test
    fun `permission denied disables location-dependent actions without crashing`() = runTest {
        val (viewModel, locationRepository) = buildViewModel()
        val job = launch { viewModel.collectLiveLocation() }
        testDispatcher.scheduler.runCurrent()

        locationRepository.locationUpdates.emit(LocationResult.PermissionDenied)
        testDispatcher.scheduler.runCurrent()

        assertTrue(viewModel.state.value.permissionDenied)
        assertFalse(viewModel.state.value.canMarkAttendance)

        job.cancel()
    }

    @Test
    fun `gps disabled disables location-dependent actions without crashing`() = runTest {
        val (viewModel, locationRepository) = buildViewModel()
        val job = launch { viewModel.collectLiveLocation() }
        testDispatcher.scheduler.runCurrent()

        locationRepository.locationUpdates.emit(LocationResult.LocationServicesDisabled)
        testDispatcher.scheduler.runCurrent()

        assertTrue(viewModel.state.value.locationServicesDisabled)
        assertFalse(viewModel.state.value.canMarkAttendance)

        job.cancel()
    }
}
