"""Tests for Strava client module."""

from datetime import datetime

import pytest

from healthlib.strava import (
    StravaActivity,
    StravaActivityDetail,
    build_auth_url,
)


class TestBuildAuthUrl:
    """Tests for build_auth_url function."""

    def test_default_scopes(self) -> None:
        """Build URL with default scopes."""
        url = build_auth_url(
            client_id="12345",
            redirect_uri="http://localhost:8000/callback",
        )

        assert "client_id=12345" in url
        assert "redirect_uri=http" in url
        assert "response_type=code" in url
        assert "scope=activity%3Aread_all%2Cactivity%3Awrite" in url

    def test_custom_scopes(self) -> None:
        """Build URL with custom scopes."""
        url = build_auth_url(
            client_id="12345",
            redirect_uri="http://localhost:8000/callback",
            scopes=["read", "activity:read"],
        )

        assert "scope=read%2Cactivity%3Aread" in url


class TestStravaActivity:
    """Tests for StravaActivity dataclass."""

    def test_from_api_response_minimal(self) -> None:
        """Parse minimal API response."""
        data = {
            "id": 12345,
            "name": "Morning Run",
            "type": "Run",
            "start_date_local": "2024-01-15T07:30:00Z",
            "elapsed_time": 1800,
            "moving_time": 1750,
            "distance": 5000.0,
        }

        activity = StravaActivity.from_api_response(data)

        assert activity.activity_id == 12345
        assert activity.name == "Morning Run"
        assert activity.activity_type == "Run"
        assert activity.elapsed_time == 1800
        assert activity.moving_time == 1750
        assert activity.distance == 5000.0
        assert activity.total_elevation_gain is None
        assert activity.average_heartrate is None

    def test_from_api_response_full(self) -> None:
        """Parse full API response with all fields."""
        data = {
            "id": 12345,
            "name": "Morning Run",
            "type": "Run",
            "start_date_local": "2024-01-15T07:30:00Z",
            "elapsed_time": 1800,
            "moving_time": 1750,
            "distance": 5000.0,
            "total_elevation_gain": 50.0,
            "average_heartrate": 145.0,
            "max_heartrate": 170.0,
        }

        activity = StravaActivity.from_api_response(data)

        assert activity.total_elevation_gain == 50.0
        assert activity.average_heartrate == 145.0
        assert activity.max_heartrate == 170.0

    def test_from_api_response_start_date_parsing(self) -> None:
        """Parse various date formats."""
        data = {
            "id": 12345,
            "type": "Run",
            "start_date_local": "2024-01-15T07:30:00",
            "elapsed_time": 1800,
            "moving_time": 1750,
            "distance": 5000.0,
        }

        activity = StravaActivity.from_api_response(data)

        assert activity.start_date.year == 2024
        assert activity.start_date.month == 1
        assert activity.start_date.day == 15


class TestStravaActivityDetail:
    """Tests for StravaActivityDetail dataclass."""

    def test_from_api_response_full(self) -> None:
        """Parse full detail API response."""
        data = {
            "id": 12345,
            "name": "Morning Run",
            "description": "Easy recovery run",
            "type": "Run",
            "start_date_local": "2024-01-15T07:30:00Z",
            "elapsed_time": 1800,
            "moving_time": 1750,
            "distance": 5000.0,
            "total_elevation_gain": 50.0,
            "average_speed": 2.78,
            "max_speed": 3.5,
            "average_heartrate": 145.0,
            "max_heartrate": 170.0,
            "calories": 350.0,
            "gear_id": "b12345",
        }

        detail = StravaActivityDetail.from_api_response(data)

        assert detail.activity_id == 12345
        assert detail.name == "Morning Run"
        assert detail.description == "Easy recovery run"
        assert detail.average_speed == 2.78
        assert detail.max_speed == 3.5
        assert detail.calories == 350.0
        assert detail.gear_id == "b12345"
        assert detail.raw_data == data

    def test_from_api_response_preserves_raw_data(self) -> None:
        """Raw data dict is preserved for access to unlisted fields."""
        data = {
            "id": 12345,
            "type": "Run",
            "start_date_local": "2024-01-15T07:30:00Z",
            "elapsed_time": 1800,
            "moving_time": 1750,
            "distance": 5000.0,
            "segment_efforts": [{"id": 1}, {"id": 2}],
        }

        detail = StravaActivityDetail.from_api_response(data)

        assert detail.raw_data["segment_efforts"] == [{"id": 1}, {"id": 2}]
