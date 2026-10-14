# deploy_agent_QueenCarine

A shell script that bootstraps a Student Attendance Tracker project. It can deploy the app, run it, archive its logs, and clean up safely if you interrupt a deployment.

The Python application (`attendance_checker.py`) is **not modified**. Everything here is shell scripting around the provided files in `templates/`.

**Video walkthrough:** https://go.screenpal.com/watch/cO62odnyi3k

---

## Repository layout

```text
deploy_agent_QueenCarine/
├── deploy_agent.sh          # master script (Deploy / Run / Archive)
├── templates/               # unmodified source files
│   ├── attendance_checker.py
│   ├── assets.csv
│   └── config.json
├── .gitignore               # ignores attendance_tracker_*/ and *.zip
└── README.md
```

`deploy_agent.sh` never edits `templates/`. It copies files into a new project directory and changes only the copies.

---

## How to run

The script reads `templates/` using relative paths, so **run it from the repository root**:

```bash
chmod +x deploy_agent.sh
./deploy_agent.sh
```

At start-up it checks dependencies, then shows a menu:

```text
Start Menu
1) Deploy
2) Run
3) Archive
4) Exit
```

Type a number and press Enter. Invalid input prints an error and shows the menu again.

---

## Feature 1: Deploy (menu option 1)

### Pre-flight checks
Before the menu appears, `verify_dependencies` checks that `python3` and `zip` are installed. If either is missing, it prints an install hint (`sudo apt install ...`) and exits with status 1. Otherwise it prints the Python version.

### Project name
The script asks for a name and creates `attendance_tracker_<name>/`.
- The name must match `^[A-Za-z0-9_-]+$`. Empty names, spaces, slashes and special characters are rejected, so a name like `../x` cannot escape the current folder.
- If the directory already exists, the script asks `Overwrite? (y/n)`. Only `y` or `Y` continues (the old directory is removed first). Anything else aborts and returns to the menu. The signal trap is not armed yet at this point, so Ctrl+C here cannot delete a project you chose to keep.

### Structure created

```text
attendance_tracker_<name>/
├── attendance_checker.py     # copied from templates/
├── Helpers/
│   ├── assets.csv            # built from the roster option you choose
│   └── config.json           # copied from templates/, then adjusted
└── reports/                  # empty; the app writes its logs here
```

`archives/` is added later by the Archive feature.

### Roster: Option A or B
The script asks how to build `Helpers/assets.csv`:

- **A) Copy from the template.** Asks how many students (1 to 10) and copies the header plus that many rows from `templates/assets.csv` using `head`. These rows carry 4 prior sessions each.
- **B) Generate a fresh roster.** Asks how many students (1 to 10) and builds the rows in the script from a built-in array of 10 sample names, with emails `student1@example.com`, `student2@example.com`, and so on. Attendance and absence counts start at `0,0`.

The count must be a whole number of at least 1. Invalid input shows an error and asks again.

### `total_sessions` and the roster
`config.json` has a `total_sessions` value that must always equal the prior sessions in the roster plus today's session:

| Roster | Prior sessions | `total_sessions` |
|--------|----------------|------------------|
| Option A (template rows) | 4 | 5 (the value already in `templates/config.json`) |
| Option B (fresh roster) | 0 | 1 (the script rewrites it with `sed`) |

For Option B the script runs:

```bash
sed -i 's/"total_sessions": [0-9]\+/"total_sessions": 1/' "$dir/Helpers/config.json"
```

### Permissions
- `chmod +x` on `attendance_checker.py` (executable)
- `chmod 600` on `Helpers/config.json` (owner read/write only, since it holds the grading thresholds)

The script prints a confirmation line when both succeed.

### Threshold update (optional)
The script asks `Update attendance alert thresholds? (y/n)`. If `y`, it asks for:
- **warning** (default 75)
- **failure** (default 50)

Validation:
- Blank input keeps the default.
- Non-numeric or out-of-range input (below 1 or above 100) prints an error and keeps the default.
- `warning` must be greater than `failure`. If not, both reset to 75 / 50.

The values are written with `sed -i`, targeting only those two lines, so the file's formatting and key order are unchanged:

```bash
sed -i "s/\"warning\": [0-9]\+/\"warning\": $warning/" "$dir/Helpers/config.json"
sed -i "s/\"failure\": [0-9]\+/\"failure\": $failure/" "$dir/Helpers/config.json"
```

Only the deployed copy changes. `templates/config.json` is never touched.

### Verify the deployment
After setup, the trap is removed and the script calls `run_project "<name>"`. If the app starts, the structure, roster and config work together.

---

## Feature 2: Run (menu option 2)

Runs the app on an already deployed project.
1. Asks for the project name (when called from Deploy, it reuses the name and does not ask).
2. Checks that `attendance_tracker_<name>/` and `attendance_checker.py` exist. If not, it prints an error and returns to the menu.
3. Runs `( cd "$dir" && python3 attendance_checker.py )` in a subshell, so the script's own working directory does not change.

The app is interactive: it asks you to mark each student present or absent, updates `Helpers/assets.csv`, and writes `reports/attendance.log` and `reports/absent.log`.

