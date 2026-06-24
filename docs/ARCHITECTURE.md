# FocusTimer Architecture

FocusTimer is a local macOS menu-bar timer. During a running focus session it asks Shortcuts to enable Focus mode, keeps a countdown visible in the menu bar, sends a completion notification, disables Focus, and optionally opens a full-screen rest reminder.

## Runtime Flow

1. `FocusTimerApp` creates a single `FocusTimerModel` and exposes it through `MenuBarExtra`.
2. `MenuContent` controls duration, fixed Shortcut setup, rest-reminder preference, and start/pause/resume/reset actions.
3. `FocusTimerModel` owns the state machine and coordinates timer ticks, Focus toggling, notifications, bundled Shortcut import, and rest reminders.
4. `TimerEngine` produces a cancellable 1 Hz async tick. The model recomputes remaining time from dates rather than decrementing counters.
5. On natural completion, the model disables Focus, returns to `idle`, and shows the rest reminder if `FocusTimer.showRestReminder` is true.
6. The rest reminder can run a separate 5/15/30 minute break countdown and play a one-shot system beep when it finishes.

## State Model

`TimerState` stores `totalDuration` plus a `FocusPhase`:

- `idle`: no active countdown; duration can be edited.
- `running(endDate)`: remaining time is derived from `endDate.timeIntervalSinceNow`.
- `paused(remaining)`: countdown is frozen; Focus remains on; pending completion notification is cancelled.

The main transitions are:

```text
idle --start--> running --pause--> paused --resume--> running
running --complete/reset--> idle
paused --reset--> idle
```

`reset()` and natural completion both attempt to run the disable Shortcut. `pause()` intentionally does not disable Focus.

## Focus Control

macOS exposes Focus status through `INFocusStatusCenter`, but not a public API for programmatically enabling or disabling Focus. FocusTimer therefore treats `INFocusStatusCenter` as read-only and writes through `/usr/bin/shortcuts run`.

The required Shortcut names are fixed:

- `开始专注`: contains a Shortcuts "Set Focus" action that turns the chosen Focus on.
- `关闭专注`: contains a Shortcuts "Set Focus" action that turns Focus off.

`FocusModeController` runs the selected Shortcut through `ProcessRunner`. Failures do not stop the timer; they are logged and surfaced through an immediate system notification.

## Bundled Shortcut Import

`ShortcutInstaller` supports the "一键创建 Shortcut" UI by opening the bundled `.shortcut` files with `NSWorkspace`:

- `FocusTimer/Resources/Shortcuts/开始专注.shortcut`
- `FocusTimer/Resources/Shortcuts/关闭专注.shortcut`

macOS 26 signed `.shortcut` imports use the file name as the visible Shortcut name, so the resource filenames, model defaults, and installer defaults must match exactly.

Installation status is checked with `shortcuts list` and exact string matching. No fuzzy whitespace or alias matching is performed.

## Persistence

UserDefaults keys:

- `FocusTimer.totalDuration`: selected duration in seconds.
- `FocusTimer.showRestReminder`: whether completion shows the full-screen rest reminder.
- `FocusTimer.enableShortcut` / `FocusTimer.disableShortcut`: legacy keys removed during model initialization.

The default duration is 60 minutes. Custom duration is clamped to 1 through 1440 minutes.

## Rest Reminder

The completion rest reminder is enabled by default. `RestReminderPresenter` owns a `RestReminderWindowController`, which opens one borderless `NSWindow` per `NSScreen`.

Each controller creates one shared `RestBreakTimerModel` and injects it into every `RestReminderView`, so multi-screen windows show the same break countdown and the alarm only plays once. Break countdown state is independent from the main focus timer; closing the reminder cancels any unfinished break countdown without playing the alarm.

Window behavior:

- `.screenSaver` level to appear above full-screen apps.
- `.fullScreenAuxiliary`, `.moveToActiveSpace`, and `.stationary` collection behavior.
- Escape, "我知道了", and "结束休息" dismiss all reminder windows.

## Testing Seams

The app keeps side-effect boundaries protocol-based:

- `ProcessRunning` for child processes.
- `NotificationManaging` for user notifications.
- `ShortcutInstalling` and `WorkspaceOpening` for Shortcut discovery/import.
- `RestReminderPresenting` for the full-screen reminder.
- `RestAlarmPlaying` for the break countdown alarm.

`FocusTimerModel._testHandleCompletion()` is exposed only in debug builds to test completion behavior without sleeping through real timers.

## Logging

All logs use subsystem `com.example.FocusTimer`. Categories are `App`, `FocusTimerModel`, `TimerEngine`, `FocusModeController`, `ShortcutInstaller`, `ProcessRunner`, `NotificationManager`, `RestBreakTimerModel`, and `RestReminderWindowController`.
