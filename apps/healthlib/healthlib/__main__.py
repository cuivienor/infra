#!/usr/bin/env python3
"""CLI entrypoint for healthlib."""

import argparse
import json
import sys
from pathlib import Path

from healthlib.config import ConfigError, load_config, save_strava_tokens
from healthlib.strava import (
    StravaClient,
    build_auth_url,
    exchange_code_for_tokens,
)


def get_secrets_path() -> Path:
    """Get default secrets path relative to module."""
    return Path(__file__).parent.parent / "vars" / "healthlib_secrets.sops.yaml"


def get_garmin_token_dir() -> Path:
    """Get Garmin token storage directory."""
    return Path.home() / ".garminconnect"


def cmd_auth_garmin(args: argparse.Namespace) -> int:
    """Handle Garmin authentication with MFA support."""
    secrets_path = get_secrets_path()
    token_dir = get_garmin_token_dir()

    try:
        config = load_config(secrets_path)
    except ConfigError as e:
        print(f"Error loading config: {e}", file=sys.stderr)
        return 1

    print("Garmin Connect Authentication")
    print("=" * 50)
    print()
    print(f"Email: {config.garmin.email}")
    print(f"Token directory: {token_dir}")
    print()

    try:
        import garth

        client = garth.Client()

        def mfa_prompt() -> str:
            return input("MFA code: ").strip()

        print("Logging in to Garmin Connect...")
        print("(You may be prompted for an MFA code)")
        print()

        client.login(config.garmin.email, config.garmin.password, prompt_mfa=mfa_prompt)

        token_dir.mkdir(parents=True, exist_ok=True)
        client.dump(str(token_dir))

        print()
        print("Success! Authenticated as:")
        print(f"  {client.profile.get('displayName', 'unknown')}")
        print()
        print(f"Tokens saved to: {token_dir}")
        print()
        print("You can now use Garmin commands.")

        return 0

    except ImportError:
        print("Error: garth package not installed", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


def cmd_auth_strava(args: argparse.Namespace) -> int:
    """Handle Strava OAuth authentication."""
    secrets_path = get_secrets_path()

    try:
        config = load_config(secrets_path)
    except ConfigError as e:
        print(f"Error loading config: {e}", file=sys.stderr)
        print(
            "\nMake sure you have configured Strava client_id and client_secret in:",
            file=sys.stderr,
        )
        print(f"  {secrets_path}", file=sys.stderr)
        return 1

    redirect_uri = "http://localhost"

    auth_url = build_auth_url(
        client_id=config.strava.client_id,
        redirect_uri=redirect_uri,
    )

    print("Strava OAuth Setup")
    print("=" * 50)
    print()
    print("1. Open this URL in a browser:")
    print()
    print(f"   {auth_url}")
    print()
    print("2. Authorize the application")
    print()
    print("3. You'll be redirected to a URL like:")
    print("   http://localhost/?state=&code=XXXXXX&scope=...")
    print()
    print("4. Copy the 'code' parameter value and paste it below")
    print()

    try:
        code = input("Authorization code: ").strip()
    except (EOFError, KeyboardInterrupt):
        print("\nAborted.", file=sys.stderr)
        return 1

    if not code:
        print("Error: No code provided", file=sys.stderr)
        return 1

    print()
    print("Exchanging code for tokens...")

    try:
        tokens = exchange_code_for_tokens(
            client_id=config.strava.client_id,
            client_secret=config.strava.client_secret,
            code=code,
        )
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    print("Saving tokens to secrets file...")

    try:
        save_strava_tokens(
            secrets_path,
            tokens["access_token"],
            tokens["refresh_token"],
            tokens["expires_at"],
        )
    except ConfigError as e:
        print(f"Error saving tokens: {e}", file=sys.stderr)
        print()
        print("You can manually add these tokens to your secrets file:")
        print(f"  access_token: {tokens['access_token']}")
        print(f"  refresh_token: {tokens['refresh_token']}")
        print(f"  expires_at: {tokens['expires_at']}")
        return 1

    athlete = tokens.get("athlete", {})
    print()
    print("Success! Authenticated as:")
    print(f"  {athlete.get('firstname', '')} {athlete.get('lastname', '')}")
    print(f"  ID: {athlete.get('id', 'unknown')}")
    print()
    print("Tokens saved. You can now use Strava commands.")

    return 0


def cmd_strava_list(args: argparse.Namespace) -> int:
    """List Strava activities."""
    secrets_path = get_secrets_path()

    try:
        config = load_config(secrets_path)
    except ConfigError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    client = StravaClient(config.strava, secrets_path)

    try:
        activities = client.list_activities(per_page=args.limit)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    if args.json:
        output = [
            {
                "id": a.activity_id,
                "name": a.name,
                "type": a.activity_type,
                "start_date": a.start_date.isoformat(),
                "distance": a.distance,
                "moving_time": a.moving_time,
            }
            for a in activities
        ]
        print(json.dumps(output, indent=2))
    else:
        for a in activities:
            dist_km = a.distance / 1000
            mins = a.moving_time // 60
            print(f"{a.activity_id:>12}  {a.start_date.strftime('%Y-%m-%d')}  {a.activity_type:<10}  {dist_km:>6.1f}km  {mins:>3}min  {a.name}")

    return 0


def cmd_strava_get(args: argparse.Namespace) -> int:
    """Get Strava activity details."""
    secrets_path = get_secrets_path()

    try:
        config = load_config(secrets_path)
    except ConfigError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    client = StravaClient(config.strava, secrets_path)

    try:
        activity = client.get_activity(args.activity_id)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(activity.raw_data, indent=2))
    else:
        print(f"ID:          {activity.activity_id}")
        print(f"Name:        {activity.name}")
        print(f"Type:        {activity.activity_type}")
        print(f"Date:        {activity.start_date.strftime('%Y-%m-%d %H:%M')}")
        print(f"Distance:    {activity.distance / 1000:.2f} km")
        print(f"Moving Time: {activity.moving_time // 60} min")
        print(f"Elapsed:     {activity.elapsed_time // 60} min")
        if activity.total_elevation_gain:
            print(f"Elevation:   {activity.total_elevation_gain:.0f} m")
        if activity.average_heartrate:
            print(f"Avg HR:      {activity.average_heartrate:.0f} bpm")
        if activity.description:
            print(f"Description: {activity.description}")

    return 0


