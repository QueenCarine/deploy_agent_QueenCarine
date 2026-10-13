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

# Start menu
start_menu() {
    while true; do
        echo
        echo "Start Menu"
        echo "1) Deploy"
        echo "2) Run"
        echo "3) Archive"
        echo "4) Exit"

        read -rp "Choose one option from 1 to 4: " choice

        case "$choice" in
            1) echo "You selected Deploy." ;;
            2) echo "You selected Run." ;;
            3) echo "You selected Archive." ;;
            4) echo "Exiting."; exit 0 ;;
            *) echo "Invalid choice: '$choice'. Please enter a number between 1 and 4." >&2 ;;
        esac
    done
}

verify_dependencies
start_menu
