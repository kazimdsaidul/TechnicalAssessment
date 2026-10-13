package com.geopunch.attendance

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.core.app.ActivityCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.geopunch.attendance.data.location.LocationSettingsStatus
import com.geopunch.attendance.presentation.attendance.AttendanceIntent
import com.geopunch.attendance.presentation.attendance.AttendanceScreen
import com.geopunch.attendance.presentation.attendance.AttendanceViewModel

class MainActivity : ComponentActivity() {

    private val container get() = (application as GeoPunchApp).container

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val attendanceViewModelFactory = viewModelFactory {
            initializer {
                AttendanceViewModel(
                    locationRepository = container.locationRepository,
                    attendanceRepository = container.attendanceRepository,
                    calculateDistance = container.calculateDistanceUseCase,
                    markAttendanceUseCase = container.markAttendanceUseCase,
                )
            }
        }

        setContent {
            val viewModel: AttendanceViewModel = viewModel(factory = attendanceViewModelFactory)
            val state by viewModel.state.collectAsState()
            val lifecycleOwner = LocalLifecycleOwner.current

            val locationPermissions = arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            )

            // Bumped on every permission result so the location-collection effect below restarts
            // and re-evaluates permission, even when granted without an intervening lifecycle
            // stop/start (repeatOnLifecycle alone won't retry a flow that already completed).
            var permissionResultVersion by remember { mutableIntStateOf(0) }

            val permissionLauncher = rememberLauncherForActivityResult(
                ActivityResultContracts.RequestMultiplePermissions(),
            ) { results ->
                val granted = results.values.any { it }
                val permanentlyDenied = !granted &&
                    !ActivityCompat.shouldShowRequestPermissionRationale(
                        this,
                        Manifest.permission.ACCESS_FINE_LOCATION,
                    )
                viewModel.onIntent(AttendanceIntent.LocationPermissionResult(granted, permanentlyDenied))
                permissionResultVersion++
            }

            val resolutionLauncher = rememberLauncherForActivityResult(
                ActivityResultContracts.StartIntentSenderForResult(),
            ) {
                // Outcome is observed indirectly: the next location update reflects whether GPS is on.
            }

            LaunchedEffect(Unit) {
                permissionLauncher.launch(locationPermissions)
            }

            LaunchedEffect(state.locationServicesDisabled) {
                if (state.locationServicesDisabled) {
                    when (val status = container.locationSettingsChecker.check()) {
                        is LocationSettingsStatus.Resolvable -> {
                            resolutionLauncher.launch(
                                IntentSenderRequest.Builder(status.exception.resolution).build(),
                            )
                        }
                        else -> Unit
                    }
                }
            }

            LaunchedEffect(lifecycleOwner, permissionResultVersion) {
                lifecycleOwner.lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
                    viewModel.collectLiveLocation()
                }
            }

            MaterialTheme {
                Surface {
                    AttendanceScreen(
                        state = state,
                        onIntent = viewModel::onIntent,
                        onRequestLocationPermission = { permissionLauncher.launch(locationPermissions) },
                        onOpenAppSettings = {
                            startActivity(
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.fromParts("package", packageName, null)
                                },
                            )
                        },
                    )
                }
            }
        }
    }
}
