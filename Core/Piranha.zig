const std = @import("std");
const Stream = @import("Byte/Stream.zig").Stream;
const Logger = @import("Logger.zig");

pub fn shortName(comptime T: type) []const u8 {
    const full = @typeName(T);
    const idx = std.mem.lastIndexOfScalar(u8, full, '.') orelse return full;
    return full[idx + 1 ..];
}

pub const Piranha = struct {
    stream: Stream,
    id: u16,
    version: u16,
    name: []const u8,
    conn: std.Io.net.Stream,
    io: std.Io,

    pub fn init(
        allocator: std.mem.Allocator,
        comptime T: type,
        id: u16,
        version: u16,
        conn: std.Io.net.Stream,
        io: std.Io,
    ) Piranha {
        return .{
            .stream = Stream.init(allocator),
            .id = id,
            .version = version,
            .name = shortName(T),
            .conn = conn,
            .io = io,
        };
    }

    pub fn deinit(self: *Piranha) void {
        self.stream.deinit();
    }

    pub fn send(self: *Piranha) !void {
        if (self.id < 20_000) return;

        const bodyLen = self.stream.buffer.items.len;

        var header: [7]u8 = undefined;
        std.mem.writeInt(u16, header[0..2], self.id, .big);
        header[2] = @truncate((bodyLen >> 16) & 0xFF);
        header[3] = @truncate((bodyLen >> 8) & 0xFF);
        header[4] = @truncate(bodyLen & 0xFF);
        std.mem.writeInt(u16, header[5..7], self.version, .big);

        var wbuf: [1024]u8 = undefined;
        var writer = self.conn.writer(self.io, &wbuf);
        try writer.interface.writeAll(&header);
        try writer.interface.writeAll(self.stream.buffer.items);
        try writer.interface.flush();

        Logger.packetOut(self.name);
    }
};
