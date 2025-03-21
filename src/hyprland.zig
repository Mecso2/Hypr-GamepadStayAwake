const cpp = @import("cpp.zig");
const config = @import("config");

pub const API_VERSION = "0.1";

pub const HANDLE = ?*opaque {};
pub const PLUGIN_DESCRIPTION_INFO = extern struct { name: cpp.String, description: cpp.String, author: cpp.String, version: cpp.String };

pub const GIT_COMMIT_HASH: []const u8 = config.HYPR_COMMIT_HASH;
pub const getApiHash = @extern(*const fn () callconv(.C) [*:0]const u8, .{ .name = "__hyprland_api_get_hash" });

pub const CColor = extern struct { r: f64, g: f64, b: f64, a: f64 };
pub extern fn addNotification(handle: HANDLE, text: *const cpp.String, color: *const CColor, timeMs: f32) bool;

pub extern fn findFunctionsByName(handle: HANDLE, *const cpp.String) cpp.Vector(SFunctionMatch);
pub extern fn createFunctionHook(handle: HANDLE, src: *const anyopaque, dst: *const anyopaque) ?*CFunctionHook;
pub extern fn removeFunctionHook(handle: HANDLE, hook: *CFunctionHook) bool;

pub const CFunctionHook = extern struct {
    pub inline fn hook(self: *@This()) bool {
        return @extern(*const fn (*@This()) callconv(.C) bool, .{ .name = "_ZN13CFunctionHook4hookEv" })(self);
    }
    pub inline fn unhook(self: *@This()) bool {
        return @extern(*const fn (*@This()) callconv(.C) bool, .{ .name = "_ZN13CFunctionHook6unhookEv" })(self);
    }

    m_pOriginal: ?*anyopaque = null,

    m_pSource: ?*anyopaque = null,
    m_pFunctionAddr: ?*anyopaque = null,
    m_pTrampolineAddr: ?*anyopaque = null,
    m_pDestination: ?*anyopaque = null,
    m_iHookLen: usize = 0,
    m_iTrampoLen: usize = 0,
    m_pOwner: HANDLE = null,
    m_bActive: bool = false,

    m_pOriginalBytes: ?*anyopaque = null,

    const SInstructionProbe = extern struct { len: usize = 0, assembly: cpp.String, insSizes: cpp.Vector(usize) };

    const SAssembly = extern struct { bytes: cpp.Vector(u8) };
};
pub const SFunctionMatch = struct {
    address: ?*anyopaque = null,
    signature: cpp.String,
    demangled: cpp.String,

    pub fn deinit(self: *@This()) void {
        self.signature.deinit();
        self.demangled.deinit();
    }
};

pub const CIdleNotifyProtocol = opaque {
    pub inline fn onActivity(self: *@This()) void {
        return @extern(*const fn (*@This()) callconv(.C) void, .{ .name = "_ZN19CIdleNotifyProtocol10onActivityEv" })(self);
    }
};
