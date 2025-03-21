const std = @import("std");
const malloc_size =
    if (@hasDecl(std.c, "malloc_size"))
        std.c.malloc_size
    else if (@hasDecl(std.c, "malloc_usable_size"))
        std.c.malloc_usable_size
    else if (@hasDecl(std.c, "_msize"))
        std.c._msize
    else {};

/// std
pub fn Vector(comptime T: type) type {
    return extern struct {
        start: [*]T,
        end: [*]T,
        storage_end: [*]T,

        pub fn len(self: *const @This()) usize {
            return (@intFromPtr(self.end) - @intFromPtr(self.start)) / @sizeOf(T);
        }

        pub fn capacity(self: *const @This()) usize {
            return (@intFromPtr(self.storage_end) - @intFromPtr(self.start)) / @sizeOf(T);
        }

        pub fn get(self: *const @This(), index: usize) ?*T {
            if (index >= self.len()) return null;
            return &self.start[index];
        }

        pub fn toArrayList(self: *const @This()) std.ArrayList(T) {
            return .{ .allocator = std.heap.c_allocator, .items = self.start[0..@call(.always_inline, len, .{self})], .capacity = @call(.always_inline, capacity, .{self}) };
        }

        pub fn fromArrayList(al: *const std.ArrayList(T)) @This() {
            return .{ .start = al.items.ptr, .end = al.items.ptr + al.items.len, .storage_end = al.items.ptr + al.capacity };
        }

        pub fn deinit(self: *@This()) void {
            std.c.free(self.start);
        }
    };
}

pub const String = extern struct {
    c_str: [*:0]u8,
    length: usize,
    un: extern union { capacity: usize, local_buffer: [15:0]u8 },

    pub fn asSlice(self: *@This()) callconv(.Inline) [:0]u8 {
        return @ptrCast(self.c_str[0..self.length]);
    }
    pub fn constrFromSlice(self: *@This(), slice: []const u8) void {
        self.length = slice.len;
        if (slice.len < 16) {
            @memcpy(self.un.local_buffer[0..slice.len], slice);
            self.un.local_buffer[slice.len] = 0;
            self.c_str = &self.un.local_buffer;
            return;
        }
        self.c_str = (std.heap.c_allocator.dupeZ(u8, slice) catch @panic("Alloc failed")).ptr;
        self.un.capacity = if (@TypeOf(malloc_size) != void) malloc_size(self.c_str) - 1 else slice.len;
    }

    pub fn fromOwnedSlice(slice: [:0]u8) @This() {
        return .{ .c_str = slice.ptr, .length = slice.len, .un = .{ .capacity = if (@TypeOf(malloc_size) != void) malloc_size(slice.ptr) - 1 else slice.len } };
    }

    pub fn deinit(self: *@This()) void {
        if (self.c_str != &self.un.local_buffer)
            std.c.free(self.c_str);
    }
};

pub fn SharedPtr(comptime T: type) type {
    return extern struct { ptr: *T, ref_count: *extern struct { vtable: *anyopaque, use_count: std.atomic.Value(i32), weak_count: std.atomic.Value(i32) } };
}

pub const FunctionManagerOp = enum(usize) { get_type_info, get_functor_ptr, clone_functor, destroy_functor };
// x86_64 g++ only
pub fn Function(R: type, Args: []const type) type {
    var invoker_params: [1 + Args.len]std.builtin.Type.Fn.Param = undefined;
    var functor_fn_params: [Args.len]std.builtin.Type.Fn.Param = undefined;
    for (invoker_params[1..], functor_fn_params[0..], Args) |*p, *p2, a| {
        p.* = .{ .type = *const a, .is_generic = false, .is_noalias = false };
        p2.* = .{ .type = a, .is_generic = false, .is_noalias = false };
    }
    const FunctorFn: type = @Type(.{ .@"fn" = .{ .calling_convention = .c, .is_generic = false, .is_var_args = false, .return_type = R, .params = functor_fn_params[0..] } });
    const s = struct {
        const Functor = extern union { object: ?*anyopaque, fn_ptr: *const FunctorFn, method_ptr: MethodPtr(R, Args) };
    };

    invoker_params[0] = .{ .type = *const s.Functor, .is_generic = false, .is_noalias = false };
    const Invoker = @Type(.{ .@"fn" = .{ .calling_convention = .c, .is_generic = false, .is_var_args = false, .return_type = R, .params = invoker_params[0..] } });

    return extern struct {
        pub const Functor = s.Functor;
        functor: Functor = .{ .object = null },
        mananger: *const fn (a: *Functor, b: *const Functor, op: FunctionManagerOp) callconv(.c) bool = &def_manager,
        invoker: *const Invoker,

        fn def_manager(a: *Functor, b: *const Functor, op: FunctionManagerOp) callconv(.c) bool {
            if (op == .clone_functor) {
                a.* = b.*;
            }
            return true;
        }

        pub fn clone(self: @This()) @This() {
            var a: Functor = undefined;
            _ = self.mananger(&a, &self.functor, .clone_functor);
            return .{ .functor = a, .manager = self.mananger, .invoker = self.invoker };
        }

        pub fn deinit(self: @This()) void {
            _ = self.mananger(self.functor, self.functor, .destroy_functor);
        }
    };
}

