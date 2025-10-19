# Logging in Increment

## Overview

Increment uses Apple's **OSLog** (Unified Logging System) for structured, production-ready logging. All logs are automatically collected by iOS and viewable from your devices.

## Logging Categories

Logs are organized by subsystem for easy filtering:

- **`session`** - Workout session lifecycle (start, resume, discard, state changes)
- **`liveActivity`** - Live Activity updates and lifecycle
- **`notifications`** - Notification permission requests
- **`ui`** - View lifecycle events (debug level)
- **`general`** - General app-wide logs

## Viewing Logs

### During Development (Xcode Console)

Logs appear automatically in Xcode's console when running from Xcode.

### From Physical Device (Console.app)

1. Connect your iPhone to your Mac
2. Open **Console.app** (built into macOS)
3. Select your iPhone from the sidebar
4. Filter by subsystem: `subsystem:com.increment.app`
5. Filter by category: `subsystem:com.increment.app category:session`

### From Device Logs (Settings)

On your iPhone:
1. Settings → Privacy & Security → Analytics & Improvements → Analytics Data
2. Look for logs starting with `Increment`
3. Share to extract and view

## Log Levels

- **`.debug`** - Development/diagnostic info (stripped in release builds)
- **`.info`** - Informational messages
- **`.notice`** - Important state changes (workout started, session resumed)
- **`.error`** - Recoverable errors
- **`.fault`** - Critical failures (not used currently)

## Example Filters in Console.app

```
# All Increment logs
subsystem:com.increment.app

# Session-specific logs
subsystem:com.increment.app category:session

# Live Activity logs
subsystem:com.increment.app category:liveActivity

# Errors only
subsystem:com.increment.app level:error
```

## Privacy

- Logs are automatically redacted for privacy by default
- Use `privacy: .public` only for non-sensitive data
- Never log PII, tokens, or credentials

## Adding New Logs

```swift
import OSLog

// Use existing loggers from AppLogger
AppLogger.session.info("Session started")
AppLogger.liveActivity.notice("Live Activity updated")
AppLogger.ui.debug("View appeared")

// With privacy control
AppLogger.session.info("Workout type: \(workoutType, privacy: .public)")
```

## Future: Crashlytics Integration

When ready to ship to more users, add Firebase Crashlytics:

1. Add Firebase SDK
2. Crashlytics automatically captures logs as breadcrumbs
3. No changes needed to existing OSLog calls
4. Crash reports include recent log context

## Benefits

- ✅ Zero dependencies
- ✅ Minimal performance overhead
- ✅ Privacy-aware by default
- ✅ Works with physical devices
- ✅ Persistent across app launches
- ✅ Easy to filter and search
- ✅ Production-ready
