#!/bin/bash

# SYNOPSIS
# This script is used to install the NinjaOne agent. Supports generic installer or generated URL.

# DESCRIPTION
# This script is used to install the NinjaOne agent. Supports generic installer or generated URL.

write_log_entry() {
    local message="$1"
    local log_path="/tmp/NinjaOneInstall.log"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    if [[ -z "$message" ]]; then
        message="Usage: write_log_entry 'You must supply a message when calling this function.'"
    fi

    # Append the log entry to the file and print it to the console
    echo "$timestamp - $message" >> "$log_path"
    echo "$timestamp - $message"
}

# Adjust URL to the MacOS generated URL and leave Token blank
URL=''
# If using generic installer URL, a token must be provided
Token=''
Folder='/tmp'
Filename=$(basename "$URL")
CheckApp='/Applications/NinjaRMMAgent'

if [[ $EUID -ne 0 ]]; then
    write_log_entry "This script must be run as root. Try running it with sudo or as the system/root user."
    exit 1
fi

if [[ -z "$URL" ]]; then
    write_log_entry 'Please provide a URL. Exiting.'
    exit 1
fi

write_log_entry 'Performing checks...'

if [[ -d "$CheckApp" ]]; then
    write_log_entry 'NinjaOne agent already installed. Please remove before installing.'
    exit 0
fi

if [[ "$Filename" != *.pkg ]]; then
    write_log_entry 'Only PKG files are supported in this script. Cannot continue.'
    exit 1
fi

if [[ "$Filename" == 'NinjaOneAgent.pkg' ]]; then
    if [[ -z "$Token" ]]; then
        write_log_entry 'A generic install URL was provided with no token. Please provide a token to use the generic installer. Exiting.'
        exit 1
    fi

    if [[ ! $Token =~ ^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$ ]]; then
        write_log_entry 'An invalid token was provided. Please ensure it was entered correctly.'
        exit 1
    fi

    write_log_entry 'Token provided and generic installer being used. Continuing...'
    echo "$Token" > "$Folder/.~"
else
    if [[ -n "$Token" ]]; then
        write_log_entry 'A token was provided, but the URL appears to be for a generated installer and not the generic installer.'
        write_log_entry 'Script will not continue. Please use either a generic installer URL, or remove the token. You cannot use both.'
        exit 1
    fi
fi

write_log_entry 'Downloading installer...'

if ! curl -fSL "$URL" -o "$Folder/$Filename"; then
    write_log_entry 'Download failed. Exiting Script.'
    exit 1
fi

if [[ ! -s "$Folder/$Filename" ]]; then
    write_log_entry 'Downloaded an empty file. Exiting.'
    exit 1
fi

if ! pkgutil --check-signature "$Folder/$Filename" | grep -q "NinjaRMM LLC"; then
    write_log_entry 'PKG file is not signed by NinjaOne. Cannot continue.'
    rm -f "$Folder/$Filename"
    exit 1
fi

write_log_entry 'Download successful. Beginning installation...'

if ! installer -pkg "$Folder/$Filename" -target /; then
    write_log_entry 'Installer command failed. Exiting.'
    rm -f "$Folder/$Filename"
    exit 1
fi

# Give the installer a moment to complete
sleep 5

if [[ ! -d "$CheckApp" ]]; then
    write_log_entry 'Failed to install the NinjaOne Agent. Exiting.'
    rm -f "$Folder/$Filename"
    exit 1
fi

write_log_entry 'Successfully installed NinjaOne!'
rm -f "$Folder/$Filename"
exit 0