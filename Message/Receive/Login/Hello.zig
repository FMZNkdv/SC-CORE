const std = @import("std");
const Stream = @import("../../../Core/Byte/Stream.zig").Stream;
const HelloReply = @import("../../Transmit/Login/Hello.zig");

pub const Hello = struct {
    stream: Stream,
    conn: std.Io.net.Stream,
    io: std.Io,

    pub fn init(allocator: std.mem.Allocator, payload: []const u8, conn: std.Io.net.Stream, io: std.Io) !Hello {
        return .{
            .stream = try Stream.initWithBytes(allocator, payload),
            .conn = conn,
            .io = io,
        };
    }

    pub fn deinit(self: *Hello) void {
        self.stream.deinit();
    }

    pub fn decode(self: *Hello) !void {
        _ = self;
    }

    pub fn process(self: *Hello) !void {
        var reply = HelloReply.Hello.init(self.stream.allocator, self.conn, self.io);
        defer reply.deinit();
        try reply.send();
    }
};
