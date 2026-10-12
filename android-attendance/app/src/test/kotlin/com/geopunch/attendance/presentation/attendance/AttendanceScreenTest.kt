package com.geopunch.attendance.presentation.attendance

import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import com.geopunch.attendance.domain.model.Coordinates
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Asserts the Mark Attendance button and distance text are driven directly by [AttendanceState]. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class AttendanceScreenTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val office = Coordinates(40.7128, -74.0060)

    @Test
    fun `mark attendance button is disabled when outside radius`() {
        val state = AttendanceState(
            officeLocation = office,
            currentLocation = office.copy(latitude = office.latitude + 0.01),
            distanceMeters = 500.0,
            withinRadius = false,
        )

        composeTestRule.setContent {
            AttendanceScreen(
                state = state,
                onIntent = {},
                onRequestLocationPermission = {},
                onOpenAppSettings = {},
            )
        }

        composeTestRule.onNodeWithText("Mark Attendance").assertIsNotEnabled()
        composeTestRule.onNodeWithText("500m").assertExists()
    }

    @Test
    fun `mark attendance button is enabled when within radius and not yet marked`() {
        val state = AttendanceState(
            officeLocation = office,
            currentLocation = office,
            distanceMeters = 10.0,
            withinRadius = true,
            markedToday = false,
        )

        composeTestRule.setContent {
            AttendanceScreen(
                state = state,
                onIntent = {},
                onRequestLocationPermission = {},
                onOpenAppSettings = {},
            )
        }

        composeTestRule.onNodeWithText("Mark Attendance").assertIsEnabled()
        composeTestRule.onNodeWithText("10m").assertExists()
    }

    @Test
    fun `already marked today disables the button and shows marked label`() {
        val state = AttendanceState(
            officeLocation = office,
            currentLocation = office,
            distanceMeters = 5.0,
            withinRadius = true,
            markedToday = true,
        )

        composeTestRule.setContent {
            AttendanceScreen(
                state = state,
                onIntent = {},
                onRequestLocationPermission = {},
                onOpenAppSettings = {},
            )
        }

        composeTestRule.onNodeWithText("Attendance Marked").assertIsNotEnabled()
    }
}
