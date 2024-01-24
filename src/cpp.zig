pub fn vector(comptime T: type) type{
    return extern struct {
        start: ?[*]T,
        end: ?[*]T,
        storage_end: ?[*]T,

        pub fn len(self: *const @This()) usize{
            return (@intFromPtr(self.end) - @intFromPtr(self.start)) / @sizeOf(T);
        }

        pub fn get(self: *const @This(), index: usize) ?*T{
            if(index>=self.len()) return null;
            return &self.start.?[index];
        }
    };
}
pub const string = extern struct{
    c_str: [*:0]u8,
    length: usize,
    _:[16]u8,

    pub fn to_slice(self: *@This()) callconv(.Inline) [:0]u8{
        return @ptrCast(self.c_str[0..self.length]);
    }
    pub fn @"(char*)"(this: *@This(), cstr: [*:0]const u8) callconv(.Inline) void{
        @"__(char*)"(this, cstr);
    }
    pub fn @"~"(this: ?*@This()) callconv(.Inline) void{
        @"__~"(this);
    }



    const @"__~" = @extern(
        *fn(?*@This()) callconv(.C) void,
        .{.name="std__string_D"}
    );
    const @"__(char*)" = @extern(
        *fn(?*@This(), [*:0]const u8) callconv(.C) void,
        .{.name="std__string_CcharP"}
    );
};
