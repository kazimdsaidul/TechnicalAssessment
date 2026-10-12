package com.geopunch.attendance.domain.usecase

import com.geopunch.attendance.domain.fake.FakeAttendanceRepository
import com.geopunch.attendance.domain.model.Coordinates
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

class MarkAttendanceUseCaseTest {

    private val office = Coordinates(40.7128, -74.0060)
    private val withinRadius = Coordinates(40.7128, -74.0058) // a few meters away
    private val outsideRadius = Coordinates(40.7200, -74.0060) // far away

    @Test
    fun `no office location set is reported`() = runTest {
        val repository = FakeAttendanceRepository(initialOfficeLocation = null)
        val useCase = MarkAttendanceUseCase(repository)

        val result = useCase(withinRadius)

        assertIs<MarkAttendanceUseCase.Result.NoOfficeLocationSet>(result)
        assertEquals(0, repository.markAttendanceNowCallCount)
    }

    @Test
    fun `outside radius is rejected and not marked`() = runTest {
        val repository = FakeAttendanceRepository(initialOfficeLocation = office)
        val useCase = MarkAttendanceUseCase(repository)

        val result = useCase(outsideRadius)

        assertIs<MarkAttendanceUseCase.Result.OutsideRadius>(result)
        assertEquals(0, repository.markAttendanceNowCallCount)
    }

    @Test
    fun `within radius and not yet marked today succeeds`() = runTest {
        val repository = FakeAttendanceRepository(initialOfficeLocation = office, initialMarkedToday = false)
        val useCase = MarkAttendanceUseCase(repository)

        val result = useCase(withinRadius)

        assertIs<MarkAttendanceUseCase.Result.Marked>(result)
        assertEquals(1, repository.markAttendanceNowCallCount)
    }

    @Test
    fun `already marked today is rejected regardless of distance`() = runTest {
        val repository = FakeAttendanceRepository(initialOfficeLocation = office, initialMarkedToday = true)
        val useCase = MarkAttendanceUseCase(repository)

        val result = useCase(withinRadius)

        assertIs<MarkAttendanceUseCase.Result.AlreadyMarkedToday>(result)
        assertEquals(0, repository.markAttendanceNowCallCount)
    }

    @Test
    fun `new day resets eligibility`() = runTest {
        val repository = FakeAttendanceRepository(initialOfficeLocation = office, initialMarkedToday = true)
        val useCase = MarkAttendanceUseCase(repository)

        // Simulates the repository rolling marked-flag over to a new calendar day.
        repository.setMarkedToday(false)
        val result = useCase(withinRadius)

        assertIs<MarkAttendanceUseCase.Result.Marked>(result)
        assertEquals(1, repository.markAttendanceNowCallCount)
    }
}
