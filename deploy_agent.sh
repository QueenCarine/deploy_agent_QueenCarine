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
            1) project_deployment ;;
            2) echo "You selected Run." ;;
            3) echo "You selected Archive." ;;
            4) echo "Exiting."; exit 0 ;;
            *) echo "Invalid choice: '$choice'. Please enter a number between 1 and 4." >&2 ;;
        esac
    done
}

# Project Deployment
project_deployment() {
    read -rp "Enter your project name: " name

    if [[ -z "$name" ]]; then
        echo "Error: project has to have a name." >&2
        return 1
    fi

    if [[ ! "$name" =~ ^[A-Za-z0-9_-]+$ ]]; then
        echo "Error: project name can only contain letters, numbers, '_' and '-'." >&2
        echo "       Received: '$name'" >&2
        return 1
    fi


    local dir="attendance_tracker_${name}"

    if [[ -d "$dir" ]]; then
        read -rp "Directory '$dir' already exists. Overwrite? (y/n): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            rm -rf -- "$dir"
        else
            echo "Aborted: '$dir' has not been overwritten. Returning to the start menu." >&2
            return 1
        fi
    fi

    mkdir -p "$dir/Helpers" "$dir/reports" || { echo "Error: could not create '$dir'. Check permission rights to this folder." >&2; return 1; }
    echo "Created folders in $dir"
    cp templates/attendance_checker.py "$dir/" || { echo "Error: could not copy 'attendance_checker.py' into '$dir/'." >&2; return 1; }
    cp templates/config.json "$dir/Helpers/" || { echo "Error: could not copy 'config.json' into '$dir/Helpers/'." >&2; return 1; }

    # Roster
     local names=(
        "Alice Johnson" "Bob Smith" "Charlie Davis" "Diana Prince" "Ethan Cole"
        "Fatima Noor" "George Mensah" "Hannah Kim" "Ibrahim Osei" "Jasmine Lee"
    )
    while true; do
        echo
        echo "How would you like to set up your roster?"
        echo "  A) Copy from the template"
        echo "  B) Generate a fresh roster"

        read -rp "Choose an option [A/B]: " r_choice

        case "$r_choice" in
                        A|a)
                read -rp "How many students to copy? " n

                if [[ ! "$n" =~ ^[0-9]+$ ]] || (( n < 1 )); then
                    echo "Error: Please enter a number equal to or greater than 1." >&2
                    continue
                fi

                if (( n > 10 )); then
                    echo "Error: You can only copy up to 10 students from the template. Please enter 1-10." >&2
                    continue
                fi

                head -n $(( n + 1 )) templates/assets.csv > "$dir/Helpers/assets.csv" \
                    || { echo "Error: could not write roster to '$dir/Helpers/assets.csv'." >&2; return 1; }

                echo "Copied $n student(s) from the template into '$dir/Helpers/assets.csv'."
                break
                ;;
                        B|b)
                read -rp "How many students do you want to generate? " n

                if [[ ! "$n" =~ ^[0-9]+$ ]] || (( n < 1 )); then
                    echo "Error: Please enter a number equal to or greater than 1." >&2
                    continue
                fi

                if (( n > ${#names[@]} )); then
                    echo "Error: You can only generate up to ${#names[@]} students. Please enter 1-${#names[@]}." >&2
                    continue
                fi

                {
                    echo "Email,Names,Attendance Count,Absence Count"
                    for (( i=0; i<n; i++ )); do
                        echo "student$(( i + 1 ))@example.com,${names[$i]},0,0"
                    done
                } > "$dir/Helpers/assets.csv" \
                    || { echo "Error: could not write roster to '$dir/Helpers/assets.csv'." >&2; return 1; }

                echo "Generated $n student(s) into '$dir/Helpers/assets.csv'."
                sed -i 's/"total_sessions": [0-9]\+/"total_sessions": 1/' "$dir/Helpers/config.json" \
                    || { echo "Error: could not update total_sessions in config.json." >&2; return 1; }
                break
                ;;
            *)   echo "Invalid choice: '$r_choice'. Please choose between A or B." >&2 ;;
        esac
    done
        chmod +x "$dir/attendance_checker.py" \
        || { echo "Error:'attendance_checker.py' could not be executable." >&2; return 1; }

    chmod 600 "$dir/Helpers/config.json" \
        || { echo "Error: Not able to restrict permissions on 'config.json'." >&2; return 1; }

    echo "Permissions set: attendance_checker.py (executable), Helpers/config.json (600)."

    #Thresholds
    read -rp "Update attendance alert thresholds? (y/n): " update

    if [[ "$update" == "y" || "$update" == "Y" ]]; then
        read -rp "Threshold for warnings (default 75): " warning
        if [[ -z "$warning" ]]; then
            warning=75
        elif [[ ! "$warning" =~ ^[0-9]+$ ]] || (( warning < 1 || warning > 100 )); then
            echo "Error: warning threshold must be a number between 1 and 100. Will keep default 75." >&2
            warning=75
        fi

        read -rp "Threshold for failures (default 50): " failure
        if [[ -z "$failure" ]]; then
            failure=50
        elif [[ ! "$failure" =~ ^[0-9]+$ ]] || (( failure < 1 || failure > 100 )); then
            echo "Error: failure threshold must be a number between 1 and 100. Will keep default 50." >&2
            failure=50
        fi

        if (( warning <= failure )); then
            echo "Error: warning ($warning) has to be greater than failure ($failure). Will keep defaults (75 / 50)." >&2
            warning=75
            failure=50
        fi

        sed -i "s/\"warning\": [0-9]\+/\"warning\": $warning/" "$dir/Helpers/config.json" \
            || { echo "Error: could not update warning threshold." >&2; return 1; }
        sed -i "s/\"failure\": [0-9]\+/\"failure\": $failure/" "$dir/Helpers/config.json" \
            || { echo "Error: could not update failure threshold." >&2; return 1; }

        echo "Thresholds updated: warning=$warning, failure=$failure."
    else
        echo "Keeping default thresholds (warning=75, failure=50)."
    fi

    echo "Deployment complete: $dir is ready."
}

verify_dependencies
start_menu