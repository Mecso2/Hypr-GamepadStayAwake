# Hypr-GamepadStayAwake
A Hyprland plugin that resets the ext-idle-notify protocol's timer when a button is pressed on a gamepad, so swayidle won't lock your screen when you're playin Rocket League.

## Requirements
- SDL3
- zig (build only)
## Building
### Building and installing using hyprpm
```
hyprpm add https://github.com/Mecso2/Hypr-GamepadStayAwake
```
### Building manually
```
zig build -Drelease -DHYPR_COMMIT_HASH=`hyprctl -j version | jq -r .commit`
```

## Loading
### Installed with hyprpm
```
hyprpm enable Hypr-GamepadStayAwake
```
### Built manually
```
hyprctl plugin load zig-out/lib/libhypr-gamepadstayawake.so
```
