package com.geopunch.attendance.data.location

import android.Manifest
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.rule.GrantPermissionRule
import com.geopunch.attendance.domain.model.LocationResult
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import kotlin.test.assertTrue

/**
 * Exercises [LocationDataSourceImpl] against the real FusedLocationProviderClient on a device
 * or emulator. Requires a location fix to be available (e.g. via `adb emu geo fix` on an
 * emulator) for both assertions to see a Success result.
 */
@RunWith(AndroidJUnit4::class)
class LocationDataSourceImplInstrumentedTest {

    @get:Rule
    val permissionRule: GrantPermissionRule = GrantPermissionRule.grant(
        Manifest.permission.ACCESS_FINE_LOCATION,
        Manifest.permission.ACCESS_COARSE_LOCATION,
    )

    private val context: Context = ApplicationProvider.getApplicationContext()

    @Test
    fun fetchCurrentLocation_emitsALocation() = runBlocking {
        val dataSource = LocationDataSourceImpl(context)
        val result = dataSource.fetchCurrentLocation()
        assertTrue(result is LocationResult.Success, "Expected Success but got $result")
    }

    @Test
    fun observeLocation_emitsALocation() = runBlocking {
        val dataSource = LocationDataSourceImpl(context)
        val result = dataSource.observeLocation().first()
        assertTrue(result is LocationResult.Success, "Expected Success but got $result")
    }
}
