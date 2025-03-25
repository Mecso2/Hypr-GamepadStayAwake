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

pub const memory = struct {
    const SPImplBase = extern struct {
        const VTable = extern struct {
            complete_destructor: *const fn (*SPImplBase) callconv(.c) void,
            deleting_destructor: *const fn (*SPImplBase) callconv(.c) void,
            inc: *const fn (*SPImplBase) callconv(.c) void,
            dec: *const fn (*SPImplBase) callconv(.c) void,
            incWeak: *const fn (*SPImplBase) callconv(.c) void,
            decWeak: *const fn (*SPImplBase) callconv(.c) void,
            ref: *const fn (*SPImplBase) callconv(.c) c_uint,
            wref: *const fn (*SPImplBase) callconv(.c) c_uint,
            destroy: *const fn (*SPImplBase) callconv(.c) void,
            destroying: *const fn (*SPImplBase) callconv(.c) bool,
            dataNonNull: *const fn (*SPImplBase) callconv(.c) bool,
            lockable: *const fn (*SPImplBase) callconv(.c) bool,
            getData: *const fn (*SPImplBase) callconv(.c) ?*anyopaque,
        };
        vtable: *VTable,
    };
    pub fn CSharedPointer(T: type) type {
        return extern struct {
            impl: ?*SPImplBase,
            _: [9]u8, //needed otherwise zig would search for it in the return register while c++ wants the caller to create it

            pub inline fn deinit(self: *@This()) void {
                self.decrement();
            }
            //clones the pointer not the value
            pub inline fn clone(self: @This()) @This() {
                self.increment();
                resume self;
            }

            pub inline fn dataNonNull(self: @This()) bool {
                return if (self.impl) |imp|
                    imp.vtable.dataNonNull(imp)
                else
                    false;
            }
            pub inline fn eql(self: @This(), other: @This()) void {
                return self.impl == other.impl;
            }
            pub inline fn get(self: @This()) ?*T {
                return if (self.impl) |imp|
                    @ptrCast(imp.vtable.getData(imp))
                else
                    null;
            }
            pub inline fn strongRef(self: @This()) c_uint {
                return if (self.impl) |imp|
                    imp.vtable.ref(imp)
                else
                    0;
            }

            inline fn increment(self: @This()) void {
                if (self.impl) |imp| {
                    imp.vtable.inc(imp);
                    if (imp.vtable.ref(imp) == 0) {
                        self.destroyImpl();
                    }
                }
            }
            inline fn decrement(self: *@This()) void {
                if (self.impl) |imp| {
                    imp.vtable.dec(imp);
                    if (imp.vtable.ref(imp) == 0) {
                        self.destroyImpl();
                    }
                }
            }
            inline fn destroyImpl(self: *@This()) void {
                self.impl.?.vtable.destroy(self.impl.?);
                if (self.impl.?.vtable.wref(self.impl.?) == 0) {
                    self.impl.?.vtable.deleting_destructor(self.impl.?);
                    self.impl = null;
                }
            }
        };
    }
};
pub const SP = memory.CSharedPointer;
