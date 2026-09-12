const std = @import("std");
const Message = @import("Gate/Message.zig");
const Logger = @import("Core/Logger.zig");
const builtin = @import("builtin");

pub const std_options: std.Options = .{
    .logFn = struct {
        fn f(
            comptime _: std.log.Level,
            comptime _: @TypeOf(.enum_literal),
            comptime _: []const u8,
            _: anytype,
        ) void {}
    }.f,
};

const client_stack_size = 256 * 1024;

fn getPeerIp(handle: std.os.linux.fd_t, buf: []u8) []const u8 {
    var addr: std.os.linux.sockaddr = undefined;
    var len: std.os.linux.socklen_t = @sizeOf(std.os.linux.sockaddr);
    if (std.os.linux.getpeername(handle, &addr, &len) != 0) return "?";
    if (addr.family != std.os.linux.AF.INET) return "?";
    const in: *const std.os.linux.sockaddr.in = @ptrCast(@alignCast(&addr));
    const b = @as([4]u8, @bitCast(in.addr));
    return std.fmt.bufPrint(buf, "{d}.{d}.{d}.{d}", .{ b[0], b[1], b[2], b[3] }) catch "?";
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    const addr = try std.Io.net.IpAddress.parseIp4("0.0.0.0", 9339);
    var server = try addr.listen(io, .{ .reuse_address = true });
    defer server.deinit(io);

    Logger.banner();
    Logger.serverInfo("Listening on {d}", .{9339});

    while (true) {
        const stream = server.accept(io) catch |err| {
            Logger.serverInfo("accept() failed  {any}", .{err});
            continue;
        };

        const t = std.Thread.spawn(.{ .stack_size = client_stack_size }, clientLoop, .{ stream, io }) catch |err| {
            Logger.serverInfo("Thread spawn failed  {any}", .{err});
            stream.close(io);
            continue;
        };
        t.detach();
    }
}

fn clientLoop(stream: std.Io.net.Stream, io: std.Io) void {
    defer stream.close(io);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var ipBuf: [64]u8 = undefined;
    const ip: []const u8 = if (builtin.os.tag == .windows)
        "client"
    else
        getPeerIp(stream.socket.handle, &ipBuf);

    Logger.setAddrStr(ip);
    Logger.connect();

    var rbuf: [1024]u8 = undefined;
    var reader = stream.reader(io, &rbuf);

    var header: [7]u8 = undefined;

    while (true) {
        reader.interface.readSliceAll(&header) catch |err| {
            if (err == error.EndOfStream or err == error.ReadFailed) {
                Logger.disconnect();
            } else {
                Logger.clientErr("Read failed  {any}", .{err});
            }
            break;
        };

        const msgId: u16 = std.mem.readInt(u16, header[0..2], .big);
        const msgLen: usize =
            (@as(usize, header[2]) << 16) |
            (@as(usize, header[3]) << 8) |
            @as(usize, header[4]);

        const alloc = arena.allocator();
        const payload = alloc.alloc(u8, msgLen) catch {
            Logger.clientErr("Out of memory for {d} bytes", .{msgLen});
            break;
        };

        if (msgLen > 0) {
            reader.interface.readSliceAll(payload) catch |err| {
                if (err == error.EndOfStream or err == error.ReadFailed) {
                    Logger.disconnect();
                } else {
                    Logger.clientErr("Payload read failed  {any}", .{err});
                }
                break;
            };
        }

        Message.dispatch(alloc, msgId, payload, stream, io) catch |err| {
            Logger.clientErr("Dispatch failed on {d}  {any}", .{ msgId, err });
        };

        _ = arena.reset(.free_all);
    }
}
