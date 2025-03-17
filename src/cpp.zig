const std = @import("std");
const malloc_size =
    if (@hasDecl(std.c, "malloc_size"))
        std.c.malloc_size
    else if (@hasDecl(std.c, "malloc_usable_size"))
        std.c.malloc_usable_size
    else if (@hasDecl(std.c, "_msize"))
        std.c._msize
    else {};

pub fn vector(comptime T: type) type {
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
pub const string = extern struct {
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
pub fn shared_ptr(comptime T: type) type {
    return extern struct { ptr: *T, ref_count: *extern struct { vtable: *anyopaque, use_count: std.atomic.Value(i32), weak_count: std.atomic.Value(i32) } };
}

extern fn __cxa_allocate_exception(size: usize) [*]u8;
extern fn __cxa_throw(buf: [*]u8, typeinfo: *anyopaque) noreturn;
