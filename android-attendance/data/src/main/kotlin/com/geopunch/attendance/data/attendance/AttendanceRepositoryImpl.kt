package com.geopunch.attendance.data.attendance

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.doublePreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.geopunch.attendance.domain.model.Coordinates
import com.geopunch.attendance.domain.repository.AttendanceRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.time.Clock
import java.time.LocalDate

private val Context.attendanceDataStore: DataStore<Preferences> by preferencesDataStore(name = "attendance_prefs")

/**
 * Persists only today's state (office location + whether attendance has been marked today),
 * per the confirmed scope — no attendance history. "Today" is resolved here by comparing the
 * stored epoch-day to the current one, so a new calendar day resets eligibility automatically.
 */
class AttendanceRepositoryImpl(
    private val context: Context,
    private val clock: Clock = Clock.systemDefaultZone(),
) : AttendanceRepository {

    private val dataStore get() = context.attendanceDataStore

    override fun observeOfficeLocation(): Flow<Coordinates?> =
        dataStore.data.map { prefs ->
            val lat = prefs[OFFICE_LATITUDE_KEY]
            val lon = prefs[OFFICE_LONGITUDE_KEY]
            if (lat != null && lon != null) Coordinates(lat, lon) else null
        }

    override suspend fun saveOfficeLocation(coordinates: Coordinates) {
        dataStore.edit { prefs ->
            prefs[OFFICE_LATITUDE_KEY] = coordinates.latitude
            prefs[OFFICE_LONGITUDE_KEY] = coordinates.longitude
        }
    }

    override fun observeTodayAttendanceMarked(): Flow<Boolean> =
        dataStore.data.map { prefs ->
            val markedEpochDay = prefs[MARKED_EPOCH_DAY_KEY] ?: return@map false
            markedEpochDay == todayEpochDay()
        }

    override suspend fun markAttendanceNow() {
        dataStore.edit { prefs ->
            prefs[MARKED_EPOCH_DAY_KEY] = todayEpochDay()
        }
    }

    private fun todayEpochDay(): Long = LocalDate.now(clock).toEpochDay()

    private companion object {
        val OFFICE_LATITUDE_KEY = doublePreferencesKey("office_latitude")
        val OFFICE_LONGITUDE_KEY = doublePreferencesKey("office_longitude")
        val MARKED_EPOCH_DAY_KEY = longPreferencesKey("marked_epoch_day")
    }
}
