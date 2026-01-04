#!/usr/bin/env python3
"""Download Bulgarian audiobooks from gramofonche.chitanka.info."""

import argparse
import re
import time
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup
from mutagen.id3 import APIC, ID3, TALB, TCOM, TCON, TPE1, TPE2, TRCK, TYER

BASE_URL = "https://gramofonche.chitanka.info"
INDEX_URL = f"{BASE_URL}/prikazki/"
COVER_CDN = "https://gramofonche.zlak.one"


@dataclass
class AudiobookMetadata:
    """Metadata for an audiobook."""

    title: str
    slug: str
    url: str
    author: str | None = None
    year: str | None = None
    narrator: str | None = None
    mp3_urls: list[str] | None = None
    cover_url: str | None = None


def sanitize_filename(name: str) -> str:
    """Create a safe filename preserving Bulgarian UTF-8 characters."""
    # Remove or replace problematic characters
    name = re.sub(r'[<>:"/\\|?*]', "", name)
    # Replace multiple spaces with single space
    name = re.sub(r"\s+", " ", name)
    return name.strip()


def get_session() -> requests.Session:
    """Create a requests session with appropriate headers."""
    session = requests.Session()
    session.headers.update(
        {
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/120.0.0.0 Safari/537.36"
            ),
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "bg-BG,bg;q=0.9,en-US;q=0.8,en;q=0.7",
            "Accept-Encoding": "gzip, deflate, br",
        }
    )
    return session


def get_audiobook_links(session: requests.Session) -> list[tuple[str, str, str]]:
    """Parse index page and return list of (title, slug, url) tuples."""
    response = session.get(INDEX_URL, timeout=30)
    response.raise_for_status()

    soup = BeautifulSoup(response.text, "html.parser")
    audiobooks: list[tuple[str, str, str]] = []

    # Find all links to audiobook pages
    for link in soup.find_all("a", href=True):
        href = link.get("href", "")
        # Match /prikazki/[slug]/ pattern
        match = re.match(r"^/prikazki/([^/]+)/$", href)
        if match:
            slug = match.group(1)
            title = link.get_text(strip=True)
            if title:  # Skip empty links
                full_url = urljoin(BASE_URL, href)
                audiobooks.append((title, slug, full_url))

    return audiobooks


def parse_detail_page(
    session: requests.Session, url: str, slug: str
) -> AudiobookMetadata:
    """Extract metadata and MP3 URLs from detail page."""
    response = session.get(url, timeout=30)
    response.raise_for_status()

    soup = BeautifulSoup(response.text, "html.parser")

    # Get title from h1
    h1 = soup.find("h1")
    title = h1.get_text(strip=True) if h1 else slug

    # Find all MP3 links (relative URLs like ./filename.mp3)
    mp3_urls: list[str] = []
    for link in soup.find_all("a", href=True):
        href = link.get("href", "")
        if href.endswith(".mp3"):
            # Convert relative URL to absolute
            full_url = urljoin(url, href)
            mp3_urls.append(full_url)

    # Extract metadata from page text
    text = soup.get_text()

    # Find author (автор:)
    author = None
    author_match = re.search(r"автор:\s*([^\n]+)", text, re.IGNORECASE)
    if author_match:
        author = author_match.group(1).strip()

    # Find year (4 digits, typically near the title or in metadata)
    year = None
    year_match = re.search(r"\b(19[5-9]\d|20[0-2]\d)\b", text)
    if year_match:
        year = year_match.group(1)

    # Find narrator/cast (изпълнение:)
    narrator = None
    narrator_match = re.search(r"изпълнение:\s*([^\n]+)", text, re.IGNORECASE)
    if narrator_match:
        narrator = narrator_match.group(1).strip()

    # Find cover image
    cover_url = None
    for img in soup.find_all("img", src=True):
        src = img.get("src", "")
        if "ikona" in src or slug in src:
            # Convert to full URL
            if src.startswith("//"):
                cover_url = "https:" + src
            elif src.startswith("/"):
                cover_url = urljoin(COVER_CDN, src)
            elif src.startswith("http"):
                cover_url = src
            break

    # Also check for cover links (some pages link to cover images)
    if not cover_url:
        for link in soup.find_all("a", href=True):
            href = link.get("href", "")
            if any(ext in href.lower() for ext in [".jpg", ".jpeg", ".png"]):
                if "ikona" in href or slug in href:
                    cover_url = urljoin(COVER_CDN, href)
                    break

    return AudiobookMetadata(
        title=title,
        slug=slug,
        url=url,
        author=author,
        year=year,
        narrator=narrator,
        mp3_urls=mp3_urls,
        cover_url=cover_url,
    )


