"""Tests for gramofonche-downloader."""

from pathlib import Path

from gramofonche_downloader import __version__
from gramofonche_downloader.__main__ import (
    AudiobookMetadata,
    create_audiobook_folder,
    sanitize_filename,
)


def test_version() -> None:
    """Test that version is defined."""
    assert __version__ == "0.1.0"


class TestSanitizeFilename:
    """Tests for sanitize_filename function."""

    def test_preserves_cyrillic(self) -> None:
        """Cyrillic characters should be preserved."""
        assert sanitize_filename("Мечо-Пух") == "Мечо-Пух"

    def test_removes_invalid_chars(self) -> None:
        """Invalid filesystem characters should be removed."""
        assert sanitize_filename('Test<>:"/\\|?*File') == "TestFile"

    def test_collapses_whitespace(self) -> None:
        """Multiple spaces should become single space."""
        assert sanitize_filename("Too   Many   Spaces") == "Too Many Spaces"

    def test_strips_whitespace(self) -> None:
        """Leading/trailing whitespace should be stripped."""
        assert sanitize_filename("  Padded  ") == "Padded"


class TestCreateAudiobookFolder:
    """Tests for create_audiobook_folder function."""

    def test_with_author_and_year(self, tmp_path: Path) -> None:
        """Folder should be Author/Year - Title/."""
        folder = create_audiobook_folder(
            tmp_path, author="Алан Милн", year="1979", title="Мечо-Пух"
        )
        assert folder == tmp_path / "Алан Милн" / "1979 - Мечо-Пух"
        assert folder.exists()

    def test_without_author(self, tmp_path: Path) -> None:
        """Missing author should use 'Unknown'."""
        folder = create_audiobook_folder(
            tmp_path, author=None, year="1985", title="Аладин"
        )
        assert folder == tmp_path / "Unknown" / "1985 - Аладин"

    def test_without_year(self, tmp_path: Path) -> None:
        """Missing year should omit year prefix."""
        folder = create_audiobook_folder(
            tmp_path, author="Unknown", year=None, title="Test Title"
        )
        assert folder == tmp_path / "Unknown" / "Test Title"


class TestAudiobookMetadata:
    """Tests for AudiobookMetadata dataclass."""

    def test_required_fields(self) -> None:
        """Required fields must be provided."""
        metadata = AudiobookMetadata(
            title="Test",
            slug="test",
            url="https://example.com/test/",
        )
        assert metadata.title == "Test"
        assert metadata.slug == "test"
        assert metadata.url == "https://example.com/test/"

    def test_optional_fields_default_none(self) -> None:
        """Optional fields should default to None."""
        metadata = AudiobookMetadata(
            title="Test",
            slug="test",
            url="https://example.com/test/",
        )
        assert metadata.author is None
        assert metadata.year is None
        assert metadata.narrator is None
        assert metadata.mp3_urls is None
        assert metadata.cover_url is None

    def test_all_fields(self) -> None:
        """All fields can be set."""
        metadata = AudiobookMetadata(
            title="Мечо-Пух",
            slug="mecho-puh",
            url="https://example.com/mecho-puh/",
            author="Алан Милн",
            year="1979",
            narrator="Иван Иванов",
            mp3_urls=["https://example.com/file.mp3"],
            cover_url="https://example.com/cover.jpg",
        )
        assert metadata.author == "Алан Милн"
        assert metadata.year == "1979"
        assert metadata.mp3_urls == ["https://example.com/file.mp3"]
