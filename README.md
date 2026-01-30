 all Linux systems).
* **Utilities:** `grep`, `awk`, `sort`, `uniq`, `file` (Standard core utilities).
* **Permissions:** The user running the script needs **Read** permissions for the log files (usually `/var/log` requires `sudo` or root) and **Write** permissions for the report output directory.

## Setup

1. **Create a directory** for your scripts:
```bash
mkdir -p ~/scripts/log-analyzer
cd ~/scripts/log-analyzer

```


2. **Save the files:**
* Save the main script logic as `log_analyzer.sh`.
* Save the configuration variables as `log_analyzer.conf`.


3. **Make the script executable:**
```bash
chmod +x log_analyzer.sh

```


4. **Verify the directory structure:**
Ensure both files are in the same folder. The script is designed to automatically locate the
# Log File Analyzer

## What This Does

This tool automates the tedious task of monitoring Linux system logs. Instead of manually running `grep` commands or scrolling through thousands of lines of text, this script scans your target log directories (like `/var/log`) for specific keywords (e.g., "Error", "Failed", "Critical"). It intelligently "deduplicates" the results—meaning if an error occurs 500 times in a row, the report will show a single line with a count of 500, rather than flooding you with noise. It generates a clean, readable summary report and logs its own execution history for auditing purposes.

## Requirements

* **Operating System:** A Linux or Unix-like system (Ubuntu, Debian, CentOS, RHEL, etc.).
* **Shell:** Bash (Standard on almost config file relative to itself.

## Configuration

All settings are stored in `log_analyzer.conf`. You do **not** need to edit the main script.

* **`LOG_DIR`**: The folder to scan (Default: `/var/log`).
* **`OUTPUT_DIR`**: Where to save the final text reports (Default: `~/reports`).
* **`SCRIPT_LOG`**: Where the script records its own success/failure history.
* **`KEYWORDS`**: A pipe-separated list of regex patterns to search for.
* *Default:* `"error|fail|critical|FAILED|ERROR|CRITICAL"`
* *Tip:* You can add application-specific codes here, e.g., `"error|fail|502 Bad Gateway"`.



## Running the Script

To run the analysis manually:

```bash
# If checking system logs, you usually need sudo
sudo ./log_analyzer.sh

```

If you are scanning logs owned by your current user (e.g., application logs), `sudo` is not required.

## Testing

To verify the setup without waiting for a real error:

1. **Run the script manually:**
```bash
./log_analyzer.sh

```


2. **Check the Execution Log:**
```bash
cat ~/reports/script_execution.log

```


*Success:* You should see `[INFO] Script started` followed by `[SUCCESS] Script completed successfully`.
3. **Check the Report:**
Navigate to your `OUTPUT_DIR` and open the generated text file (e.g., `error_report_20251120.txt`).

## Cron Setup

To automate this to run every morning at 06:00:

1. Open your crontab:
```bash
sudo crontab -e

```


2. Add the following line (adjust paths to match your actual setup):
```cron
0 6 * * * /home/vagrant/scripts/log-analyzer/log_analyzer.sh > /dev/null 2>&1

```



*Note: The script uses internal logging (`script_execution.log`), so we discard standard Cron emails using `> /dev/null 2>&1`.*

## Security Notes

* **Read Access:** This script parses sensitive system logs. Ensure only authorised users have access to the script and the generated reports.
* **Write Access:** The script writes to disk. Ensure the `OUTPUT_DIR` has valid permissions for the user running the Cron job.
* **Execution:** Avoid running scripts blindly as root unless necessary. If possible, create a dedicated `log_audit` group with read-only access to `/var/log`.

## Known Limitations

* **Plain Text Only:** The script intentionally skips binary files (like `.gz` archives or `wtmp`) to prevent corruption. It does not unzip old logs.
* **Fingerprinting:** The deduplication logic relies on standard timestamp formats (removing the first 16 chars). If a log file uses a non-standard timestamp format, lines might not dedup perfectly.
* **Single Host:** This is designed for single-server analysis. It does not aggregate logs from multiple servers across a network.

## Sample Output

The final report (`error_report_YYYYMMDD.txt`) will look like this:

```text
==================================================
          PRODUCTION ERROR REPORT
==================================================
Generated:  Thu Nov 20 06:00:01 UTC 2025
Scope:      /var/log
==================================================

--------------------------------------------------
SOURCE: /var/log/syslog
--------------------------------------------------
Count | Time Range (First - Last) | Error Fingerprint
--------------------------------------------------
  500 | [Nov 19 08:00 - Nov 19 23:59]   | server-01 sshd[#]: Failed password for invalid user
   12 | [Nov 19 10:15 - Nov 19 10:20]   | server-01 kernel: [   12.34] Network unreachable
    3 | [Nov 19 14:00 - Nov 19 14:01]   | server-01 nginx[#]: [error] 123#123: *1 connect() failed

--------------------------------------------------
SOURCE: /var/log/auth.log
--------------------------------------------------
Count | Time Range (First - Last) | Error Fingerprint
--------------------------------------------------
   42 | [Nov 19 09:00 - Nov 19 09:15]   | sudo: pam_unix(sudo:auth): authentication failure;

```

