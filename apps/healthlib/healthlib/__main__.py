#!/usr/bin/env python3
"""CLI entrypoint for healthlib."""

import argparse
import sys


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

    # Placeholder subcommands - will be implemented
    subparsers.add_parser("garmin", help="Garmin operations")
    subparsers.add_parser("strava", help="Strava operations")
    subparsers.add_parser("auth", help="Authentication setup")

    args = parser.parse_args()

    if args.version:
        from healthlib import __version__

        print(f"healthlib {__version__}")
        return 0

    if args.command is None:
        parser.print_help()
        return 0

    # Command dispatch will be added as we implement each module
    print(f"Command '{args.command}' not yet implemented")
    return 1


if __name__ == "__main__":
    sys.exit(main())
