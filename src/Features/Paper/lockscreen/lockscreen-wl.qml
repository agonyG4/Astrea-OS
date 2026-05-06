import "."

// Disabled for now: WlSessionLock is crashing or stranding the Hyprland session
// on this machine. Keep LockscreenWl.qml for later debugging, but do not launch
// it through this wrapper by accident.
Lockscreen {}
