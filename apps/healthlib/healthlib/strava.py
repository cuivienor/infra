"""Strava API client.

Provides OAuth2 authentication and activity operations via the official Strava v3 API.
"""

import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any
from urllib.parse import urlencode

import requests

from healthlib.config import StravaConfig, save_strava_tokens


STRAVA_AUTH_URL = "https://www.strava.com/oauth/authorize"
STRAVA_TOKEN_URL = "https://www.strava.com/oauth/token"
STRAVA_API_BASE = "https://www.strava.com/api/v3"


@dataclass
class StravaActivity:
    """Strava activity summary."""

    activity_id: int
    name: str
    activity_type: str
    start_date: datetime
    elapsed_time: int
    moving_time: int
    distance: float
    total_elevation_gain: float | None
    average_heartrate: float | None
    max_heartrate: float | None

    @classmethod
    def from_api_response(cls, data: dict[str, Any]) -> "StravaActivity":
        """Create from Strava API response."""
        start_date_str = data.get("start_date_local", data.get("start_date", ""))
        if start_date_str:
            start_date = datetime.fromisoformat(start_date_str.replace("Z", "+00:00"))
        else:
            start_date = datetime.now()

        return cls(
            activity_id=data["id"],
            name=data.get("name", ""),
            activity_type=data.get("type", "unknown"),
            start_date=start_date,
            elapsed_time=data.get("elapsed_time", 0),
            moving_time=data.get("moving_time", 0),
            distance=data.get("distance", 0.0),
            total_elevation_gain=data.get("total_elevation_gain"),
            average_heartrate=data.get("average_heartrate"),
            max_heartrate=data.get("max_heartrate"),
        )


@dataclass
class StravaActivityDetail:
    """Detailed Strava activity with full metadata."""

    activity_id: int
    name: str
    description: str | None
    activity_type: str
    start_date: datetime
    elapsed_time: int
    moving_time: int
    distance: float
    total_elevation_gain: float | None
    average_speed: float | None
    max_speed: float | None
    average_heartrate: float | None
    max_heartrate: float | None
    calories: float | None
    gear_id: str | None
    raw_data: dict[str, Any]

    @classmethod
    def from_api_response(cls, data: dict[str, Any]) -> "StravaActivityDetail":
        """Create from Strava API response."""
        start_date_str = data.get("start_date_local", data.get("start_date", ""))
        if start_date_str:
            start_date = datetime.fromisoformat(start_date_str.replace("Z", "+00:00"))
        else:
            start_date = datetime.now()

        return cls(
            activity_id=data["id"],
            name=data.get("name", ""),
            description=data.get("description"),
            activity_type=data.get("type", "unknown"),
            start_date=start_date,
            elapsed_time=data.get("elapsed_time", 0),
            moving_time=data.get("moving_time", 0),
            distance=data.get("distance", 0.0),
            total_elevation_gain=data.get("total_elevation_gain"),
            average_speed=data.get("average_speed"),
            max_speed=data.get("max_speed"),
            average_heartrate=data.get("average_heartrate"),
            max_heartrate=data.get("max_heartrate"),
            calories=data.get("calories"),
            gear_id=data.get("gear_id"),
            raw_data=data,
        )


class StravaClientError(Exception):
    """Raised when Strava client operations fail."""


class StravaAuthError(StravaClientError):
    """Raised when authentication fails or tokens are missing."""


class StravaRateLimitError(StravaClientError):
    """Raised when rate limit is exceeded."""

    def __init__(self, message: str, retry_after: int | None = None) -> None:
        super().__init__(message)
        self.retry_after = retry_after


def build_auth_url(client_id: str, redirect_uri: str, scopes: list[str] | None = None) -> str:
    """Build Strava OAuth authorization URL.

    Args:
        client_id: Strava application client ID.
        redirect_uri: URL to redirect after authorization.
        scopes: List of scopes to request. Defaults to activity:read_all,activity:write.

    Returns:
        Full authorization URL for user to visit.
    """
    if scopes is None:
        scopes = ["activity:read_all", "activity:write"]

    params = {
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": ",".join(scopes),
        "approval_prompt": "auto",
    }

    return f"{STRAVA_AUTH_URL}?{urlencode(params)}"


def exchange_code_for_tokens(
    client_id: str,
    client_secret: str,
    code: str,
) -> dict[str, Any]:
    """Exchange authorization code for access and refresh tokens.

    Args:
        client_id: Strava application client ID.
        client_secret: Strava application client secret.
        code: Authorization code from OAuth callback.

    Returns:
        Dict with access_token, refresh_token, expires_at, and athlete info.

    Raises:
        StravaAuthError: If token exchange fails.
    """
    response = requests.post(
        STRAVA_TOKEN_URL,
        data={
            "client_id": client_id,
            "client_secret": client_secret,
            "code": code,
            "grant_type": "authorization_code",
        },
        timeout=30,
    )

    if response.status_code != 200:
        raise StravaAuthError(f"Token exchange failed: {response.text}")

    return response.json()  # type: ignore[no-any-return]


