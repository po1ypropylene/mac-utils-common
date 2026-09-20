# Instructions for agents: macOS background command-line services

Use these instructions when building or reorganizing a small macOS command-line
utility that should run continuously in a logged-in user's session. The pattern
uses an Xcode command-line target, a Release build, a stable installed executable,
a per-user LaunchAgent, and simple install/uninstall scripts. These instructions
are self-contained and do not require access to another utility's repository.

Examples use the fictional name `ExampleUtility` and service label
`com.example.ExampleUtility`. Replace both with the target project's name and
unique service label throughout its scripts and documentation.
Read the target repository's instructions first and adapt names and requirements
to that project. A reference repository is read-only unless the user authorizes
changes to it.

## Repository and build conventions

- Keep application source separate from lifecycle scripts. Provide executable
  `scripts/install.sh` and `scripts/uninstall.sh`, a root README, and an ignored
  `build/` directory. Commit a shared Xcode scheme for command-line builds.
- Make installation one command from a fresh checkout: `./scripts/install.sh`.
  Resolve the repository root relative to the script, so invocation also works
  from another directory. Use strict shell error handling and quote paths.
- Build Release with an explicit local DerivedData path. For the example utility:

  ```sh
  xcodebuild \
    -project "$projectDirectory/ExampleUtility.xcodeproj" \
    -scheme ExampleUtility \
    -configuration Release \
    -derivedDataPath "$projectDirectory/build" \
    build
  ```

  The result is `build/Build/Products/Release/ExampleUtility`. Do not ask users
  to find a hashed global DerivedData directory. Keep routine polling logs quiet
  in Release while retaining useful startup and failure diagnostics.

## Installation contract

1. Choose a stable service label and paths. For example:

   | Item | Example |
   | --- | --- |
   | Label | `com.example.ExampleUtility` |
   | Executable | `~/Library/Application Support/ExampleUtility/ExampleUtility` |
   | LaunchAgent | `~/Library/LaunchAgents/com.example.ExampleUtility.plist` |
   | Standard output | `~/Library/Logs/ExampleUtility/output.log` |
   | Standard error | `~/Library/Logs/ExampleUtility/error.log` |

   Preserve an existing label when reorganizing a project unless a migration
   requires changing it. Replace the example identity consistently for each new service.
2. Build and check the executable before stopping the installed service. Prepare
   and lint a replacement plist before unloading the old job. A failed build
   must leave the installed service running.
3. Create the application, LaunchAgents, and log directories. Use absolute paths
   in the plist: launchd does not expand `~`, shell variables, or shell syntax.
4. Include `Label`, a `ProgramArguments` array containing the executable and each
   argument as a separate string, `RunAtLoad`, `KeepAlive`, `StandardOutPath`, and
   `StandardErrorPath`. Generate strings with a plist-aware tool, such as
   `plutil -insert ... -string`, rather than interpolating unescaped XML. Verify
   with `plutil -lint`. Spaces, ampersands, and quotes must survive unchanged.
5. Use `RunAtLoad=true` and `KeepAlive=true` for a continuous utility. Reject
   one-shot/help modes in the service installer; otherwise launchd will repeatedly
   restart them. Consider exit behavior and logging when required hardware or
   permissions are missing. Set `ProcessType=Interactive` only when appropriate
   for latency-sensitive work such as input-event processing; do not apply it
   automatically to every background utility.
6. Stop the old job with `launchctl bootout "$serviceDomain/$serviceLabel"`
   before replacing the installed binary. An absent job is normal on first
   install. Install the executable with mode 755 and replace the plist. Enable
   the job, bootstrap it into `gui/$(id -u)`, then kickstart it. Surface build,
   copy, plist, and startup errors; do not suppress failures indiscriminately.
7. Re-running the installer is the update path. Document whether supplied runtime
   arguments are preserved or reset. Migrate known old executable/plist locations
   so only one service remains. Retain logs unless deletion was requested.

Use a per-user LaunchAgent for hardware/UI utilities tied to a graphical login.
Do not use `sudo`, a system LaunchDaemon, or shell-profile startup for this case.
If the requirement is to run before login or with system privileges, reassess the
architecture instead of blindly applying this pattern.

## Lifecycle commands and README

Document requirements, build output, one-command installation, any permissions,
status, stop, start, restart, logs, update, uninstall, and foreground diagnosis.
Give copyable commands with the actual project label and paths. Using the
placeholder label, the lifecycle commands are:

```sh
# Status
launchctl print "gui/$(id -u)/com.example.ExampleUtility"

# Stop/unload until next login or an explicit start
launchctl bootout "gui/$(id -u)/com.example.ExampleUtility"

# Start an unloaded service
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.example.ExampleUtility.plist"

# Restart a loaded service
launchctl kickstart -k "gui/$(id -u)/com.example.ExampleUtility"
```

A termination signal alone is not a reliable stop with
`KeepAlive=true`: launchd can restart the process. After `bootout`, use `bootstrap`
to start; `kickstart` requires a loaded job. Leaving the plist installed allows
loading again on the next login. For permanent removal, use the uninstaller.

The uninstaller should unload the job, remove only its known executable and
plist (including documented legacy locations), and remove the application
folder only if empty. Repeated uninstall should succeed. Keep logs and unrelated
files. State clearly that logs remain.

Document only permissions the application actually requires. If a utility needs
Accessibility permission, direct users to add or enable the installed executable
under **System Settings > Privacy & Security > Accessibility**. Permission granted to a development build
may not apply to the installed copy; signing changes can require renewed approval.
Do not automatically claim that every background utility needs Accessibility.

## Verification before delivery

- Check shell syntax, executable script modes, and README paths against the
  implementation. Build Release using the exact documented command.
- Exercise install, reinstall, custom arguments, uninstall, and repeated uninstall
  in an isolated fixture with service commands stubbed. Include a failed-build
  case, migration from old locations, and paths containing spaces/XML characters.
  Check generated plist values and lifecycle ordering, not just exit codes.
- Do not replace or start the user's actual background service merely to test a
  repository reorganization. If live installation is authorized, verify status,
  logs, stop/start/restart, and the application's real behavior in a logged-in
  session. Distinguish fixture verification from live service verification.
- Inspect the final diff and confirm any read-only reference repository remains
  unchanged. Report what changed, what was verified, and any unverified hardware
  or login behavior.

For future tasks, ask the agent to read this document and apply the conventions
to the target repository. Adapt the example identifiers, arguments, permissions,
and migration behavior to the actual utility. No external reference repository
is required.
