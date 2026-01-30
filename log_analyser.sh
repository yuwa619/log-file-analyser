#!/bin/bash
set -o pipefail

# --- 1. DYNAMIC PATH RESOLUTION ---
# This line finds the directory where the SCRIPT is saved, no matter where it's called from.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Now we reference the config file using that absolute path
CONFIG_FILE="$SCRIPT_DIR/log_analyser.conf"

# --- 2. LOGGING FUNCTION ---
# This helper function writes messages to both the Console and the Script Log.
# Format: [YYYY-MM-DD HH:MM:SS] [LEVEL] Message
log_msg() {
    local LEVEL="$1"
    local MSG="$2"
    local TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$TIMESTAMP] [$LEVEL] $MSG" | tee -a "$SCRIPT_LOG"
}

# --- 3. LOAD CONFIGURATION ---
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "CRITICAL: Configuration file not found." >&2
    exit 1
fi

# Ensure the log directory exists before trying to write to it
mkdir -p "$(dirname "$SCRIPT_LOG")"
mkdir -p "$OUTPUT_DIR"

# Validate critical variables
if [ -z "$LOG_DIR" ] || [ -z "$OUTPUT_DIR" ]; then
    log_msg "CRITICAL" "Config variables missing. Aborting."
    exit 1
fi

# Start the Log
log_msg "INFO" "Script started. Analyzing: $LOG_DIR"
REPORT_FILE="$OUTPUT_DIR/error_report_$(date +%Y%m%d).txt"

# --- 4. INITIALIZE REPORT ---
{
    echo "=================================================="
    echo "          PRODUCTION ERROR REPORT"
    echo "=================================================="
    echo "Generated: $(date)"
    echo "Scope:     $LOG_DIR"
    echo "=================================================="
    echo ""
} > "$REPORT_FILE"

# --- 5. THE MAIN LOOP ---
FILES_PROCESSED=0
ERRORS_ENCOUNTERED=0

# Check if directory actually exists
if [ ! -d "$LOG_DIR" ]; then
    log_msg "CRITICAL" "Source directory $LOG_DIR does not exist."
    exit 1
fi

# Iterate
for CURRENT_FILE in "$LOG_DIR"/*; do
    
    # EDGE CASE 1: Handle if the glob matches nothing (empty directory)
    [ -e "$CURRENT_FILE" ] || continue

    # Check: Is it a regular file?
    if [ -f "$CURRENT_FILE" ]; then
        
        # EDGE CASE 2: Permissions check
        if [ ! -r "$CURRENT_FILE" ]; then
            log_msg "WARN" "Permission denied: Skipping $CURRENT_FILE"
            ((ERRORS_ENCOUNTERED++))
            continue
        fi

        # EDGE CASE 3: Empty file check
        if [ ! -s "$CURRENT_FILE" ]; then
            log_msg "INFO" "File is empty: Skipping $CURRENT_FILE"
            continue
        fi

        # Check: Is it plain text?
        if file "$CURRENT_FILE" | grep -q "text"; then
            
            # log_msg "INFO" "Scanning $CURRENT_FILE..."
            
            # Using || true ensures the script doesn't crash if grep finds nothing
            if grep -q -E "$KEYWORDS" "$CURRENT_FILE" 2>/dev/null; then
                
                log_msg "INFO" "Found errors in $CURRENT_FILE. Appending to report."
                
                {
                    echo "--------------------------------------------------"
                    echo "SOURCE: $CURRENT_FILE"
                    echo "--------------------------------------------------"
                    echo "Count | Time Range (First - Last) | Error Fingerprint"
                    echo "--------------------------------------------------"
                    
                    grep -E "$KEYWORDS" "$CURRENT_FILE" | awk '
                    {
                        current_time = $1 " " $2 " " $3
                        fingerprint = $0
                        sub(/^.{16}/, "", fingerprint)
                        gsub(/\[[0-9]+\]/, "[#]", fingerprint)
                        
                        count[fingerprint]++
                        if (count[fingerprint] == 1) first_seen[fingerprint] = current_time
                        last_seen[fingerprint] = current_time
                    }
                    END {
                        for (msg in count) {
                            printf "%5d | [%s - %s] | %s\n", count[msg], first_seen[msg], last_seen[msg], msg
                        }
                    }
                    ' | sort -rn
                    echo "" 
                } >> "$REPORT_FILE"
                
            fi
            
            ((FILES_PROCESSED++))
            
        else
            # log_msg "DEBUG" "Skipping binary file: $CURRENT_FILE"
            : # No-op
        fi
    fi
done

# --- 6. COMPLETION & EXIT CODES ---

log_msg "INFO" "Analysis complete."
log_msg "INFO" "Files Processed: $FILES_PROCESSED"
log_msg "INFO" "Permission/Read Errors: $ERRORS_ENCOUNTERED"
log_msg "INFO" "Report saved to: $REPORT_FILE"

# Final Exit Logic
if [ "$ERRORS_ENCOUNTERED" -gt 0 ]; then
    log_msg "WARN" "Script completed with warnings."
    exit 2 # Exit 2 indicates "Completed but with some issues"
else
    log_msg "SUCCESS" "Script completed successfully."
    exit 0
fi
