package com.geopunch.attendance.presentation.attendance

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.geopunch.attendance.domain.model.Coordinates
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker

/**
 * Non-interactive OSM preview of the saved office location. Per spec: the saved coordinates
 * (rendered by the caller as a text pill) must remain visible even if tiles fail to load offline,
 * so this composable never gates that text behind tile-load success.
 */
@Composable
fun OfficeMapPreview(
    coordinates: Coordinates,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val mapView = remember {
        MapView(context).apply {
            setTileSource(TileSourceFactory.MAPNIK)
            setMultiTouchControls(false)
            isClickable = false
            isFocusable = false
        }
    }

    DisposableEffect(Unit) {
        onDispose { mapView.onDetach() }
    }

    Box(modifier = modifier) {
        AndroidView(
            modifier = Modifier.fillMaxSize(),
            factory = { mapView },
            update = { view ->
                val point = GeoPoint(coordinates.latitude, coordinates.longitude)
                view.controller.setZoom(17.0)
                view.controller.setCenter(point)
                view.overlays.clear()
                view.overlays.add(
                    Marker(view).apply {
                        position = point
                        setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                    },
                )
                view.invalidate()
            },
        )
        // Required by OSM's tile usage policy.
        Text(
            text = "© OpenStreetMap contributors",
            style = MaterialTheme.typography.labelSmall,
            color = Color.White,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .background(Color.Black.copy(alpha = 0.45f))
                .padding(horizontal = 4.dp, vertical = 2.dp),
        )
    }
}