class StravaClient:
    """Strava API client with automatic token refresh."""

    def __init__(
        self,
        config: StravaConfig,
        secrets_path: Path | None = None,
    ) -> None:
        """Initialize Strava client.

        Args:
            config: Strava OAuth configuration.
            secrets_path: Path to SOPS secrets file for token persistence.
        """
        self._config = config
        self._secrets_path = secrets_path
        self._session = requests.Session()

    def _ensure_valid_token(self) -> str:
        """Ensure we have a valid access token, refreshing if needed.

        Returns:
            Valid access token.

        Raises:
            StravaAuthError: If no tokens available or refresh fails.
        """
        if not self._config.refresh_token:
            raise StravaAuthError(
                "No refresh token available. Run 'healthlib auth strava' first."
            )

        if not self._config.access_token or not self._config.expires_at:
            return self._refresh_token()

        if time.time() >= self._config.expires_at - 300:
            return self._refresh_token()

        return self._config.access_token

    def _refresh_token(self) -> str:
        """Refresh access token using refresh token.

        Returns:
            New access token.

        Raises:
            StravaAuthError: If refresh fails.
        """
        if not self._config.refresh_token:
            raise StravaAuthError("No refresh token available")

        response = requests.post(
            STRAVA_TOKEN_URL,
            data={
                "client_id": self._config.client_id,
                "client_secret": self._config.client_secret,
                "grant_type": "refresh_token",
                "refresh_token": self._config.refresh_token,
            },
            timeout=30,
        )

        if response.status_code != 200:
            raise StravaAuthError(f"Token refresh failed: {response.text}")

        data = response.json()

        self._config.access_token = data["access_token"]
        self._config.refresh_token = data["refresh_token"]
        self._config.expires_at = data["expires_at"]

        if self._secrets_path:
            save_strava_tokens(
                self._secrets_path,
                data["access_token"],
                data["refresh_token"],
                data["expires_at"],
            )

        return data["access_token"]

    def _request(
        self,
        method: str,
        endpoint: str,
        **kwargs: Any,
    ) -> dict[str, Any] | list[Any]:
        """Make authenticated API request.

        Args:
            method: HTTP method (GET, POST, PUT, etc.).
            endpoint: API endpoint (e.g., "/athlete/activities").
            **kwargs: Additional arguments for requests.

        Returns:
            JSON response data.

        Raises:
            StravaClientError: If request fails.
            StravaRateLimitError: If rate limit exceeded.
        """
        token = self._ensure_valid_token()

        headers = kwargs.pop("headers", {})
        headers["Authorization"] = f"Bearer {token}"

        url = f"{STRAVA_API_BASE}{endpoint}"

        response = self._session.request(
            method,
            url,
            headers=headers,
            timeout=30,
            **kwargs,
        )

        if response.status_code == 429:
            retry_after = response.headers.get("Retry-After")
            raise StravaRateLimitError(
                "Rate limit exceeded",
                retry_after=int(retry_after) if retry_after else None,
            )

        if response.status_code >= 400:
            raise StravaClientError(
                f"API request failed ({response.status_code}): {response.text}"
            )

        return response.json()  # type: ignore[no-any-return]

    def list_activities(
        self,
        before: int | None = None,
        after: int | None = None,
        page: int = 1,
        per_page: int = 30,
    ) -> list[StravaActivity]:
        """List athlete activities.

        Args:
            before: Filter activities before this Unix timestamp.
            after: Filter activities after this Unix timestamp.
            page: Page number (1-indexed).
            per_page: Number of activities per page (max 200).

        Returns:
            List of StravaActivity summaries.
        """
        params: dict[str, Any] = {
            "page": page,
            "per_page": min(per_page, 200),
        }
        if before:
            params["before"] = before
        if after:
            params["after"] = after

        data = self._request("GET", "/athlete/activities", params=params)
        return [StravaActivity.from_api_response(a) for a in data]  # type: ignore[union-attr]

    def get_activity(self, activity_id: int) -> StravaActivityDetail:
        """Get detailed information for a specific activity.

        Args:
            activity_id: Strava activity ID.

        Returns:
            StravaActivityDetail with full metadata.
        """
        data = self._request("GET", f"/activities/{activity_id}")
        return StravaActivityDetail.from_api_response(data)  # type: ignore[arg-type]

    def update_activity(
        self,
        activity_id: int,
        name: str | None = None,
        description: str | None = None,
        activity_type: str | None = None,
        gear_id: str | None = None,
        commute: bool | None = None,
        trainer: bool | None = None,
        hide_from_home: bool | None = None,
    ) -> StravaActivityDetail:
        """Update activity metadata.

        Args:
            activity_id: Strava activity ID.
            name: New activity name.
            description: New activity description.
            activity_type: New activity type (e.g., "Run", "Ride").
            gear_id: Gear ID to associate.
            commute: Mark as commute.
            trainer: Mark as trainer activity.
            hide_from_home: Hide from home feed.

        Returns:
            Updated StravaActivityDetail.
        """
        update_data: dict[str, Any] = {}

        if name is not None:
            update_data["name"] = name
        if description is not None:
            update_data["description"] = description
        if activity_type is not None:
            update_data["type"] = activity_type
        if gear_id is not None:
            update_data["gear_id"] = gear_id
        if commute is not None:
            update_data["commute"] = commute
        if trainer is not None:
            update_data["trainer"] = trainer
        if hide_from_home is not None:
            update_data["hide_from_home"] = hide_from_home

        if not update_data:
            return self.get_activity(activity_id)

        data = self._request("PUT", f"/activities/{activity_id}", json=update_data)
        return StravaActivityDetail.from_api_response(data)  # type: ignore[arg-type]
