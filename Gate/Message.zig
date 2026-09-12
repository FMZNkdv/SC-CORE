const std = @import("std");
const Logger = @import("../Core/Logger.zig");
const shortName = @import("../Core/Piranha.zig").shortName;
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
            Logger.packetIn(shortName(Hello.Hello));
            var msg = try Hello.Hello.init(allocator, payload, stream, io);
            defer msg.deinit();
            try msg.decode();
            try msg.process();
        },
        else => Logger.unknown(id),
    }
}
