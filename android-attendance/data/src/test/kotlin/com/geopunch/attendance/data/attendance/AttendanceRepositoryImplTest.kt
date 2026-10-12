package com.geopunch.attendance.data.attendance

import androidx.test.core.app.ApplicationProvider
import com.geopunch.attendance.domain.model.Coordinates
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class AttendanceRepositoryImplTest {

    private val context = ApplicationProvider.getApplicationContext<android.app.Application>()

    @Test
    fun `office location is null before anything is saved`() = runTest {
        val repository = AttendanceRepositoryImpl(context)
        assertNull(repository.observeOfficeLocation().first())
    }

    @Test
    fun `office location round-trips through DataStore`() = runTest {
        val repository = AttendanceRepositoryImpl(context)
        val saved = Coordinates(40.7128, -74.0060)

        repository.saveOfficeLocation(saved)

        assertEquals(saved, repository.observeOfficeLocation().first())
    }

    @Test
    fun `attendance is not marked today by default`() = runTest {
        val repository = AttendanceRepositoryImpl(context)
        assertFalse(repository.observeTodayAttendanceMarked().first())
    }

    @Test
    fun `marking attendance persists for the same day`() = runTest {
        val fixedClock = Clock.fixed(Instant.parse("2026-10-12T09:00:00Z"), ZoneOffset.UTC)
        val repository = AttendanceRepositoryImpl(context, clock = fixedClock)

        repository.markAttendanceNow()

        assertTrue(repository.observeTodayAttendanceMarked().first())
    }

    @Test
    fun `a new calendar day resets eligibility`() = runTest {
        val dayOneClock = Clock.fixed(Instant.parse("2026-10-12T09:00:00Z"), ZoneOffset.UTC)
        val repositoryDayOne = AttendanceRepositoryImpl(context, clock = dayOneClock)
        repositoryDayOne.markAttendanceNow()
        assertTrue(repositoryDayOne.observeTodayAttendanceMarked().first())

        val dayTwoClock = Clock.fixed(Instant.parse("2026-10-13T09:00:00Z"), ZoneOffset.UTC)
        val repositoryDayTwo = AttendanceRepositoryImpl(context, clock = dayTwoClock)

        assertFalse(repositoryDayTwo.observeTodayAttendanceMarked().first())
    }
}