def cmd_strava_update(args: argparse.Namespace) -> int:
    """Update Strava activity."""
    secrets_path = get_secrets_path()

    try:
        config = load_config(secrets_path)
    except ConfigError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    client = StravaClient(config.strava, secrets_path)

    try:
        activity = client.update_activity(
            args.activity_id,
            name=args.name,
            description=args.description,
        )
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    print(f"Updated activity {activity.activity_id}:")
    print(f"  Name: {activity.name}")
    if activity.description:
        print(f"  Description: {activity.description}")

    return 0


def cmd_garmin_list(args: argparse.Namespace) -> int:
    """List Garmin activities."""
    secrets_path = get_secrets_path()

    try:
        config = load_config(secrets_path)
    except ConfigError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    try:
        from healthlib.garmin import GarminClient
    except ImportError:
        print("Error: garminconnect package not installed", file=sys.stderr)
        return 1

    token_dir = get_garmin_token_dir()
    client = GarminClient(config.garmin, token_dir=token_dir)

    try:
        activities = client.list_activities(limit=args.limit)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        print("\nIf this is a login error, try running: healthlib auth garmin", file=sys.stderr)
        return 1

    if args.json:
        output = [
            {
                "id": a.activity_id,
                "name": a.activity_name,
                "type": a.activity_type,
                "start_time": a.start_time.isoformat(),
                "distance": a.distance_meters,
                "duration": a.duration_seconds,
            }
            for a in activities
        ]
        print(json.dumps(output, indent=2))
    else:
        for a in activities:
            dist_km = (a.distance_meters or 0) / 1000
            mins = int(a.duration_seconds // 60)
            print(f"{a.activity_id:>12}  {a.start_time.strftime('%Y-%m-%d')}  {a.activity_type:<10}  {dist_km:>6.1f}km  {mins:>3}min  {a.activity_name}")

    return 0


def cmd_garmin_get(args: argparse.Namespace) -> int:
    """Get Garmin activity details."""
    secrets_path = get_secrets_path()

    try:
        config = load_config(secrets_path)
    except ConfigError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    try:
        from healthlib.garmin import GarminClient
    except ImportError:
        print("Error: garminconnect package not installed", file=sys.stderr)
        return 1

    token_dir = get_garmin_token_dir()
    client = GarminClient(config.garmin, token_dir=token_dir)

    try:
        activity = client.get_activity(args.activity_id)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(activity.raw_data, indent=2))
    else:
        print(f"ID:          {activity.activity_id}")
        print(f"Name:        {activity.activity_name}")
        print(f"Type:        {activity.activity_type}")
        print(f"Date:        {activity.start_time.strftime('%Y-%m-%d %H:%M')}")
        if activity.distance_meters:
            print(f"Distance:    {activity.distance_meters / 1000:.2f} km")
        print(f"Duration:    {int(activity.duration_seconds // 60)} min")
        if activity.elevation_gain:
            print(f"Elevation:   {activity.elevation_gain:.0f} m")
        if activity.average_hr:
            print(f"Avg HR:      {activity.average_hr} bpm")
        if activity.description:
            print(f"Description: {activity.description}")

    return 0


