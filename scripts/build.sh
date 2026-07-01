#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

usage() {
    cat <<EOF
BestFin Build Script

Usage:
    ./scripts/build.sh <platform> [backend_url]

Platforms:
    android     Build Android APK
    linux       Build Linux desktop app

Arguments:
    backend_url   Optional backend URL (default: http://10.0.2.2:28083 for Android,
                  http://127.0.0.1:28083 for Linux)

Examples:
    # Build Android with default URL
    ./scripts/build.sh android

    # Build Android with custom backend URL
    ./scripts/build.sh android http://192.168.1.100:28083

    # Build Linux with custom backend URL
    ./scripts/build.sh linux http://myserver.local:28083

Environment variables:
    BESTFIN_BACKEND_URL   Override backend URL (overrides positional argument)
EOF
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

PLATFORM="$1"
BACKEND_URL="${2:-}"

# Environment variable takes precedence
if [ -n "${BESTFIN_BACKEND_URL:-}" ]; then
    BACKEND_URL="$BESTFIN_BACKEND_URL"
fi

# Set default URLs per platform if not provided
if [ -z "$BACKEND_URL" ]; then
    case "$PLATFORM" in
        android)
            BACKEND_URL="http://10.0.2.2:28083"
            ;;
        linux)
            BACKEND_URL="http://127.0.0.1:28083"
            ;;
        *)
            echo "Error: default URL not known for platform '$PLATFORM'"
            usage
            ;;
    esac
fi

echo "Building BestFin for $PLATFORM"
echo "Backend URL: $BACKEND_URL"

cd "$PROJECT_DIR"

case "$PLATFORM" in
    android)
        nix develop -c flutter build apk --dart-define=BESTFIN_BACKEND_URL="$BACKEND_URL"
        ;;
    linux)
        nix develop -c flutter build linux --dart-define=BESTFIN_BACKEND_URL="$BACKEND_URL"
        ;;
    *)
        echo "Error: unknown platform '$PLATFORM'"
        usage
        ;;
esac

echo "Build complete!"