/// Builtin

// x86_64, aarch64 only
pub fn MethodPtr(R: type, Args: []const type) type {
    var params: [1 + Args.len]std.builtin.Type.Fn.Param = undefined;
    params[0] = .{ .type = *anyopaque, .is_generic = false, .is_noalias = false };
    var ptr_args_tuple_fields: [1 + Args.len]std.builtin.Type.StructField = undefined;
    ptr_args_tuple_fields[0] = .{ .name = "0", .type = *anyopaque, .default_value_ptr = null, .is_comptime = false, .alignment = @alignOf(*anyopaque) };
    var args_tuple_fields: [Args.len]std.builtin.Type.StructField = undefined;
    for (params[1..], ptr_args_tuple_fields[1..], args_tuple_fields[0..], Args, 0..) |*p, *f, *f2, a, i| {
        p.* = .{ .type = a, .is_generic = false, .is_noalias = false };
        f.* = .{ .name = std.fmt.comptimePrint("{d}", .{i + 1}), .type = a, .default_value_ptr = null, .is_comptime = false, .alignment = @alignOf(a) };
        f2.* = .{ .name = std.fmt.comptimePrint("{d}", .{i}), .type = a, .default_value_ptr = null, .is_comptime = false, .alignment = @alignOf(a) };
    }

    const ArgsTuple = @Type(std.builtin.Type{ .@"struct" = .{ .layout = .auto, .decls = &[_]std.builtin.Type.Declaration{}, .is_tuple = true, .fields = args_tuple_fields[0..] } });
    const PtrArgsTuple = @Type(std.builtin.Type{ .@"struct" = .{ .layout = .auto, .decls = &[_]std.builtin.Type.Declaration{}, .is_tuple = true, .fields = ptr_args_tuple_fields[0..] } });
    const Fn: type = @Type(.{ .@"fn" = .{ .calling_convention = .c, .is_generic = false, .is_var_args = false, .return_type = R, .params = params[0..] } });

    return switch (@import("builtin").cpu.arch) {
        .x86_64 => extern struct {
            un: extern union { is_virtual: bool, vtable_offset_plus_1: usize, func: *const Fn },
            this_offet: usize,

            pub fn call(self: @This(), this: *anyopaque, args: ArgsTuple) R {
                var ptr_args: PtrArgsTuple = undefined;
                const offset_this: *align(1) usize = @ptrFromInt(@intFromPtr(this) + self.this_offet);
                ptr_args[0] = offset_this;
                inline for (0..Args.len) |i| {
                    ptr_args[1 + i] = args[i];
                }

                if (self.un.is_virtual) {
                    const vtable_ptr: usize = offset_this.*;
                    const func: *const Fn = @as(*const *const Fn, @ptrFromInt(vtable_ptr + self.un.vtable_offset_plus_1 - 1)).*;
                    return @call(.auto, func, ptr_args);
                } else {
                    return @call(.auto, self.un.func, ptr_args);
                }
            }
        },
        .aarch64 => extern struct {
            un: extern union { vtable_offset: usize, func: *const Fn },
            pa: packed struct(usize) { is_virtual: bool, this_offet: u63 },

            pub fn call(self: @This(), this: *anyopaque, args: ArgsTuple) R {
                var ptr_args: PtrArgsTuple = undefined;
                const offset_this: *align(1) usize = @ptrFromInt(@intFromPtr(this) + self.pa.this_offet);
                ptr_args[0] = offset_this;
                inline for (0..Args.len) |i| {
                    ptr_args[1 + i] = args[i];
                }

                if (self.pa.is_virtual) {
                    const vtable_ptr: usize = offset_this.*;
                    const func: *const Fn = @as(*const *const Fn, @ptrFromInt(vtable_ptr + self.un.vtable_offset)).*;
                    return @call(.auto, func, ptr_args);
                } else {
                    return @call(.auto, self.un.func, ptr_args);
                }
            }
        },
        else => @compileError("Unsupported arch"),
    };
}

extern fn __cxa_allocate_exception(size: usize) [*]u8;
extern fn __cxa_throw(buf: [*]u8, typeinfo: *anyopaque) noreturn;
