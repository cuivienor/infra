"""Tests for healthlib configuration module."""

import os
from pathlib import Path
from unittest.mock import patch

import pytest

from healthlib.config import (
    Config,
    ConfigError,
    GarminConfig,
    StravaConfig,
    load_config,
)


class TestGarminConfig:
    """Tests for GarminConfig dataclass."""

    def test_required_fields(self) -> None:
        """Required fields must be provided."""
        config = GarminConfig(email="test@example.com", password="secret")
        assert config.email == "test@example.com"
        assert config.password == "secret"


class TestStravaConfig:
    """Tests for StravaConfig dataclass."""

    def test_required_fields(self) -> None:
        """Required fields must be provided."""
        config = StravaConfig(client_id="123", client_secret="abc")
        assert config.client_id == "123"
        assert config.client_secret == "abc"

    def test_optional_fields_default_none(self) -> None:
        """Optional fields should default to None."""
        config = StravaConfig(client_id="123", client_secret="abc")
        assert config.access_token is None
        assert config.refresh_token is None
        assert config.expires_at is None

    def test_all_fields(self) -> None:
        """All fields can be set."""
        config = StravaConfig(
            client_id="123",
            client_secret="abc",
            access_token="token",
            refresh_token="refresh",
            expires_at=1234567890,
        )
        assert config.access_token == "token"
        assert config.refresh_token == "refresh"
        assert config.expires_at == 1234567890


class TestConfig:
    """Tests for Config dataclass."""

    def test_combined_config(self) -> None:
        """Config combines Garmin and Strava configs."""
        garmin = GarminConfig(email="test@example.com", password="secret")
        strava = StravaConfig(client_id="123", client_secret="abc")
        config = Config(garmin=garmin, strava=strava)
        assert config.garmin.email == "test@example.com"
        assert config.strava.client_id == "123"


class TestLoadConfigFromEnv:
    """Tests for load_config using environment variables."""

    def test_load_from_env_minimal(self, tmp_path: Path) -> None:
        """Load config from environment variables (no SOPS file)."""
        env = {
            "GARMIN_EMAIL": "garmin@example.com",
            "GARMIN_PASSWORD": "garminpass",
            "STRAVA_CLIENT_ID": "strava123",
            "STRAVA_CLIENT_SECRET": "stravasecret",
        }
        # Use non-existent path to force env-only mode
        secrets_path = tmp_path / "nonexistent.sops.yaml"

        with patch.dict(os.environ, env, clear=False):
            config = load_config(secrets_path)

        assert config.garmin.email == "garmin@example.com"
        assert config.garmin.password == "garminpass"
        assert config.strava.client_id == "strava123"
        assert config.strava.client_secret == "stravasecret"
        assert config.strava.access_token is None
        assert config.strava.refresh_token is None

    def test_load_from_env_with_tokens(self, tmp_path: Path) -> None:
        """Load config with optional Strava tokens from env."""
        env = {
            "GARMIN_EMAIL": "garmin@example.com",
            "GARMIN_PASSWORD": "garminpass",
            "STRAVA_CLIENT_ID": "strava123",
            "STRAVA_CLIENT_SECRET": "stravasecret",
            "STRAVA_ACCESS_TOKEN": "access123",
            "STRAVA_REFRESH_TOKEN": "refresh456",
            "STRAVA_EXPIRES_AT": "1234567890",
        }
        secrets_path = tmp_path / "nonexistent.sops.yaml"

        with patch.dict(os.environ, env, clear=False):
            config = load_config(secrets_path)

        assert config.strava.access_token == "access123"
        assert config.strava.refresh_token == "refresh456"
        assert config.strava.expires_at == 1234567890

    def test_missing_garmin_credentials_raises(self, tmp_path: Path) -> None:
        """Raise ConfigError when Garmin credentials are missing."""
        env = {
            "STRAVA_CLIENT_ID": "strava123",
            "STRAVA_CLIENT_SECRET": "stravasecret",
        }
        secrets_path = tmp_path / "nonexistent.sops.yaml"

        # Clear any existing Garmin env vars
        with patch.dict(
            os.environ,
            {**env, "GARMIN_EMAIL": "", "GARMIN_PASSWORD": ""},
            clear=False,
        ):
            # Also ensure they're not set at all
            os.environ.pop("GARMIN_EMAIL", None)
            os.environ.pop("GARMIN_PASSWORD", None)
            with pytest.raises(ConfigError, match="Garmin credentials not found"):
                load_config(secrets_path)

    def test_missing_strava_credentials_raises(self, tmp_path: Path) -> None:
        """Raise ConfigError when Strava credentials are missing."""
        env = {
            "GARMIN_EMAIL": "garmin@example.com",
            "GARMIN_PASSWORD": "garminpass",
        }
        secrets_path = tmp_path / "nonexistent.sops.yaml"

        with patch.dict(
            os.environ,
            {**env, "STRAVA_CLIENT_ID": "", "STRAVA_CLIENT_SECRET": ""},
            clear=False,
        ):
            os.environ.pop("STRAVA_CLIENT_ID", None)
            os.environ.pop("STRAVA_CLIENT_SECRET", None)
            with pytest.raises(ConfigError, match="Strava credentials not found"):
                load_config(secrets_path)