def main() -> int:
    """Entry point for healthlib CLI."""
    parser = argparse.ArgumentParser(
        description="Personal library for interacting with Garmin and Strava APIs"
    )
    parser.add_argument(
        "--version",
        action="store_true",
        help="Show version and exit",
    )

    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # Auth commands
    auth_parser = subparsers.add_parser("auth", help="Authentication setup")
    auth_subparsers = auth_parser.add_subparsers(dest="auth_command")
    auth_subparsers.add_parser("strava", help="Setup Strava OAuth tokens")
    auth_subparsers.add_parser("garmin", help="Setup Garmin Connect tokens (with MFA)")

    # Strava commands
    strava_parser = subparsers.add_parser("strava", help="Strava operations")
    strava_subparsers = strava_parser.add_subparsers(dest="strava_command")

    strava_list = strava_subparsers.add_parser("list", help="List activities")
    strava_list.add_argument("--limit", type=int, default=20, help="Number of activities")
    strava_list.add_argument("--json", action="store_true", help="Output as JSON")

    strava_get = strava_subparsers.add_parser("get", help="Get activity details")
    strava_get.add_argument("activity_id", type=int, help="Activity ID")
    strava_get.add_argument("--json", action="store_true", help="Output as JSON")

    strava_update = strava_subparsers.add_parser("update", help="Update activity")
    strava_update.add_argument("activity_id", type=int, help="Activity ID")
    strava_update.add_argument("--name", help="New activity name")
    strava_update.add_argument("--description", help="New activity description")

    # Garmin commands
    garmin_parser = subparsers.add_parser("garmin", help="Garmin operations")
    garmin_subparsers = garmin_parser.add_subparsers(dest="garmin_command")

    garmin_list = garmin_subparsers.add_parser("list", help="List activities")
    garmin_list.add_argument("--limit", type=int, default=20, help="Number of activities")
    garmin_list.add_argument("--json", action="store_true", help="Output as JSON")

    garmin_get = garmin_subparsers.add_parser("get", help="Get activity details")
    garmin_get.add_argument("activity_id", type=int, help="Activity ID")
    garmin_get.add_argument("--json", action="store_true", help="Output as JSON")

    args = parser.parse_args()

    if args.version:
        from healthlib import __version__

        print(f"healthlib {__version__}")
        return 0

    if args.command is None:
        parser.print_help()
        return 0

    if args.command == "auth":
        if args.auth_command == "strava":
            return cmd_auth_strava(args)
        if args.auth_command == "garmin":
            return cmd_auth_garmin(args)
        auth_parser.print_help()
        return 0

    if args.command == "strava":
        if args.strava_command == "list":
            return cmd_strava_list(args)
        if args.strava_command == "get":
            return cmd_strava_get(args)
        if args.strava_command == "update":
            return cmd_strava_update(args)
        strava_parser.print_help()
        return 0

    if args.command == "garmin":
        if args.garmin_command == "list":
            return cmd_garmin_list(args)
        if args.garmin_command == "get":
            return cmd_garmin_get(args)
        garmin_parser.print_help()
        return 0

    parser.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