**Note on repeated runs:** the app updates the roster counts each run, but `total_sessions` stays fixed from deploy time. After several runs on the same project the two can drift apart. Re-deploy for a fresh pair.

---

## Feature 3: Archive (menu option 3)

Asks for a project name, then moves each existing log into its own archive folder with a timestamp:

```text
attendance_tracker_<name>/
└── archives/
    ├── attendance/
    │   └── attendance_YYYYMMDD_HHMMSS.log
    └── absent/
        └── absent_YYYYMMDD_HHMMSS.log
```

How it works:
- Both archive folders are created with `mkdir -p`.
- One timestamp (`date +%Y%m%d_%H%M%S`) is taken per run, so both logs from the same archive share it.
- Logs are **moved** with `mv`, so `reports/` is empty afterwards and ready for the next run.
- The script prints the final path of each archived log.
- If a log does not exist (for example, nobody was absent, so there is no `absent.log`), it prints a message saying there is nothing to archive for that log and carries on without crashing. If neither log exists, it says there are no logs to archive and suggests running the app first.

Archiving is manual: run the app (option 2), then archive (option 3).

---

## Signal handling: Ctrl+C and Ctrl+Z during Deploy

During deployment the script sets:

```bash
trap handle_interrupt SIGINT SIGTSTP
```

On Ctrl+C (SIGINT) or Ctrl+Z (SIGTSTP), `handle_interrupt`:
1. Prints that the deployment was interrupted.
2. Zips whatever exists of the project into `attendance_tracker_<name>_archive.zip` with `zip -r`.
3. Deletes the incomplete `attendance_tracker_<name>/` directory.
4. Exits with status 130.

**When the trap is active:**
- It is armed right after the overwrite decision, once the script starts creating files.
- It is removed just before the verification run, so Ctrl+C during the marking session goes to the Python app and not to the deploy cleanup. The assignment says the trap is for the script, not for `attendance_checker.py`.

Note: Ctrl+Z normally suspends a program. During deployment this script deliberately treats it the same as Ctrl+C.

### What the `.zip` contains
The partial project exactly as it was at the moment of interruption. For example, an interrupt at the threshold prompt gives:

```text
attendance_tracker_<name>/
├── attendance_checker.py
├── Helpers/
│   ├── assets.csv
│   └── config.json
└── reports/
```

### How to test it
1. Run `./deploy_agent.sh`, choose `1`, and use the name `trap_test`.
2. At any prompt after the overwrite step (for example the roster or threshold prompt), press **Ctrl+C**. Repeat with **Ctrl+Z**.
3. Check the result:

```bash
ls attendance_tracker_trap_test_archive.zip      # exists
ls -d attendance_tracker_trap_test               # No such file or directory
unzip -l attendance_tracker_trap_test_archive.zip
```

Other checks:
- **Overwrite is safe:** deploy a project, deploy the same name again and answer `n`. The folder must still exist and no `.zip` must be created.
- **Trap is off during marking:** deploy fully, and press Ctrl+C while the Python app is waiting for input. No `.zip` should appear and the project folder should remain.

---

## How the deployment was tested

Tick off or delete each item so this list only contains what you actually ran.

- [ ] **Structure:** deployed with both roster options and checked the tree with `find attendance_tracker_<name> -type d` and `-type f`.
- [ ] **Roster:** `wc -l Helpers/assets.csv` shows header + N rows.
- [ ] **`total_sessions`:** `grep total_sessions Helpers/config.json` gives 5 for Option A and 1 for Option B.
- [ ] **Permissions:** `ls -l Helpers/config.json` shows `-rw-------`, and `attendance_checker.py` is executable.
- [ ] **Thresholds:** tried valid values, blank, non-numeric (`abc`), out of range (`101`), and warning ≤ failure; checked `config.json` each time.
- [ ] **Roster input:** tried `0`, `11`, `abc` and blank.
- [ ] **Overwrite prompt:** answered `y` and `n`.
- [ ] **Verify-run and standalone Run:** marked a few students and exited.
- [ ] **Archive:** ran the app, archived, and confirmed both logs moved with a shared timestamp and `reports/` was empty.
- [ ] **Archive with a missing log:** archived after a run where everyone was present, and after no run at all.
- [ ] **Signals:** Ctrl+C and Ctrl+Z during deploy, as described above.

---

## Known limitations

- **Run from the repository root.** `templates/` is referenced by relative path, so running the script from another folder fails.
- **Leading zeros in numbers.** Input such as `08` passes the digit check but Bash reads it as octal, so the roster and threshold checks can error. Enter numbers without a leading zero.
- **Failed deploy steps.** If a command fails after the project folder is created (for example a `cp` or `chmod` error), the script prints an error and returns to the menu, but the partial folder stays and the interrupt trap remains active until the next successful deploy. Delete the folder manually before retrying.
- **Option A and `total_sessions`.** The script relies on `templates/config.json` already containing `5`. It does not rewrite the value for Option A.
- **Roster size** is capped at 10 for both options (Option A by the template, Option B by the built-in names array).
- **Interrupt cleanup is destructive by design:** the partial directory is deleted after it is archived, as the assignment requires.

---

## Author

Queen Carine, [github.com/QueenCarine](https://github.com/QueenCarine)