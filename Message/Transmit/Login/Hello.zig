const std = @import("std");
const Piranha = @import("../../../Core/Piranha.zig").Piranha;
const Stream = @import("../../../Core/Byte/Stream.zig");

pub const Hello = struct {
    msg: Piranha,

    pub fn init(allocator: std.mem.Allocator, conn: std.Io.net.Stream, io: std.Io) Hello {
        return .{ .msg = Piranha.init(allocator, @This(), 20100, 0, conn, io) };
    }

    pub fn deinit(self: *Hello) void {
        self.msg.deinit();
    }

    pub fn encode(self: *Hello) void {
        const w = Stream.Writer.init(&self.msg.stream);
        w.int(24);
        var i: usize = 0;
        while (i < 24) : (i += 1) w.byte(1);
    }

    pub fn send(self: *Hello) !void {
        self.encode();
        try self.msg.send();
    }
};
