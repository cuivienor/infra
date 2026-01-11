"""Tests for Garmin client module.

Note: These tests focus on pure data transformation logic.
Integration tests requiring garminconnect should be run separately
with the full dependency environment.
"""

from datetime import datetime

import pytest

# Skip imports if garminconnect is not available (pure dataclass tests only)
pytest.importorskip("garminconnect")

from healthlib.garmin import GarminActivity, GarminActivityDetail


class TestGarminActivity:
    """Tests for GarminActivity dataclass."""

    def test_from_api_response_minimal(self) -> None:
        """Parse minimal API response."""
        data = {
            "activityId": 12345,
            "activityName": "Morning Run",
            "activityType": {"typeKey": "running"},
            "startTimeLocal": "2024-01-15T07:30:00",
            "duration": 1800.0,
        }

        activity = GarminActivity.from_api_response(data)

        assert activity.activity_id == 12345
        assert activity.activity_name == "Morning Run"
        assert activity.activity_type == "running"
        assert activity.start_time == datetime(2024, 1, 15, 7, 30, 0)
        assert activity.duration_seconds == 1800.0
        assert activity.distance_meters is None
        assert activity.calories is None

    def test_from_api_response_full(self) -> None:
        """Parse full API response with all fields."""
        data = {
            "activityId": 12345,
            "activityName": "Morning Run",
            "activityType": {"typeKey": "running"},
            "startTimeLocal": "2024-01-15T07:30:00",
            "duration": 1800.0,
            "distance": 5000.0,
            "calories": 350,
            "averageHR": 145,
            "maxHR": 170,
        }

        activity = GarminActivity.from_api_response(data)

        assert activity.distance_meters == 5000.0
        assert activity.calories == 350
        assert activity.average_hr == 145
        assert activity.max_hr == 170

    def test_from_api_response_iso_with_z(self) -> None:
        """Parse ISO datetime with Z suffix."""
        data = {
            "activityId": 12345,
            "activityType": {"typeKey": "running"},
            "startTimeGMT": "2024-01-15T15:30:00Z",
            "duration": 1800.0,
        }

        activity = GarminActivity.from_api_response(data)

        # Should parse without error
        assert activity.start_time.year == 2024
        assert activity.start_time.month == 1
        assert activity.start_time.day == 15

    def test_from_api_response_missing_activity_type(self) -> None:
        """Handle missing activityType gracefully."""
        data = {
            "activityId": 12345,
            "activityName": "Unknown Activity",
            "startTimeLocal": "2024-01-15T07:30:00",
            "duration": 1800.0,
        }

        activity = GarminActivity.from_api_response(data)

        assert activity.activity_type == "unknown"


class TestGarminActivityDetail:
    """Tests for GarminActivityDetail dataclass."""

    def test_from_api_response_full(self) -> None:
        """Parse full detail API response."""
        data = {
            "activityId": 12345,
            "activityName": "Morning Run",
            "description": "Easy recovery run",
            "activityType": {"typeKey": "running"},
            "startTimeLocal": "2024-01-15T07:30:00",
            "duration": 1800.0,
            "distance": 5000.0,
            "elevationGain": 50.0,
            "calories": 350,
            "averageHR": 145,
            "maxHR": 170,
            "averageSpeed": 2.78,
            "maxSpeed": 3.5,
        }

        detail = GarminActivityDetail.from_api_response(data)

        assert detail.activity_id == 12345
        assert detail.activity_name == "Morning Run"
        assert detail.description == "Easy recovery run"
        assert detail.elevation_gain == 50.0
        assert detail.average_speed == 2.78
        assert detail.max_speed == 3.5
        assert detail.raw_data == data

    def test_from_api_response_preserves_raw_data(self) -> None:
        """Raw data dict is preserved for access to unlisted fields."""
        data = {
            "activityId": 12345,
            "activityType": {"typeKey": "running"},
            "startTimeLocal": "2024-01-15T07:30:00",
            "duration": 1800.0,
            "customField": "custom_value",
        }

        detail = GarminActivityDetail.from_api_response(data)

        assert detail.raw_data["customField"] == "custom_value"
