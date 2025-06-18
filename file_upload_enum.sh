#!/bin/bash

# Author: Kiran D
# Purpose: Comprehensive File Upload Vulnerability Enumerator
# Version: 1.0
# Use: ./file_upload_enum.sh <target_ip/domain> [optional_port]

TARGET=$1
PORT=${2:-80}
DATE=$(date +%F)
OUTPUT_DIR="results_${TARGET}_${DATE}"
mkdir -p "$OUTPUT_DIR"

echo "[*] Starting File Upload Vulnerability Scan on $TARGET:$PORT"
echo "[*] Results will be saved to $OUTPUT_DIR"

### Step 1: Nmap Script Scan for file upload
echo "[*] Running Nmap NSE scripts for HTTP file uploads..."
nmap -p $PORT --script http-fileupload-exploiter,http-put,http-enum -oN "$OUTPUT_DIR/nmap_fileupload.txt" $TARGET

### Step 2: Directory Bruteforce for common upload paths
echo "[*] Running directory brute force for upload endpoints..."

wordlists=(
    "/usr/share/wordlists/dirb/common.txt"
    "/usr/share/seclists/Discovery/Web-Content/common.txt"
    "/usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt"
)

for wl in "${wordlists[@]}"; do
    if [ -f "$wl" ]; then
        echo " -> Using wordlist: $wl"
        ffuf -u "http://$TARGET:$PORT/FUZZ" -w "$wl" -mc 200,201,204,403,401 -t 50 -o "$OUTPUT_DIR/ffuf_$(basename $wl).json" -of json
    fi
done

### Step 3: Upload Fuzzing (Custom curl-based)
echo "[*] Attempting file upload on discovered endpoints..."

PAYLOAD_FILE="$OUTPUT_DIR/payload_test.txt"
echo "<?php echo 'UploadTest-' . uniqid(); ?>" > "$PAYLOAD_FILE"

upload_paths=$(grep -r -i "upload" "$OUTPUT_DIR/" | grep -Eo "/[a-zA-Z0-9_/.-]*upload[a-zA-Z0-9_/.-]*" | sort -u)

for path in $upload_paths; do
    echo "[+] Trying upload to: http://$TARGET:$PORT$path"

    RESPONSE=$(curl -s -X POST -F "file=@$PAYLOAD_FILE" "http://$TARGET:$PORT$path")
    echo "$RESPONSE" | grep -i -E "success|uploaded|url|path" && echo "[!] Possible Upload Success at $path"
done

### Step 4: Look for accessible upload result
echo "[*] Checking for successful uploads..."
curl -s "http://$TARGET:$PORT/uploads/$(basename $PAYLOAD_FILE)" | grep -q "UploadTest" && echo "[!] File successfully uploaded and accessible!"

### Final Notes
echo "[*] Enumeration complete. Review results in $OUTPUT_DIR"
