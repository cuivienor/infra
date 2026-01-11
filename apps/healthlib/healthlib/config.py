"""Configuration management for healthlib.

Loads secrets from SOPS-encrypted YAML files or environment variables.
"""

import os
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml


@dataclass
class GarminConfig:
    """Garmin credentials configuration."""

    email: str
    password: str


@dataclass
class StravaConfig:
    """Strava OAuth configuration."""

    client_id: str
    client_secret: str
    access_token: str | None = None
    refresh_token: str | None = None
    expires_at: int | None = None


@dataclass
class Config:
    """Complete healthlib configuration."""

    garmin: GarminConfig
    strava: StravaConfig


class ConfigError(Exception):
    """Raised when configuration is invalid or missing."""


def _decrypt_sops_file(path: Path) -> dict[str, Any]:
    """Decrypt a SOPS-encrypted YAML file.

    Args:
        path: Path to the encrypted YAML file.

    Returns:
        Decrypted YAML content as a dictionary.

    Raises:
        ConfigError: If decryption fails or file doesn't exist.
    """
    if not path.exists():
        raise ConfigError(f"Secrets file not found: {path}")

    try:
        result = subprocess.run(
            ["sops", "--decrypt", str(path)],
            capture_output=True,
            text=True,
            check=True,
        )
        return yaml.safe_load(result.stdout)  # type: ignore[no-any-return]
    except subprocess.CalledProcessError as e:
        raise ConfigError(f"Failed to decrypt {path}: {e.stderr}") from e
    except yaml.YAMLError as e:
        raise ConfigError(f"Invalid YAML in {path}: {e}") from e


def _get_env_or_none(key: str) -> str | None:
    """Get environment variable or None if not set."""
    value = os.environ.get(key)
    return value if value else None


def load_config(secrets_path: Path | None = None) -> Config:
    """Load configuration from SOPS file or environment variables.

    Priority:
    1. Environment variables (if set)
    2. SOPS-encrypted secrets file

    Environment variables:
    - GARMIN_EMAIL, GARMIN_PASSWORD
    - STRAVA_CLIENT_ID, STRAVA_CLIENT_SECRET
    - STRAVA_ACCESS_TOKEN, STRAVA_REFRESH_TOKEN, STRAVA_EXPIRES_AT

    Args:
        secrets_path: Path to SOPS-encrypted secrets file.
            Defaults to vars/healthlib_secrets.sops.yaml relative to this module.

    Returns:
        Config object with all credentials loaded.

    Raises:
        ConfigError: If required credentials are missing.
    """
    # Default secrets path relative to this file
    if secrets_path is None:
        module_dir = Path(__file__).parent.parent
        secrets_path = module_dir / "vars" / "healthlib_secrets.sops.yaml"

    # Try to load from SOPS file first
    sops_data: dict[str, Any] = {}
    if secrets_path.exists():
        try:
            sops_data = _decrypt_sops_file(secrets_path)
        except ConfigError:
            # If decryption fails, fall back to env vars only
            pass

    garmin_data = sops_data.get("garmin", {})
    strava_data = sops_data.get("strava", {})

    # Garmin config (env vars override SOPS)
    garmin_email = _get_env_or_none("GARMIN_EMAIL") or garmin_data.get("email")
    garmin_password = _get_env_or_none("GARMIN_PASSWORD") or garmin_data.get("password")

    if not garmin_email or not garmin_password:
        raise ConfigError(
            "Garmin credentials not found. Set GARMIN_EMAIL and GARMIN_PASSWORD "
            "environment variables or configure in SOPS file."
        )

    garmin_config = GarminConfig(email=garmin_email, password=garmin_password)

    # Strava config (env vars override SOPS)
    strava_client_id = _get_env_or_none("STRAVA_CLIENT_ID") or strava_data.get(
        "client_id"
    )
    strava_client_secret = _get_env_or_none("STRAVA_CLIENT_SECRET") or strava_data.get(
        "client_secret"
    )

    if not strava_client_id or not strava_client_secret:
        raise ConfigError(
            "Strava credentials not found. Set STRAVA_CLIENT_ID and STRAVA_CLIENT_SECRET "
            "environment variables or configure in SOPS file."
        )

    # Optional token fields
    strava_access_token = _get_env_or_none("STRAVA_ACCESS_TOKEN") or strava_data.get(
        "access_token"
    )
    strava_refresh_token = _get_env_or_none("STRAVA_REFRESH_TOKEN") or strava_data.get(
        "refresh_token"
    )
    strava_expires_at_str = _get_env_or_none("STRAVA_EXPIRES_AT")
    strava_expires_at: int | None = None
    if strava_expires_at_str:
        strava_expires_at = int(strava_expires_at_str)
    elif strava_data.get("expires_at"):
        strava_expires_at = int(strava_data["expires_at"])

    # Normalize empty strings to None
    if strava_access_token == "":
        strava_access_token = None
    if strava_refresh_token == "":
        strava_refresh_token = None

    strava_config = StravaConfig(
        client_id=strava_client_id,
        client_secret=strava_client_secret,
        access_token=strava_access_token,
        refresh_token=strava_refresh_token,
        expires_at=strava_expires_at,
    )

    return Config(garmin=garmin_config, strava=strava_config)


def save_strava_tokens(
    secrets_path: Path,
    access_token: str,
    refresh_token: str,
    expires_at: int,
) -> None:
    """Update Strava tokens in the SOPS-encrypted secrets file.

    Args:
        secrets_path: Path to SOPS-encrypted secrets file.
        access_token: New access token.
        refresh_token: New refresh token.
        expires_at: Token expiration timestamp.

    Raises:
        ConfigError: If updating fails.
    """
    if not secrets_path.exists():
        raise ConfigError(f"Secrets file not found: {secrets_path}")

    # Decrypt existing file
    data = _decrypt_sops_file(secrets_path)

    # Update strava tokens
    if "strava" not in data:
        data["strava"] = {}
    data["strava"]["access_token"] = access_token
    data["strava"]["refresh_token"] = refresh_token
    data["strava"]["expires_at"] = expires_at

    # Write back and re-encrypt
    temp_path = secrets_path.with_suffix(".tmp.yaml")
    try:
        # Write plaintext temporarily
        with open(temp_path, "w") as f:
            yaml.safe_dump(data, f, default_flow_style=False)

        # Encrypt in place
        subprocess.run(
            ["sops", "--encrypt", "--in-place", str(temp_path)],
            capture_output=True,
            text=True,
            check=True,
        )

        # Move to final location
        temp_path.rename(secrets_path)

    except subprocess.CalledProcessError as e:
        # Clean up temp file on failure
        if temp_path.exists():
            temp_path.unlink()
        raise ConfigError(f"Failed to encrypt {secrets_path}: {e.stderr}") from e
    except Exception as e:
        # Clean up temp file on failure
        if temp_path.exists():
            temp_path.unlink()
        raise ConfigError(f"Failed to save tokens: {e}") from e
