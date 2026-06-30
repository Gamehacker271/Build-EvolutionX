#!/bin/bash

if [[ "$#" == '0' ]]; then
    echo 'ERROR: No File Specified!'
    exit 1
fi

FILE="$1"

# Temp Use -k (DNM)
SERVER=$(curl -ks https://api.gofile.io/servers | jq -r '.data.servers[0].name')

if [[ -z "$SERVER" || "$SERVER" == "null" ]]; then
    echo "ERROR: Could not get GoFile server"
    exit 1
fi

LINK=$(curl -ks -F "file=@$FILE" "https://${SERVER}.gofile.io/uploadFile" \
       | jq -r '.data.downloadPage')

if [[ -z "$LINK" || "$LINK" == "null" ]]; then
    echo "ERROR: Upload failed"
    exit 1
fi

echo "$LINK"
echo
