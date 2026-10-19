#!/bin/sh
# Inject the public application ID into the built plist without committing it.
set -eu
env_file="$SRCROOT/../.env"
plist="$TARGET_BUILD_DIR/$INFOPLIST_PATH"
if [ ! -f "$env_file" ]; then exit 0; fi
app_id=$(/usr/bin/awk -F= '
  /^[[:space:]]*ADMOB_IOS_APP_ID[[:space:]]*=/ {
    sub(/^[^=]*=/, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, "");
    gsub(/^"|"$/, ""); gsub(/^\047|\047$/, ""); print; exit
  }' "$env_file")
if [ -n "$app_id" ]; then
  if ! printf '%s\n' "$app_id" | /usr/bin/grep -Eq '^ca-app-pub-[0-9]{16}~[0-9]{10}$'; then
    echo 'error: Invalid ADMOB_IOS_APP_ID in .env' >&2
    exit 1
  fi
  /usr/libexec/PlistBuddy -c "Set :GADApplicationIdentifier $app_id" "$plist" 2>/dev/null ||
    /usr/libexec/PlistBuddy -c "Add :GADApplicationIdentifier string $app_id" "$plist"
else
  # Clear a previously built ID if configuration was removed between builds.
  /usr/libexec/PlistBuddy -c 'Delete :GADApplicationIdentifier' "$plist" 2>/dev/null || true
fi
