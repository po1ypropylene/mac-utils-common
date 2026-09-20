#!/bin/zsh
set -euo pipefail

# Keep these values identical to those in install.sh.
readonly utilityName="ExampleUtility"
readonly serviceLabel="com.example.ExampleUtility"
readonly installationDirectory="$HOME/Library/Application Support/$utilityName"
readonly launchAgentPath="$HOME/Library/LaunchAgents/$serviceLabel.plist"
readonly serviceDomain="gui/$(id -u)"

if launchctl print "$serviceDomain/$serviceLabel" >/dev/null 2>&1; then
    launchctl bootout "$serviceDomain/$serviceLabel"
fi
rm -f "$launchAgentPath"
rm -f "$installationDirectory/$utilityName"
# If migrating an existing utility, remove only its verified legacy files here.
rmdir "$installationDirectory" 2>/dev/null || true

echo "$utilityName has been uninstalled."
echo "Logs remain in $HOME/Library/Logs/$utilityName."
