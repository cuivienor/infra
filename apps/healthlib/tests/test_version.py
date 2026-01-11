"""Tests for healthlib version."""

from healthlib import __version__


def test_version() -> None:
    """Test that version is defined."""
    assert __version__ == "0.1.0"
