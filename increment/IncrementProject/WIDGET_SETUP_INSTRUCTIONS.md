# Widget Extension Setup Instructions

The Live Activity code has been created, but the Widget Extension target needs to be added to the Xcode project manually.

## Files Created

### 1. Activity Attributes (Shared)
- `IncrementPackage/Sources/IncrementFeature/WorkoutLiveActivity.swift`
- `IncrementPackage/Sources/IncrementFeature/LiveActivityManager.swift`
- `IncrementPackage/Sources/IncrementFeature/NotificationManager.swift`

### 2. Widget Extension Files
- `IncrementWidget/IncrementWidgetBundle.swift`
- `IncrementWidget/WorkoutLiveActivityWidget.swift`
- `IncrementWidget/Info.plist`

## Manual Setup Steps (Do in Xcode)

### Step 1: Add Widget Extension Target

1. Open `Increment.xcworkspace` in Xcode
2. File → New → Target
3. Select "Widget Extension"
4. Configure:
   - Product Name: `IncrementWidget`
   - Include Live Activity: ✅ YES
   - Bundle Identifier: `com.yourapp.Increment.IncrementWidget`
   - Minimum iOS version: iOS 16.1 or later
5. Delete the generated template files (Xcode will create some sample files)
6. Add the existing files we created:
   - Right-click the IncrementWidget folder
   - Add Files to "Increment"
   - Select:
     - `IncrementWidget/IncrementWidgetBundle.swift`
     - `IncrementWidget/WorkoutLiveActivityWidget.swift`
     - `IncrementWidget/Info.plist`

### Step 2: Configure Build Settings

1. Select the IncrementWidget target
2. Build Settings → Search "Info.plist"
3. Set Info.plist File to: `IncrementWidget/Info.plist`

### Step 3: Add Framework Dependencies

1. Select the IncrementWidget target
2. General → Frameworks and Libraries
3. Add:
   - `ActivityKit.framework`
   - `WidgetKit.framework`
   - Link the `IncrementFeature` SPM package

### Step 4: Update Main App Target

1. Select the Increment app target
2. Info tab → Add key:
   - `NSSupportsLiveActivities` = `YES`
   - `NSSupportsLiveActivitiesFrequentUpdates` = `YES`

### Step 5: Request Permissions

Add notification permission request to the app startup. The NotificationManager is already created, just call it when starting a session.

## Testing

1. Build and run the app on simulator (iPhone 14 Pro+ for Dynamic Island)
2. Start a workout session
3. Lock the screen to see the Live Activity
4. On supported devices, the Dynamic Island will show workout progress
5. Rest timer will update in real-time

## Architecture

```
SessionManager
    ↓ (manages)
LiveActivityManager
    ↓ (controls)
WorkoutLiveActivity (Widget)
    ↓ (displays)
Lock Screen & Dynamic Island UI
```

## Features Implemented

✅ Live Activity attributes and content state
✅ Lock screen UI with exercise, sets, rest timer
✅ Dynamic Island UI (compact, minimal, expanded)
✅ Real-time rest timer updates
✅ Integrated with SessionManager lifecycle
✅ Notification permissions handling
✅ Automatic start/update/end of activities

## What's Left

- Add the Widget Extension target in Xcode (manual)
- Test on physical device for full Dynamic Island experience
- Optional: Add app intent for quick actions
