const std = @import("std");
const Hello = @import("../Message/Receive/Login/Hello.zig");

pub fn dispatch(
    allocator: std.mem.Allocator,
    id: u16,
    payload: []const u8,
    stream: std.Io.net.Stream,
    io: std.Io,
) !void {
    switch (id) {
        10100 => {
            var msg = try Hello.Hello.init(allocator, payload, stream, io);
            defer msg.deinit();
            try msg.decode();
            try msg.process();
        },
        else => {
            const Logger = @import("../Core/Logger.zig");
            Logger.unknown(id);
        },
    }
}
