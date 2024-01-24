const cpp=@import("cpp.zig");
pub const API_VERSION="0.1";


pub const HANDLE = ?*opaque {};
pub const SFunctionMatch= struct {
    address: ?*anyopaque= null,
    signature: cpp.string,
    demangled: cpp.string,

    pub fn @"~"(self: *@This()) void {
        self.signature.@"~"();
        self.demangled.@"~"();
    }
};
pub const PLUGIN_DESCRIPTION_INFO=extern struct{
    name: cpp.string,
    description: cpp.string,
    author: cpp.string,
    version: cpp.string
};
pub const CFunctionHook = extern struct{
    pub fn hook(self: *@This()) callconv(.Inline) bool{
        return hook_extern(self);
    }
    pub fn unhook(self: *@This()) callconv(.Inline) bool{
        return unhook2(self);
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

    const SInstructionProbe = extern struct {
        len: usize = 0,
        assembly: cpp.string,
        insSizes: cpp.vector(usize)
    };

    const SAssembly = extern struct {
        bytes: cpp.vector(u8)
    };


    const hook_extern=@extern(
        *fn(?*@This()) callconv(.C) bool,
        .{.name="_ZN13CFunctionHook4hookEv"}
    );
    const unhook2=@extern(
        *fn(?*@This()) callconv(.C) bool,
        .{.name="_ZN13CFunctionHook6unhookEv"}
    );
};
pub const CKeybindManager=extern struct{
    _: [320]u8,
    m_pXKBTranslationState: ?*xkb_state
};
pub const SSeat=extern struct{
    seat: *wlr_seat,
    _: [16]u8
};
pub const CCompositor = extern struct{
    _: [104]u8,
    m_sWLRIdleNotifier: *wlr_idle_notifier_v1,
    __: [304]u8,
    m_szCurrentSplash: cpp.string,
    ___: [296]u8,
    m_sSeat: SSeat,
    ____: [64]u8,
};
pub const findFunctionsByName = @extern(*fn(?*cpp.vector(SFunctionMatch), HANDLE, ?*const cpp.string) callconv(.C) void, 
    .{.name="findFunctionsByName"}
);
pub const createFunctionHook = @extern(*fn(HANDLE, ?*const anyopaque, ?*const anyopaque) callconv(.C) ?*CFunctionHook, 
    .{.name="createFunctionHook"}
);


pub const wlr_keyboard_key_event = extern struct{
    time_msec: u32,
    keycode: u32,
    update_state: bool,
    state: wl_keyboard_key_state
};
pub const wl_keyboard_key_state = enum(u32){
    released,
    pressed
};

const wlr_idle_notifier_v1 = opaque{};
const wlr_seat = opaque {};
pub extern fn wlr_idle_notifier_v1_notify_activity(*wlr_idle_notifier_v1, *wlr_seat) void;


pub const xkb_state = opaque{};
pub extern fn xkb_state_key_get_one_sym(*xkb_state, keycode: u32) u32;
pub extern fn xkb_keysym_to_utf32(u32) u32;