def download_file(
    session: requests.Session, url: str, output_path: Path, retries: int = 3
) -> bool:
    """Download a file with retries and exponential backoff."""
    for attempt in range(retries):
        try:
            response = session.get(url, timeout=60, stream=True)
            response.raise_for_status()

            # Ensure parent directory exists
            output_path.parent.mkdir(parents=True, exist_ok=True)

            with open(output_path, "wb") as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)

            return True
        except requests.RequestException as e:
            if attempt < retries - 1:
                wait_time = 2**attempt
                print(f"  Retry {attempt + 1}/{retries} after {wait_time}s: {e}")
                time.sleep(wait_time)
            else:
                print(f"  Failed to download {url}: {e}")
                return False
    return False


def set_id3_tags(
    filepath: Path, metadata: AudiobookMetadata, track_num: int | None = None
) -> None:
    """Set ID3 tags on an MP3 file."""
    try:
        # Try to load existing tags, or create new
        try:
            tags = ID3(filepath)
        except Exception:
            tags = ID3()

        # Clear existing tags
        tags.delete()

        # Album = book title
        tags.add(TALB(encoding=3, text=metadata.title))

        # Genre
        tags.add(TCON(encoding=3, text="Audiobook"))

        # Artist and Album Artist = author
        if metadata.author:
            tags.add(TPE1(encoding=3, text=metadata.author))
            tags.add(TPE2(encoding=3, text=metadata.author))

        # Composer = narrator/cast
        if metadata.narrator:
            tags.add(TCOM(encoding=3, text=metadata.narrator))

        # Year
        if metadata.year:
            tags.add(TYER(encoding=3, text=metadata.year))

        # Track number
        if track_num is not None:
            tags.add(TRCK(encoding=3, text=str(track_num)))

        tags.save(filepath)
    except Exception as e:
        print(f"  Warning: Could not set ID3 tags on {filepath}: {e}")


def add_cover_to_mp3(filepath: Path, cover_path: Path) -> None:
    """Embed cover art into MP3 file."""
    if not cover_path.exists():
        return

    try:
        tags = ID3(filepath)

        with open(cover_path, "rb") as f:
            cover_data = f.read()

        # Determine MIME type
        mime = "image/jpeg"
        if cover_path.suffix.lower() == ".png":
            mime = "image/png"

        tags.add(
            APIC(
                encoding=3,
                mime=mime,
                type=3,  # Cover (front)
                desc="Cover",
                data=cover_data,
            )
        )
        tags.save(filepath)
    except Exception as e:
        print(f"  Warning: Could not add cover to {filepath}: {e}")


def create_audiobook_folder(
    base_path: Path, author: str | None, year: str | None, title: str
) -> Path:
    """Create Audiobookshelf-compatible folder structure: Author/Year - Title/"""
    author_folder = sanitize_filename(author) if author else "Unknown"
    title_folder = sanitize_filename(title)

    if year:
        title_folder = f"{year} - {title_folder}"

    folder = base_path / author_folder / title_folder
    folder.mkdir(parents=True, exist_ok=True)
    return folder


