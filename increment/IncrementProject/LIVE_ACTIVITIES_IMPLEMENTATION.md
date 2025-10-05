# Live Activities & Notifications Implementation

## Summary

Successfully implemented Live Activities for workout tracking with Dynamic Island support, lock screen UI, and real-time rest timer updates. The implementation is **complete and modular**, but requires manual Widget Extension target setup in Xcode.

## ✅ What Was Implemented

### 1. **Activity Attributes & Models**
- `WorkoutLiveActivity.swift` - Activity attributes with static workout name and dynamic content state
- Content state includes:
  - Current exercise name
  - Set progress (current/total)
  - Rest timer countdown
  - Next prescription (weight/reps)
  - Exercise completion progress

### 2. **Live Activity Manager**
- `LiveActivityManager.swift` - Singleton manager for activity lifecycle
- Features:
  - Start activity when workout begins
  - Update activity in real-time during rest periods
  - End activity when workout completes
  - Handles errors gracefully

### 3. **Lock Screen UI**
- `WorkoutLiveActivityWidget.swift` - Complete Live Activity widget
- Lock screen displays:
  - Workout name with icon
  - Current exercise and set number
  - Rest timer (when resting)
  - Next prescription preview
  - Exercise completion progress

### 4. **Dynamic Island UI** (iPhone 14 Pro+)
- **Compact**: Shows "INC" icon + rest timer or set progress
- **Minimal**: Shows exercise icon (timer when resting, workout icon when active)
- **Expanded**: Full workout details with:
  - Exercise name and set progress (leading)
  - Rest timer or workout icon (trailing)
  - Next set prescription and overall progress (bottom)

### 5. **SessionManager Integration**
- Integrated with workout lifecycle:
  - Starts Live Activity when first exercise begins
  - Updates during rest periods with countdown timer
  - Updates when moving to next set/exercise
  - Ends when workout completes
- Updates every second during rest timer for smooth countdown

### 6. **Notification Permissions**
- `NotificationManager.swift` - Handles notification authorization
- Required for Live Activities to function
- Async/await API for permission requests
- Status checking methods

### 7. **Widget Extension Files**
- `IncrementWidget/IncrementWidgetBundle.swift` - Widget bundle entry point
- `IncrementWidget/WorkoutLiveActivityWidget.swift` - Widget implementation
- `IncrementWidget/Info.plist` - Configured with:
  - `NSSupportsLiveActivities = YES`
  - `NSSupportsLiveActivitiesFrequentUpdates = YES`

## 📋 Manual Setup Required

The code is complete, but the Widget Extension target needs to be added to Xcode:

### Step 1: Add Widget Extension Target in Xcode

1. Open `Increment.xcworkspace` in Xcode
2. File → New → Target → Widget Extension
3. Configuration:
   - Product Name: `IncrementWidget`
   - Include Live Activity: ✅ YES
   - Bundle ID: `com.increment.app.IncrementWidget`
   - iOS 16.1+
4. Delete generated template files
5. Add existing files:
   - `IncrementWidget/IncrementWidgetBundle.swift`
   - `IncrementWidget/WorkoutLiveActivityWidget.swift`
   - `IncrementWidget/Info.plist`

### Step 2: Configure Dependencies

1. IncrementWidget target → General → Frameworks and Libraries
2. Add `IncrementFeature` SPM package (link to shared code)

### Step 3: Update Main App Info.plist

Add to Increment app target Info.plist:
```xml
<key>NSSupportsLiveActivities</key>
<true/>
<key>NSSupportsLiveActivitiesFrequentUpdates</key>
<true/>
```

### Step 4: Request Notification Permissions

Add to app startup (optional, can be done on first workout):
```swift
Task {
    await NotificationManager.shared.requestAuthorization()
}
```

## 🎨 UI Design

