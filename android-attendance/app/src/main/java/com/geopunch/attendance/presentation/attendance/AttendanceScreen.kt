package com.geopunch.attendance.presentation.attendance

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AddLocationAlt
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.LockOpen
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Snackbar
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.geopunch.attendance.domain.model.Coordinates
import kotlin.math.roundToInt

private val RingPositiveColor = Color(0xFF2E7D32)
private val RingNegativeColor = Color(0xFFD32F2F)
private const val RING_DISPLAY_MAX_METERS = 200.0

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AttendanceScreen(
    state: AttendanceState,
    onIntent: (AttendanceIntent) -> Unit,
    onRequestLocationPermission: () -> Unit,
    onOpenAppSettings: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(state.message) {
        state.message?.let { message ->
            snackbarHostState.showSnackbar(message)
            onIntent(AttendanceIntent.MessageShown)
        }
    }

    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(
                title = { Text("Attendance") },
                navigationIcon = {
                    IconButton(onClick = {}) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
                    }
                },
            )
        },
        snackbarHost = {
            SnackbarHost(snackbarHostState) { data ->
                Snackbar(snackbarData = data)
            }
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            OfficeContextCard(
                state = state,
                onSetOfficeLocation = {
                    if (state.permissionDenied) onRequestLocationPermission()
                    else onIntent(AttendanceIntent.SetOfficeLocationClicked)
                },
            )

            Spacer(Modifier.height(24.dp))

            if (state.officeLocation != null) {
                ProximityRing(distanceMeters = state.distanceMeters, withinRadius = state.withinRadius)
                Spacer(Modifier.height(8.dp))
                StatusChip(withinRadius = state.withinRadius)
                Spacer(Modifier.height(8.dp))
                Text(
                    text = if (state.withinRadius) {
                        "You're within range to check in."
                    } else {
                        "Move within 50 meters of the designated office location to enable check-in."
                    },
                    style = MaterialTheme.typography.bodySmall,
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.height(24.dp))
            }

            PermissionAndGpsBanners(
                state = state,
                onRequestPermission = onRequestLocationPermission,
                onOpenAppSettings = onOpenAppSettings,
            )

            MarkAttendanceButton(
                state = state,
                onClick = { onIntent(AttendanceIntent.MarkAttendanceClicked) },
            )
        }
    }
}

@Composable
private fun OfficeContextCard(
    state: AttendanceState,
    onSetOfficeLocation: () -> Unit,
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        tonalElevation = 1.dp,
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "STEP 1: OFFICE CONTEXT",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                )
                Box(
                    modifier = Modifier
                        .padding(start = 8.dp)
                        .size(6.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.primary),
                )
            }

            Spacer(Modifier.height(12.dp))

            val office = state.officeLocation
            if (office != null) {
                Box(modifier = Modifier.fillMaxWidth().height(140.dp).clip(RoundedCornerShape(12.dp))) {
                    OfficeMapPreview(coordinates = office, modifier = Modifier.fillMaxSize())
                    CoordinatesPill(
                        coordinates = office,
                        modifier = Modifier.align(Alignment.TopStart).padding(8.dp),
                    )
                }
            } else {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(140.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "No office location set yet",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            Spacer(Modifier.height(12.dp))

            Text(
                text = "To mark your attendance, ensure your current office location is correctly identified.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            Spacer(Modifier.height(12.dp))

            OutlinedButton(
                onClick = onSetOfficeLocation,
                modifier = Modifier.fillMaxWidth(),
                enabled = !state.isSettingOfficeLocation,
            ) {
                if (state.isSettingOfficeLocation) {
                    CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                } else {
                    Icon(Icons.Filled.AddLocationAlt, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(text = "Set Office Location")
                }
            }
        }
    }
}

@Composable
private fun CoordinatesPill(coordinates: Coordinates, modifier: Modifier = Modifier) {
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(50),
        color = Color.White.copy(alpha = 0.9f),
    ) {
        Text(
            text = "Lat: %.4f, Lon: %.4f".format(coordinates.latitude, coordinates.longitude),
            style = MaterialTheme.typography.labelSmall,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            color = Color.Black,
        )
    }
}

@Composable
private fun ProximityRing(distanceMeters: Double?, withinRadius: Boolean) {
    val ringColor = if (withinRadius) RingPositiveColor else RingNegativeColor
    val progress = when {
        distanceMeters == null -> 0f
        withinRadius -> 1f
        else -> (1f - (distanceMeters / RING_DISPLAY_MAX_METERS).toFloat()).coerceIn(0f, 1f)
    }

    Box(contentAlignment = Alignment.Center) {
        Canvas(modifier = Modifier.size(160.dp)) {
            val strokeWidth = 12.dp.toPx()
            drawArc(
                color = ringColor.copy(alpha = 0.15f),
                startAngle = -90f,
                sweepAngle = 360f,
                useCenter = false,
                style = Stroke(width = strokeWidth, cap = StrokeCap.Round),
            )
            drawArc(
                color = ringColor,
                startAngle = -90f,
                sweepAngle = 360f * progress,
                useCenter = false,
                style = Stroke(width = strokeWidth, cap = StrokeCap.Round),
            )
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = distanceMeters?.let { "${it.roundToInt()}m" } ?: "--",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
            )
            Text(text = "AWAY", style = MaterialTheme.typography.labelSmall)
        }
    }
}

@Composable
private fun StatusChip(withinRadius: Boolean) {
    val (label, color) = if (withinRadius) "IN RANGE" to RingPositiveColor else "OUT OF RANGE" to RingNegativeColor
    Surface(shape = RoundedCornerShape(50), color = color.copy(alpha = 0.12f)) {
        Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(modifier = Modifier.size(8.dp).clip(CircleShape).background(color))
            Spacer(Modifier.width(6.dp))
            Text(text = label, style = MaterialTheme.typography.labelMedium, color = color)
        }
    }
}

@Composable
private fun MarkAttendanceButton(state: AttendanceState, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        enabled = state.canMarkAttendance,
        modifier = Modifier.fillMaxWidth().height(56.dp),
    ) {
        if (state.isMarkingAttendance) {
            CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
        } else {
            Icon(
                imageVector = if (state.canMarkAttendance) Icons.Filled.LockOpen else Icons.Filled.Lock,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
            )
            Spacer(Modifier.width(8.dp))
            Text(text = if (state.markedToday) "Attendance Marked" else "Mark Attendance")
        }
    }
}

@Composable
private fun PermissionAndGpsBanners(
    state: AttendanceState,
    onRequestPermission: () -> Unit,
    onOpenAppSettings: () -> Unit,
) {
    val bannerText: String? = when {
        state.permissionPermanentlyDenied ->
            "Location permission was permanently denied. Open app settings to grant it."
        state.permissionDenied ->
            "Location permission is needed to verify you're at the office."
        state.locationServicesDisabled ->
            "Location services are off. Enable GPS to continue."
        else -> null
    }

    if (bannerText != null) {
        Surface(
            modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp),
            shape = RoundedCornerShape(12.dp),
            color = MaterialTheme.colorScheme.errorContainer,
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                Text(text = bannerText, style = MaterialTheme.typography.bodySmall)
                Spacer(Modifier.height(8.dp))
                Row {
                    when {
                        state.permissionPermanentlyDenied ->
                            Button(onClick = onOpenAppSettings) { Text("Open Settings") }
                        state.permissionDenied ->
                            Button(onClick = onRequestPermission) { Text("Grant Permission") }
                    }
                }
            }
        }
    }
}
