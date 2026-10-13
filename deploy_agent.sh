#!/usr/bin/env bash

# Verify python3 and zip are installed
verify_dependencies() {
    local absent=0

    if ! command -v python3 >/dev/null 2>&1; then
        echo "Error: python3 isn't installed or is not in this PATH." >&2
        echo "  You can install it with: sudo apt install python3" >&2
        absent=1
    fi

    if ! command -v zip >/dev/null 2>&1; then
        echo "Error: zip isn't installed or is not in this PATH." >&2
        echo "  You can install it with: sudo apt install zip" >&2
        absent=1
    fi

    if (( absent )); then
        exit 1
    fi

    echo "Checks have passed: $(python3 --version)"
}

verify_dependencies
