const std = @import("std");
const os = std.os;
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();
const cpp = @import("cpp.zig");
const hyprland = @import("hyprland.zig");
const c = @cImport(@cInclude("SDL3/SDL.h"));

var PHANDLE: hyprland.HANDLE = null;
var joys: std.AutoHashMap(c.SDL_JoystickID, *c.SDL_Joystick) = .init(std.heap.c_allocator);
var subs: hyprland.SP(hyprland.HOOK_CALLBACK_FN) = undefined;
var idle: *hyprland.CIdleNotifyProtocol = undefined;

export fn pluginAPIVersion(ret: *cpp.String) ?*cpp.String {
    ret.constrFromSlice(hyprland.API_VERSION);
    return ret;
}
export fn pluginInit(ret: *hyprland.PLUGIN_DESCRIPTION_INFO, handle: hyprland.HANDLE) *hyprland.PLUGIN_DESCRIPTION_INFO {
    idle = @extern(**hyprland.CIdleNotifyProtocol, .{ .name = "_ZN10NProtocols4idleE" }).*;

    PHANDLE = handle;
    ret.description.constrFromSlice("A plugin that resets the idle timer on controller button events");
    ret.author.constrFromSlice("Mecso");
    ret.version.constrFromSlice("1.1");

    if (!std.mem.eql(u8, std.mem.span(hyprland.getApiHash()), hyprland.GIT_COMMIT_HASH)) {
        notify(handle, .{ .r = 1, .g = 1, .b = 0, .a = 1 }, 8000, "Hypr-GamepadStayAwake version mismatch, expected Hyprland with commit hash: `{s}`, but got one with `{s}`", .{ hyprland.GIT_COMMIT_HASH, hyprland.getApiHash() }) catch @panic("OOM");

        ret.name.constrFromSlice("Hypr-GamepadStayAwake (VERSION MISMATCH)");
        return ret;
    }
    if (!c.SDL_Init(c.SDL_INIT_JOYSTICK)) {
        notify(handle, .{ .r = 1, .g = 1, .b = 0, .a = 1 }, 8000, "Hypr-GamepadStayAwake failed to initailze SDL: `{s}`", .{c.SDL_GetError()}) catch @panic("OOM");

        ret.name.constrFromSlice("Hypr-GamepadStayAwake (Couldn't init SDL)");
        return ret;
    }

    var event_name: cpp.String = undefined;
    event_name.constrFromSlice("tick");
    defer event_name.deinit();
    var f: hyprland.HOOK_CALLBACK_FN = .{ .invoker = &tick };
    defer f.deinit();

    subs = hyprland.registerCallbackDynamic(handle, &event_name, &f);
    if (!subs.dataNonNull()) {
        notify(handle, .{ .r = 1, .g = 1, .b = 0, .a = 1 }, 8000, "Hypr-GamepadStayAwake failed to hook tick event", .{}) catch @panic("OOM");

        ret.name.constrFromSlice("Hypr-GamepadStayAwake (Failed to register callback)");
        return ret;
    }

    ret.name.constrFromSlice("Hypr-GamepadStayAwake");
    return ret;
}
export fn pluginExit() void {
    subs.deinit();
    var iter = joys.valueIterator();
    while (iter.next()) |v| {
        c.SDL_CloseJoystick(v.*);
    }
    joys.deinit();
    c.SDL_Quit();
}

fn tick(_: *const hyprland.HOOK_CALLBACK_FN.Functor, _: *const ?*anyopaque, _: *const hyprland.SCallbackInfo, _: *const ?*anyopaque) callconv(.c) void {
    var event: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&event)) {
        if (event.type == c.SDL_EVENT_JOYSTICK_REMOVED) {
            c.SDL_CloseJoystick(joys.fetchRemove(event.jdevice.which).?.value);
        } else if (event.type == c.SDL_EVENT_JOYSTICK_ADDED) {
            joys.put(event.jdevice.which, c.SDL_OpenJoystick(event.jdevice.which).?) catch @panic("map");
        } else if (event.type == c.SDL_EVENT_JOYSTICK_BUTTON_UP or event.type == c.SDL_EVENT_JOYSTICK_BUTTON_DOWN) {
            idle.onActivity();
        }
    }
}

inline fn notify(handle: hyprland.HANDLE, color: hyprland.CColor, timeout: f32, fmt: []const u8, args: anytype) !void {
    var text = cpp.String.fromOwnedSlice(try std.fmt.allocPrintZ(std.heap.c_allocator, fmt, args));
    defer text.deinit();

    _ = hyprland.addNotification(handle, &text, &color, timeout);
}
