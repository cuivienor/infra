"""Garmin Connect client wrapper.

Provides a clean interface to python-garminconnect for activity operations.
"""

from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path
from typing import Any

from garminconnect import Garmin

from healthlib.config import GarminConfig


@dataclass
class GarminActivity:
    """Garmin activity summary."""

    activity_id: int
    activity_name: str
    activity_type: str
    start_time: datetime
    duration_seconds: float
    distance_meters: float | None
    calories: int | None
    average_hr: int | None
    max_hr: int | None

    @classmethod
    def from_api_response(cls, data: dict[str, Any]) -> "GarminActivity":
        """Create from Garmin Connect API response.

        Args:
            data: Activity dict from Garmin Connect API.

        Returns:
            GarminActivity instance.
        """
        # Parse start time - Garmin returns ISO format
        start_time_str = data.get("startTimeLocal", data.get("startTimeGMT", ""))
        if start_time_str:
            # Handle various Garmin datetime formats
            try:
                start_time = datetime.fromisoformat(start_time_str.replace("Z", "+00:00"))
            except ValueError:
                # Fallback for other formats
                start_time = datetime.strptime(start_time_str, "%Y-%m-%d %H:%M:%S")
        else:
            start_time = datetime.now()

        return cls(
            activity_id=data["activityId"],
            activity_name=data.get("activityName", ""),
            activity_type=data.get("activityType", {}).get("typeKey", "unknown"),
            start_time=start_time,
            duration_seconds=data.get("duration", 0),
            distance_meters=data.get("distance"),
            calories=data.get("calories"),
            average_hr=data.get("averageHR"),
            max_hr=data.get("maxHR"),
        )


@dataclass
class GarminActivityDetail:
    """Detailed Garmin activity with full metadata."""

    activity_id: int
    activity_name: str
    description: str | None
    activity_type: str
    start_time: datetime
    duration_seconds: float
    distance_meters: float | None
    elevation_gain: float | None
    calories: int | None
    average_hr: int | None
    max_hr: int | None
    average_speed: float | None
    max_speed: float | None
    raw_data: dict[str, Any]

    @classmethod
    def from_api_response(cls, data: dict[str, Any]) -> "GarminActivityDetail":
        """Create from Garmin Connect API response.

        Args:
            data: Activity detail dict from Garmin Connect API.

        Returns:
            GarminActivityDetail instance.
        """
        # Parse start time
        start_time_str = data.get("startTimeLocal", data.get("startTimeGMT", ""))
        if start_time_str:
            try:
                start_time = datetime.fromisoformat(start_time_str.replace("Z", "+00:00"))
            except ValueError:
                start_time = datetime.strptime(start_time_str, "%Y-%m-%d %H:%M:%S")
        else:
            start_time = datetime.now()

        return cls(
            activity_id=data["activityId"],
            activity_name=data.get("activityName", ""),
            description=data.get("description"),
            activity_type=data.get("activityType", {}).get("typeKey", "unknown"),
            start_time=start_time,
            duration_seconds=data.get("duration", 0),
            distance_meters=data.get("distance"),
            elevation_gain=data.get("elevationGain"),
            calories=data.get("calories"),
            average_hr=data.get("averageHR"),
            max_hr=data.get("maxHR"),
            average_speed=data.get("averageSpeed"),
            max_speed=data.get("maxSpeed"),
            raw_data=data,
        )


class GarminClientError(Exception):
    """Raised when Garmin client operations fail."""


class GarminClient:
    """Wrapper for python-garminconnect with session management."""

    def __init__(self, config: GarminConfig) -> None:
        """Initialize Garmin client.

        Args:
            config: Garmin credentials configuration.
        """
        self._config = config
        self._client: Garmin | None = None

    def _get_client(self) -> Garmin:
        """Get authenticated Garmin client, logging in if needed.

        Returns:
            Authenticated Garmin client.

        Raises:
            GarminClientError: If login fails.
        """
        if self._client is None:
            try:
                self._client = Garmin(self._config.email, self._config.password)
                self._client.login()
            except Exception as e:
                raise GarminClientError(f"Failed to login to Garmin Connect: {e}") from e
        return self._client

    def list_activities(
        self,
        start_date: date | None = None,
        end_date: date | None = None,
        limit: int = 20,
    ) -> list[GarminActivity]:
        """List activities from Garmin Connect.

        Args:
            start_date: Filter activities starting from this date.
            end_date: Filter activities up to this date.
            limit: Maximum number of activities to return.

        Returns:
            List of GarminActivity summaries.

        Raises:
            GarminClientError: If fetching fails.
        """
        client = self._get_client()

        try:
            if start_date and end_date:
                # Use date range method
                activities = client.get_activities_by_date(
                    start_date.isoformat(),
                    end_date.isoformat(),
                )
            else:
                # Use simple list with limit
                activities = client.get_activities(0, limit)

            return [GarminActivity.from_api_response(a) for a in activities]

        except Exception as e:
            raise GarminClientError(f"Failed to fetch activities: {e}") from e

    def get_activity(self, activity_id: int) -> GarminActivityDetail:
        """Get detailed information for a specific activity.

        Args:
            activity_id: Garmin activity ID.

        Returns:
            GarminActivityDetail with full metadata.

        Raises:
            GarminClientError: If fetching fails.
        """
        client = self._get_client()

        try:
            data = client.get_activity(activity_id)
            return GarminActivityDetail.from_api_response(data)

        except Exception as e:
            raise GarminClientError(f"Failed to fetch activity {activity_id}: {e}") from e

    def download_activity(
        self,
        activity_id: int,
        output_path: Path,
        file_format: str = "fit",
    ) -> Path:
        """Download activity file (FIT, TCX, GPX).

        Args:
            activity_id: Garmin activity ID.
            output_path: Directory to save the file.
            file_format: File format: "fit", "tcx", or "gpx".

        Returns:
            Path to downloaded file.

        Raises:
            GarminClientError: If download fails.
            ValueError: If file_format is invalid.
        """
        client = self._get_client()

        valid_formats = {"fit", "tcx", "gpx"}
        if file_format.lower() not in valid_formats:
            raise ValueError(f"Invalid format '{file_format}'. Must be one of: {valid_formats}")

        try:
            # Ensure output directory exists
            output_path.mkdir(parents=True, exist_ok=True)

            # Download based on format
            format_lower = file_format.lower()
            filename = f"{activity_id}.{format_lower}"
            filepath = output_path / filename

            if format_lower == "fit":
                data = client.download_activity(activity_id, dl_fmt=client.ActivityDownloadFormat.ORIGINAL)
            elif format_lower == "tcx":
                data = client.download_activity(activity_id, dl_fmt=client.ActivityDownloadFormat.TCX)
            elif format_lower == "gpx":
                data = client.download_activity(activity_id, dl_fmt=client.ActivityDownloadFormat.GPX)
            else:
                raise ValueError(f"Unsupported format: {format_lower}")

            # Write to file
            with open(filepath, "wb") as f:
                f.write(data)

            return filepath

        except ValueError:
            raise
        except Exception as e:
            raise GarminClientError(f"Failed to download activity {activity_id}: {e}") from e
