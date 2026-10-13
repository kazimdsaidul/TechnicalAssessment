package com.geopunch.attendance.data.location

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Looper
import androidx.core.content.ContextCompat
import com.geopunch.attendance.domain.model.Coordinates
import com.geopunch.attendance.domain.model.LocationResult
import com.geopunch.attendance.domain.repository.LocationRepository
import com.google.android.gms.location.CurrentLocationRequest
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationAvailability
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume
import com.google.android.gms.location.LocationResult as GmsLocationResult

/**
 * Wraps [FusedLocationProviderClient] behind the domain [LocationRepository] contract.
 * Two distinct shapes, per design.md: a one-shot fetch for "Set Office Location", and a
 * continuous stream collected only while the attendance screen is visible.
 */
class LocationDataSourceImpl(
    private val context: Context,
) : LocationRepository {

    private val fusedClient: FusedLocationProviderClient =
        LocationServices.getFusedLocationProviderClient(context)

    private fun hasLocationPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    private fun isLocationServicesEnabled(): Boolean {
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
            locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }

    override suspend fun fetchCurrentLocation(): LocationResult {
        if (!hasLocationPermission()) return LocationResult.PermissionDenied
        if (!isLocationServicesEnabled()) return LocationResult.LocationServicesDisabled

        return try {
            // Bounded on both ends: the request itself times out at the platform level, and
            // withTimeoutOrNull guarantees the UI gets a response even if that platform timeout
            // is ever not honored — a stuck spinner would itself be a hardware-failure UX bug.
            withTimeoutOrNull(FETCH_TIMEOUT_MS + 2_000) {
                suspendCancellableCoroutine { continuation ->
                    val request = CurrentLocationRequest.Builder()
                        .setPriority(Priority.PRIORITY_HIGH_ACCURACY)
                        .setDurationMillis(FETCH_TIMEOUT_MS)
                        .build()

                    @Suppress("MissingPermission")
                    fusedClient.getCurrentLocation(request, null)
                        .addOnSuccessListener { location ->
                            val result = if (location != null) {
                                LocationResult.Success(
                                    coordinates = Coordinates(location.latitude, location.longitude),
                                    accuracyMeters = location.accuracy,
                                )
                            } else {
                                LocationResult.Unavailable("No location fix available")
                            }
                            if (continuation.isActive) continuation.resume(result)
                        }
                        .addOnFailureListener { exception ->
                            if (continuation.isActive) {
                                continuation.resume(
                                    LocationResult.Unavailable(exception.message ?: "Location fetch failed"),
                                )
                            }
                        }
                }
            } ?: LocationResult.Unavailable("Location request timed out")
        } catch (e: SecurityException) {
            LocationResult.PermissionDenied
        }
    }

    override fun observeLocation(): Flow<LocationResult> = callbackFlow {
        if (!hasLocationPermission()) {
            trySend(LocationResult.PermissionDenied)
            close()
            return@callbackFlow
        }
        if (!isLocationServicesEnabled()) {
            trySend(LocationResult.LocationServicesDisabled)
            close()
            return@callbackFlow
        }

        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, UPDATE_INTERVAL_MS)
            .setMinUpdateIntervalMillis(MIN_UPDATE_INTERVAL_MS)
            .build()

        val callback = object : LocationCallback() {
            override fun onLocationResult(result: GmsLocationResult) {
                val location = result.lastLocation ?: return
                trySend(
                    LocationResult.Success(
                        coordinates = Coordinates(location.latitude, location.longitude),
                        accuracyMeters = location.accuracy,
                    ),
                )
            }

            override fun onLocationAvailability(availability: LocationAvailability) {
                if (!availability.isLocationAvailable) {
                    trySend(LocationResult.LocationServicesDisabled)
                }
            }
        }

        try {
            @Suppress("MissingPermission")
            fusedClient.requestLocationUpdates(request, callback, Looper.getMainLooper())
        } catch (e: SecurityException) {
            trySend(LocationResult.PermissionDenied)
            close()
        }

        awaitClose { fusedClient.removeLocationUpdates(callback) }
    }

    private companion object {
        const val UPDATE_INTERVAL_MS = 3000L
        const val MIN_UPDATE_INTERVAL_MS = 2000L
        const val FETCH_TIMEOUT_MS = 20_000L
    }
}
