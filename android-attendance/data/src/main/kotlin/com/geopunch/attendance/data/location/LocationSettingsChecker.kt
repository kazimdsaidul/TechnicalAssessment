package com.geopunch.attendance.data.location

import android.content.Context
import com.google.android.gms.common.api.ResolvableApiException
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.LocationSettingsRequest
import com.google.android.gms.location.Priority
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

sealed interface LocationSettingsStatus {
    data object Satisfied : LocationSettingsStatus
    data class Resolvable(val exception: ResolvableApiException) : LocationSettingsStatus
    data object Unresolvable : LocationSettingsStatus
}

/**
 * Checks whether device location settings satisfy the app's accuracy needs, surfacing a
 * [ResolvableApiException] the UI layer can use to launch the system "enable location" dialog
 * instead of sending the user to Settings manually.
 */
class LocationSettingsChecker(private val context: Context) {
    suspend fun check(): LocationSettingsStatus = suspendCancellableCoroutine { continuation ->
        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, UPDATE_INTERVAL_MS).build()
        val settingsRequest = LocationSettingsRequest.Builder().addLocationRequest(request).build()

        LocationServices.getSettingsClient(context)
            .checkLocationSettings(settingsRequest)
            .addOnSuccessListener {
                if (continuation.isActive) continuation.resume(LocationSettingsStatus.Satisfied)
            }
            .addOnFailureListener { exception ->
                val status = if (exception is ResolvableApiException) {
                    LocationSettingsStatus.Resolvable(exception)
                } else {
                    LocationSettingsStatus.Unresolvable
                }
                if (continuation.isActive) continuation.resume(status)
            }
    }

    private companion object {
        const val UPDATE_INTERVAL_MS = 3000L
    }
}
