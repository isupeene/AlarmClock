A simple Alarm Clock mod for Civ VI.

#### Capabilities
* Set an alarm for Δt turns in the future with a custom message. On turn t + Δt, you will receive a notification containing your message.
* A single alarm can be set per future turn.
* You can view and delete upcoming alarms in the grid view, which appears in the dialog after you've added an alarm.
* Upcoming alarms are **not** saved when the game is closed. You'll have to pull out a good old-fashioned paper and pencil if you want to save reminders between sessions!

#### Keyboard Shortcuts
* Alt-R: toggle dialog
* ESC: close dialog
* Enter: confirm alarm, or close dialog if message is blank

#### Known Issues
* Alt-R does not close the window while an EditBox has focus, since the EditBox captures the keystroke.
* Activating the notification pans the camera. There's likely a way to disable panning by passing more arguments to NotificationManager.SendNotification, but most modders don't even know that function exists, much less what its signature is, since it's never called from Lua in the game's code.