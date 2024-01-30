const std=@import("std");

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
            if(index >= self.len()) return null;
            return &self.start[index];
        }

        pub fn toArrayList(self: *@This()) std.ArrayList(T) {
            return .{
                .allocator=std.heap.c_allocator,
                .items=self.start[0..@call(.always_inline, len, .{self})],
                .capacity=@call(.always_inline, capacity, .{self})};
        }

        pub fn deinit(self: *@This()) void{
            std.c.free(self.start);
        }
    };
}
pub const string = extern struct{
    c_str: [*:0]u8,
    length: usize,
    un: extern union{
        capacity: usize,
        local_buffer: [15:0]u8
    },

    pub fn toSlice(self: *@This()) callconv(.Inline) [:0]u8{
        return @ptrCast(self.c_str[0..self.length]);
    }
    pub fn constrFromSlice(self: *@This(), slice: []const u8) void{
        self.length=slice.len;
        if(slice.len<16){
            @memcpy(self.un.local_buffer[0..slice.len], slice);
            self.un.local_buffer[slice.len]=0;
            self.c_str=&self.un.local_buffer;
            return;
        }
        self.c_str=(std.heap.c_allocator.dupeZ(u8, slice) catch @panic("Alloc failed")).ptr;
        self.un.capacity=slice.len;
    }

    pub fn deinit(self: *@This()) void{
        if(self.c_str != &self.un.local_buffer)
            std.c.free(self.c_str);
    }
};
