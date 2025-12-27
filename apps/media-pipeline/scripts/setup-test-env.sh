#!/bin/bash
set -e

# Get script directory for finding binaries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Parse arguments
REMOTE_HOST=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --remote|-r)
            REMOTE_HOST="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--remote <host>] [MEDIA_BASE=/path]"
            echo ""
            echo "Options:"
            echo "  --remote, -r <host>  Deploy to remote host via SSH"
            echo "  MEDIA_BASE=<path>    Use specific path (default: /tmp/media-test-<timestamp>)"
            echo ""
            echo "Examples:"
            echo "  $0                           # Local setup with auto-generated path"
            echo "  $0 --remote pipeline-test    # Deploy to remote host"
            echo "  MEDIA_BASE=/tmp/mytest $0    # Local setup at specific path"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Generate unique test directory or use provided MEDIA_BASE
if [ -n "$MEDIA_BASE" ]; then
    TEST_MEDIA_BASE="$MEDIA_BASE"
else
    TIMESTAMP=$(date +%s)
    TEST_MEDIA_BASE="/tmp/media-test-$TIMESTAMP"
fi

# Remote deployment
if [ -n "$REMOTE_HOST" ]; then
    echo "Deploying test environment to $REMOTE_HOST:$TEST_MEDIA_BASE"
    echo ""

    # Create directory structure on remote
    ssh "$REMOTE_HOST" "mkdir -p '$TEST_MEDIA_BASE/pipeline/logs/jobs' \
        '$TEST_MEDIA_BASE/staging/1-ripped/movies' \
        '$TEST_MEDIA_BASE/staging/1-ripped/tv' \
        '$TEST_MEDIA_BASE/staging/2-remuxed/movies' \
        '$TEST_MEDIA_BASE/staging/2-remuxed/tv' \
        '$TEST_MEDIA_BASE/staging/3-transcoded/movies' \
        '$TEST_MEDIA_BASE/staging/3-transcoded/tv' \
        '$TEST_MEDIA_BASE/library/movies' \
        '$TEST_MEDIA_BASE/library/tv' \
        '$TEST_MEDIA_BASE/bin'"

    echo "Created directory structure"

    # Create config file on remote
    # shellcheck disable=SC2087 # Variables should expand locally before sending
    ssh "$REMOTE_HOST" "cat > '$TEST_MEDIA_BASE/pipeline/config.yaml'" << EOF
staging_base: $TEST_MEDIA_BASE/staging
library_base: $TEST_MEDIA_BASE/library

dispatch:
  rip: ""
  remux: ""
  transcode: ""
  publish: ""

remux:
  languages:
    - eng
    - bul

transcode:
  crf: 20
  mode: software
  preset: ultrafast
EOF

    echo "Created config"

    # Copy binaries to remote
    BINARIES="media-pipeline ripper remux transcode publish mock-makemkv"
    COPIED_BINS=""
    for bin in $BINARIES; do
        if [ -f "$PROJECT_ROOT/bin/$bin" ]; then
            scp -q "$PROJECT_ROOT/bin/$bin" "$REMOTE_HOST:$TEST_MEDIA_BASE/bin/"
            COPIED_BINS="$COPIED_BINS $bin"
        fi
    done

    if [ -n "$COPIED_BINS" ]; then
        echo "Copied binaries:$COPIED_BINS"
    fi

    echo ""
    echo "=========================================="
    echo "Test environment ready on $REMOTE_HOST!"
    echo "=========================================="
    echo ""
    echo "To run:"
    echo "  ssh $REMOTE_HOST 'MEDIA_BASE=$TEST_MEDIA_BASE MAKEMKVCON_PATH=$TEST_MEDIA_BASE/bin/mock-makemkv $TEST_MEDIA_BASE/bin/media-pipeline'"
    echo ""
    echo "Or connect and run:"
    echo "  ssh $REMOTE_HOST"
    echo "  export MEDIA_BASE=$TEST_MEDIA_BASE"
    echo "  export MAKEMKVCON_PATH=$TEST_MEDIA_BASE/bin/mock-makemkv"
    echo "  $TEST_MEDIA_BASE/bin/media-pipeline"
    echo ""
    echo "To clean up:"
    echo "  ssh $REMOTE_HOST 'rm -rf $TEST_MEDIA_BASE'"
    exit 0
fi

# Local deployment
echo "Setting up test environment at $TEST_MEDIA_BASE"
echo ""

# Create directory structure
mkdir -p "$TEST_MEDIA_BASE/pipeline/logs/jobs"
mkdir -p "$TEST_MEDIA_BASE/staging/1-ripped/movies"
mkdir -p "$TEST_MEDIA_BASE/staging/1-ripped/tv"
mkdir -p "$TEST_MEDIA_BASE/staging/2-remuxed/movies"
mkdir -p "$TEST_MEDIA_BASE/staging/2-remuxed/tv"
mkdir -p "$TEST_MEDIA_BASE/staging/3-transcoded/movies"
mkdir -p "$TEST_MEDIA_BASE/staging/3-transcoded/tv"
mkdir -p "$TEST_MEDIA_BASE/library/movies"
mkdir -p "$TEST_MEDIA_BASE/library/tv"
mkdir -p "$TEST_MEDIA_BASE/bin"

# Create config file
cat > "$TEST_MEDIA_BASE/pipeline/config.yaml" << EOF
staging_base: $TEST_MEDIA_BASE/staging
library_base: $TEST_MEDIA_BASE/library

dispatch:
  rip: ""
  remux: ""
  transcode: ""
  publish: ""

remux:
  languages:
    - eng
    - bul

transcode:
  crf: 20
  mode: software
  preset: ultrafast
EOF

echo "Created directory structure"
echo "Created config at $TEST_MEDIA_BASE/pipeline/config.yaml"

# Copy binaries if they exist
BINARIES="media-pipeline ripper remux transcode publish mock-makemkv"
COPIED_BINS=""
for bin in $BINARIES; do
    if [ -f "$PROJECT_ROOT/bin/$bin" ]; then
        cp "$PROJECT_ROOT/bin/$bin" "$TEST_MEDIA_BASE/bin/"
        COPIED_BINS="$COPIED_BINS $bin"
    fi
done

if [ -n "$COPIED_BINS" ]; then
    echo "Copied binaries:$COPIED_BINS"
fi

# Initialize database
DB_PATH="$TEST_MEDIA_BASE/pipeline/pipeline.db"
if [ -f "$TEST_MEDIA_BASE/bin/media-pipeline" ]; then
    # Use the TUI binary to initialize DB (it creates schema on startup)
    # For now just touch the file - the app will initialize it
    touch "$DB_PATH"
    echo "Created database at $DB_PATH"
fi

echo ""
echo "=========================================="
echo "Test environment ready!"
echo "=========================================="
echo ""
echo "To use:"
echo "  export MEDIA_BASE=$TEST_MEDIA_BASE"
echo "  export MAKEMKVCON_PATH=$TEST_MEDIA_BASE/bin/mock-makemkv"
echo "  $TEST_MEDIA_BASE/bin/media-pipeline"
echo ""
echo "Or run directly:"
echo "  MEDIA_BASE=$TEST_MEDIA_BASE MAKEMKVCON_PATH=$TEST_MEDIA_BASE/bin/mock-makemkv $TEST_MEDIA_BASE/bin/media-pipeline"
echo ""
echo "To clean up:"
echo "  rm -rf $TEST_MEDIA_BASE"
