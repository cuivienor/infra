"""Basic tests for gramofonche-downloader."""

from gramofonche_downloader import __version__
from gramofonche_downloader.__main__ import main


def test_version() -> None:
    """Test that version is defined."""
    assert __version__ == "0.1.0"


def test_main_runs(capsys: object) -> None:
    """Test that main function runs without error."""
    main()
    # For now, just verify it doesn't crash
    # Will add more tests when implementing actual functionality
