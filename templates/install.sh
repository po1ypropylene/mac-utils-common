#!/bin/zsh
set -euo pipefail

# Adapt these values before copying this file into the target repo's scripts/.
readonly utilityName="ExampleUtility"
readonly projectName="ExampleUtility"
readonly schemeName="ExampleUtility"
readonly serviceLabel="com.example.ExampleUtility"
# Add the utility's continuous-service defaults here, each argument separately.
readonly -a defaultArguments=()
readonly projectDirectory="$(cd "$(dirname "$0")/.." && pwd)"
readonly buildDirectory="$projectDirectory/build"
readonly installationDirectory="$HOME/Library/Application Support/${utilityName}"
readonly executableDestination="$installationDirectory/${utilityName}"
readonly launchAgentPath="$HOME/Library/LaunchAgents/$serviceLabel.plist"
readonly logDirectory="$HOME/Library/Logs/${utilityName}"
readonly serviceDomain="gui/$(id -u)"

readonly executableSource="$buildDirectory/Build/Products/Release/$utilityName"

# Adapt this list to the utility's actual one-shot modes.
for argument in "$@"; do
    if [[ "$argument" == --once || "$argument" == --help ]]; then
        echo "$argument is for foreground use, not a continuously running service." >&2
        exit 64
    fi
done
if (( $# == 0 )); then
    set -- "${defaultArguments[@]}"
fi

echo "Building $utilityName..."
xcodebuild \
    -project "$projectDirectory/$projectName.xcodeproj" \
    -scheme "$schemeName" \
    -configuration Release \
    -derivedDataPath "$buildDirectory" \
    build
if [[ ! -f "$executableSource" || ! -x "$executableSource" ]]; then
    echo "Executable not found or not executable: $executableSource" >&2
    exit 66
fi

mkdir -p "$installationDirectory" "$HOME/Library/LaunchAgents" "$logDirectory"
# Prepare and validate the new plist before stopping an existing service.
temporaryPlist="$(mktemp "$HOME/Library/LaunchAgents/.${utilityName}.XXXXXX")"
trap 'rm -f "$temporaryPlist"' EXIT
plutil -create xml1 "$temporaryPlist"
plutil -insert Label -string "$serviceLabel" "$temporaryPlist"
plutil -insert ProgramArguments -xml '<array/>' "$temporaryPlist"
plutil -insert ProgramArguments.0 -string "$executableDestination" "$temporaryPlist"
argumentIndex=1
for argument in "$@"; do
    plutil -insert "ProgramArguments.$argumentIndex" -string "$argument" "$temporaryPlist"
    argumentIndex=$((argumentIndex + 1))
done
plutil -insert RunAtLoad -bool true "$temporaryPlist"
plutil -insert KeepAlive -bool true "$temporaryPlist"
plutil -insert StandardOutPath -string "$logDirectory/output.log" "$temporaryPlist"
plutil -insert StandardErrorPath -string "$logDirectory/error.log" "$temporaryPlist"
plutil -lint "$temporaryPlist"

# An unloaded job is normal on first installation. Surface errors for loaded jobs.
if launchctl print "$serviceDomain/$serviceLabel" >/dev/null 2>&1; then
    launchctl bootout "$serviceDomain/$serviceLabel"
fi
install -m 755 "$executableSource" "$executableDestination"
mv -f "$temporaryPlist" "$launchAgentPath"
# If migrating an existing utility, remove only its verified legacy files here.
launchctl enable "$serviceDomain/$serviceLabel"
launchctl bootstrap "$serviceDomain" "$launchAgentPath"
launchctl kickstart -k "$serviceDomain/$serviceLabel"

echo "${utilityName} is installed and will start whenever you log in."
echo "Executable: $executableDestination"
echo "Status: launchctl print $serviceDomain/$serviceLabel"
echo "Logs: $logDirectory"