### Lock Screen
```
┌─────────────────────────────┐
│ 🏋️ Default Push/Pull        │
│                        0/2  │
├─────────────────────────────┤
│ Barbell Bench Press         │
│ Set 2 of 3                  │
│                      01:25  │
│                        Rest │
├─────────────────────────────┤
│ Next: 5 reps × 45 lb        │
└─────────────────────────────┘
```

### Dynamic Island (Expanded)
```
┌─────────────────────────────┐
│ Barbell Bench Press  01:25  │
│ Set 2/3                Rest │
│                             │
│ Next Set        Progress    │
│ 5 × 45 lb          0/2      │
└─────────────────────────────┘
```

### Dynamic Island (Compact)
```
INC • 01:25
```

## 🔧 Architecture

```
App Launch
    ↓
SessionManager.init()
    ↓
Start Workout → Pre-Workout Feeling → Stretching
    ↓
First Exercise → Warmups → Load Screen
    ↓
Working Set (LiveActivityManager.startActivity())
    ↓
Log Set → Rest Timer ⟳ (LiveActivityManager.updateActivity() every second)
    ↓
Next Set or Next Exercise
    ↓
Finish Workout (LiveActivityManager.endActivity())
```

## 🧪 Testing

The implementation was tested on iPhone 17 Pro simulator:
1. ✅ App builds successfully
2. ✅ Workout flow works correctly
3. ✅ Rest timer counts down properly
4. ✅ SessionManager integration complete
5. ⏳ Live Activity UI pending Widget Extension target setup

### To Test Live Activities:

1. Complete manual setup steps above
2. Build and run on iPhone 14 Pro+ simulator (or physical device)
3. Start a workout
4. Complete a set to trigger rest timer
5. Lock the screen to see Live Activity
6. Check Dynamic Island (iPhone 14 Pro+ only)

## 📁 Files Created

### Shared (IncrementFeature package)
- `Sources/IncrementFeature/WorkoutLiveActivity.swift`
- `Sources/IncrementFeature/LiveActivityManager.swift`
- `Sources/IncrementFeature/NotificationManager.swift`
- `Sources/IncrementFeature/SessionManager.swift` (updated)

### Widget Extension
- `IncrementWidget/IncrementWidgetBundle.swift`
- `IncrementWidget/WorkoutLiveActivityWidget.swift`
- `IncrementWidget/Info.plist`

### Documentation
- `WIDGET_SETUP_INSTRUCTIONS.md`
- `LIVE_ACTIVITIES_IMPLEMENTATION.md` (this file)

## ✨ Features

✅ Real-time rest timer updates on lock screen
✅ Dynamic Island integration with multiple states
✅ Sleek, minimal UI design with monospaced numbers
✅ Automatic activity lifecycle management
✅ Exercise progress tracking
✅ Next set prescription preview
✅ Notification permission handling
✅ Modular, maintainable code structure
✅ Error handling and edge cases

## 🚀 Next Steps

1. **Manual Setup**: Follow steps in section above to add Widget Extension target
2. **Test on Device**: Dynamic Island requires iPhone 14 Pro+ (simulator or physical)
3. **Permissions**: Request notification permissions on app first launch
4. **Optional Enhancements**:
   - App Intents for quick actions from Live Activity
   - Custom animations for state transitions
   - Haptic feedback on timer completion
   - Background notification when rest timer completes

## 🐛 Known Limitations

- Widget Extension target must be added manually in Xcode (cannot be automated via CLI)
- Dynamic Island testing requires iPhone 14 Pro+ or newer
- Live Activities limited to 8 hours duration (iOS system limit)
- Frequent updates (rest timer) may impact battery on physical devices

## 📚 References

- [Apple Live Activities Documentation](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)
- [Dynamic Island Design Guidelines](https://developer.apple.com/design/human-interface-guidelines/live-activities)
- Issue #28: Implement Live Activities for Workout Sessions
- Issue #30: Widget support (deferred for now, focusing on Live Activities)
