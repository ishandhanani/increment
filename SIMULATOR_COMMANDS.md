# iOS Simulator Commands & Log Viewing

## Quick Reference: Simulator Commands

### List Available Simulators
```bash
xcrun simctl list devices available | grep -E "iPhone|iPad"
```

### Boot a Simulator
```bash
xcrun simctl boot "iPhone 17"
```

### Open Simulator App
```bash
open -a Simulator
```

### Shutdown a Simulator
```bash
xcrun simctl shutdown "iPhone 17"
# Or shutdown all:
xcrun simctl shutdown all
```

### Erase/Reset a Simulator
```bash
xcrun simctl erase "iPhone 17"
# Or erase all:
xcrun simctl erase all
```

### Install App on Simulator
```bash
xcrun simctl install "iPhone 17" /path/to/YourApp.app
```

### Launch App
```bash
xcrun simctl launch "iPhone 17" com.increment.app
```

### Terminate App
```bash
xcrun simctl terminate "iPhone 17" com.increment.app
```

### Uninstall App
```bash
xcrun simctl uninstall "iPhone 17" com.increment.app
```

## Building & Running the App

### Build and Run (One Command)
From the project root:
```bash
cd /Users/ishandhanani/Desktop/increment/.conductor/indianapolis/increment/IncrementProject

xcodebuild -workspace Increment.xcworkspace \
  -scheme Increment \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

### Clean Build Folder
```bash
xcodebuild -workspace Increment.xcworkspace \
  -scheme Increment \
  clean
```

## Viewing Logs in Real-Time

### Method 1: Using `log stream` (Best for Real-Time)

**Filter by subsystem (all Increment logs):**
```bash
xcrun simctl spawn booted log stream --level debug --predicate 'subsystem == "com.increment.app"'
```

**Filter by specific category:**
```bash
# Session logs only
xcrun simctl spawn booted log stream --level debug \
  --predicate 'subsystem == "com.increment.app" && category == "session"'

# Live Activity logs only
xcrun simctl spawn booted log stream --level debug \
  --predicate 'subsystem == "com.increment.app" && category == "liveActivity"'

# Notifications logs only
xcrun simctl spawn booted log stream --level debug \
  --predicate 'subsystem == "com.increment.app" && category == "notifications"'
```

**Filter by log level (errors only):**
```bash
xcrun simctl spawn booted log stream --level error \
  --predicate 'subsystem == "com.increment.app"'
```

**Save logs to file:**
```bash
xcrun simctl spawn booted log stream --level debug \
  --predicate 'subsystem == "com.increment.app"' > increment_logs.txt
```

### Method 2: Using Console.app (GUI)

1. Open **Console.app** (built into macOS)
2. Select your simulator from the left sidebar (e.g., "iPhone 17")
3. In the search bar, enter: `subsystem:com.increment.app`
4. Click "Start streaming" button
5. Interact with your app - logs appear in real-time

**Useful filters in Console.app:**
- `subsystem:com.increment.app` - All app logs
- `subsystem:com.increment.app category:session` - Session logs only
- `subsystem:com.increment.app AND level:error` - Errors only
- `subsystem:com.increment.app AND "workout"` - Search for keyword

### Method 3: Historical Logs (After the Fact)

**Show logs from last run:**
```bash
xcrun simctl spawn booted log show --predicate 'subsystem == "com.increment.app"' \
  --info --debug --last 5m
```

**Show logs from specific time range:**
```bash
xcrun simctl spawn booted log show --predicate 'subsystem == "com.increment.app"' \
  --start "2025-10-18 19:00:00" --end "2025-10-18 20:00:00"
```

## Example Workflow

### Start Fresh and Monitor Logs

```bash
# 1. Reset simulator to clean state
xcrun simctl erase "iPhone 17"

# 2. Boot simulator
xcrun simctl boot "iPhone 17"
open -a Simulator

# 3. In a separate terminal, start streaming logs
xcrun simctl spawn booted log stream --level debug \
  --predicate 'subsystem == "com.increment.app"' --color always

# 4. In another terminal, build and run
cd /Users/ishandhanani/Desktop/increment/.conductor/indianapolis/increment/IncrementProject
xcodebuild -workspace Increment.xcworkspace \
  -scheme Increment \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build

# 5. Install and launch
xcrun simctl install "iPhone 17" \
  ~/Library/Developer/Xcode/DerivedData/.../Increment.app
xcrun simctl launch "iPhone 17" com.increment.app

# Now interact with app - logs appear in terminal from step 3
```

## Log Output Examples

### What You'll See

```
2025-10-18 19:46:22 Debug   [session] START WORKOUT button tapped
2025-10-18 19:46:22 Notice  [session] Starting new session with dynamic generation
2025-10-18 19:46:22 Debug   [session] Session initialized, workout will be generated
2025-10-18 19:46:23 Notice  [session] Generating push workout
2025-10-18 19:46:23 Info    [session] Workout template generated: Push Day A
2025-10-18 19:46:24 Notice  [liveActivity] Live Activity started
```

## Quick Tips

**Color output:**
Add `--color always` to log commands for colored output

**Follow logs like tail -f:**
Use `log stream` (it auto-follows)

**Save & analyze later:**
```bash
log stream --predicate 'subsystem == "com.increment.app"' > ~/Desktop/app_logs.txt
# Later:
grep "error" ~/Desktop/app_logs.txt
```

**Find specific simulator UUID:**
```bash
xcrun simctl list devices | grep "iPhone 17"
# Output: iPhone 17 (719B5465-4369-4557-AA6E-370DED0AAFAE) (Booted)
```

**Check if app is running:**
```bash
xcrun simctl listapps booted | grep increment
```

## Xcode Shortcuts

If running from Xcode:
- **⌘R** - Build and run
- **⌘.** - Stop running app
- **⌘K** - Clear console
- **⌘⇧Y** - Show/hide console

## Log Levels Reference

- **debug** - Development info (stripped in release builds)
- **info** - Informational messages
- **notice** - Important state changes
- **error** - Recoverable errors
- **fault** - Critical failures

## Troubleshooting

**Logs not appearing?**
- Make sure subsystem matches: `com.increment.app`
- Check log level: use `--level debug` to see all logs
- Verify app is actually running: `xcrun simctl listapps booted`

**Simulator stuck?**
```bash
xcrun simctl shutdown all
killall Simulator
open -a Simulator
```

**Build issues?**
```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/Increment-*

# Clean build folder
xcodebuild -workspace Increment.xcworkspace -scheme Increment clean
```
