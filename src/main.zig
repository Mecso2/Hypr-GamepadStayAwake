const std=@import("std");
const os=std.os;
const stdout=std.io.getStdOut().writer();
const stderr=std.io.getStdErr().writer();
const cpp=@import("cpp.zig");
const hyprland=@import("hyprland.zig");
const c=@cImport(@cInclude("SDL2/SDL.h"));

var g_pCompositor: *hyprland.CCompositor = undefined;
var PHANDLE: hyprland.HANDLE=null;
var joys: std.AutoHashMap(i32, *c.SDL_Joystick)=undefined;
var thread: std.Thread=undefined;

export fn pluginAPIVersion(ret: *cpp.string) ?*cpp.string{
    ret.constrFromSlice(hyprland.API_VERSION);
    return ret;
}

export fn pluginInit(ret: *hyprland.PLUGIN_DESCRIPTION_INFO, handle: hyprland.HANDLE) *hyprland.PLUGIN_DESCRIPTION_INFO{
    PHANDLE = handle;
    joys=std.AutoHashMap(i32, *c.SDL_Joystick).init(std.heap.c_allocator);
    if(c.SDL_Init(c.SDL_INIT_JOYSTICK)!=0)
        @panic("Can't init SDL");

    ret.name.constrFromSlice("Hypr-GamepadStayAwake");
    ret.description.constrFromSlice("A plugin that resets the idle timer on controller button events");
    ret.author.constrFromSlice("Mecso");
    ret.version.constrFromSlice("1.0");


    //pointer to the unique_ptr to the class, resolve once to get the pointer to the instance
    g_pCompositor=@as(**hyprland.CCompositor, @alignCast(@ptrCast(getAddress("g_pCompositor", handle) orelse return ret))).*;
    stdout.writeAll(g_pCompositor.m_szCurrentSplash.toSlice()) catch {};
    
    
    
    thread=std.Thread.spawn(.{}, threadFn, .{}) catch @panic("lol");
    

    
    return ret;
}

export fn pluginExit() void{
    go=false;
    thread.join();
    var iter=joys.valueIterator();
    while(iter.next())|v|{
        c.SDL_JoystickClose(v.*);
    }
    joys.deinit();
    c.SDL_Quit();
}

var go: bool=true;
fn threadFn() void{
    var event: c.SDL_Event=undefined;
    while(go){
        if(c.SDL_PollEvent(&event)==0) continue;
        
        if(event.type==c.SDL_JOYDEVICEREMOVED){
            c.SDL_JoystickClose(joys.fetchRemove(event.jdevice.which).?.value);
        } else if(event.type==c.SDL_JOYDEVICEADDED){
            joys.put(event.jdevice.which, c.SDL_JoystickOpen(event.jdevice.which).?) catch @panic("map");
        } else if(event.type==c.SDL_JOYBUTTONUP or event.type==c.SDL_JOYBUTTONDOWN){
            hyprland.wlr_idle_notifier_v1_notify_activity(g_pCompositor.m_sWLRIdleNotifier, g_pCompositor.m_sSeat.seat);
        }
    }
}



fn getAddress(name: [:0]const u8, handle: hyprland.HANDLE) ?*anyopaque{
    var identifier: cpp.string = undefined;
    identifier.constrFromSlice(name);
    defer identifier.deinit();

    var fns: std.ArrayList(hyprland.SFunctionMatch) = q:{
        var fns: cpp.vector(hyprland.SFunctionMatch) = undefined;
        hyprland.findFunctionsByName(&fns, handle, &identifier);
        break :q fns.toArrayList();
    };
    defer fns.deinit();
    defer for(fns.items)|*e| e.deinit();

    if(fns.items.len==0){
        stderr.print("Can't find function named {s}\n", .{name}) catch {};
        return null;
    }
    return fns.items[0].address;
}