def process_audiobook(
    session: requests.Session,
    metadata: AudiobookMetadata,
    output_dir: Path,
    dry_run: bool = False,
) -> bool:
    """Download and process a single audiobook."""
    if not metadata.mp3_urls:
        print(f"  No MP3 files found for {metadata.title}")
        return False

    # Create folder
    folder = create_audiobook_folder(
        output_dir, metadata.author, metadata.year, metadata.title
    )

    if dry_run:
        print(f"  Would create: {folder}")
        for mp3_url in metadata.mp3_urls:
            filename = Path(mp3_url).name
            print(f"  Would download: {filename}")
        if metadata.cover_url:
            print(f"  Would download cover: {metadata.cover_url}")
        return True

    # Download cover first (if exists)
    cover_path = folder / "cover.jpg"
    if metadata.cover_url and not cover_path.exists():
        print("  Downloading cover...")
        download_file(session, metadata.cover_url, cover_path)

    # Download MP3s
    num_files = len(metadata.mp3_urls)
    for i, mp3_url in enumerate(metadata.mp3_urls, 1):
        # Generate filename
        if num_files == 1:
            # Single file - use title
            filename = f"{sanitize_filename(metadata.title)}.mp3"
        else:
            # Multiple files - number them
            filename = f"{i:02d}.mp3"

        filepath = folder / filename

        if filepath.exists():
            print(f"  Skipping (exists): {filename}")
            continue

        print(f"  Downloading: {filename}")
        if download_file(session, mp3_url, filepath):
            # Set ID3 tags
            track_num = i if num_files > 1 else None
            set_id3_tags(filepath, metadata, track_num)

            # Add cover if available
            if cover_path.exists():
                add_cover_to_mp3(filepath, cover_path)

    return True


def main() -> None:
    """Entry point for gramofonche-downloader."""
    parser = argparse.ArgumentParser(
        description="Download Bulgarian audiobooks from gramofonche.chitanka.info"
    )
    parser.add_argument(
        "--output",
        "-o",
        type=Path,
        default=Path("/mnt/media/audiobooks/bulgarian-kids"),
        help="Output directory (default: /mnt/media/audiobooks/bulgarian-kids)",
    )
    parser.add_argument(
        "--dry-run",
        "-n",
        action="store_true",
        help="Show what would be downloaded without actually downloading",
    )
    parser.add_argument(
        "--limit",
        "-l",
        type=int,
        default=0,
        help="Limit to first N audiobooks (0 = no limit)",
    )
    parser.add_argument(
        "--delay",
        "-d",
        type=float,
        default=1.0,
        help="Delay between requests in seconds (default: 1.0)",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Show verbose output",
    )

    args = parser.parse_args()

    print("Gramofonche Audiobook Downloader")
    print("=" * 40)

    if args.dry_run:
        print("DRY RUN MODE - no files will be downloaded")
    print(f"Output directory: {args.output}")
    print()

    session = get_session()

    # Get list of all audiobooks
    print("Fetching audiobook index...")
    audiobooks = get_audiobook_links(session)
    print(f"Found {len(audiobooks)} audiobooks")

    if args.limit > 0:
        audiobooks = audiobooks[: args.limit]
        print(f"Limited to first {args.limit}")

    print()

    # Process each audiobook
    success_count = 0
    fail_count = 0

    for i, (title, slug, url) in enumerate(audiobooks, 1):
        print(f"[{i}/{len(audiobooks)}] {title}")

        try:
            metadata = parse_detail_page(session, url, slug)

            if args.verbose:
                print(f"  Author: {metadata.author or 'Unknown'}")
                print(f"  Year: {metadata.year or 'Unknown'}")
                print(f"  MP3s: {len(metadata.mp3_urls or [])}")
                if metadata.cover_url:
                    print("  Cover: Yes")

            if process_audiobook(session, metadata, args.output, args.dry_run):
                success_count += 1
            else:
                fail_count += 1

        except Exception as e:
            print(f"  Error: {e}")
            fail_count += 1

        # Rate limiting
        if i < len(audiobooks):
            time.sleep(args.delay)

    print()
    print("=" * 40)
    print(f"Completed: {success_count} success, {fail_count} failed")


if __name__ == "__main__":
    main()
