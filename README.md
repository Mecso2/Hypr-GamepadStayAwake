# Hypr-GamepadStayAwake
A Hyprland plugin that resets the ext-idle-notify protocol's timer when a button is pressed on a gamepad, so swayidle won't lock your screen when you're playin Rocket League.

## Build
```
zig build -Drelease -DHYPR_COMMIT_HASH=`hyprctl -j version | jq -r .commit`
```
