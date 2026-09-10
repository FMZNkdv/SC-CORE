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

const ClientCtx = struct {
    stream: std.Io.net.Stream,
    io: std.Io,
    allocator: std.mem.Allocator,
};

fn getPeerIp(handle: std.os.linux.fd_t, buf: []u8) []const u8 {
    var addr: std.os.linux.sockaddr = undefined;
    var len: std.os.linux.socklen_t = @sizeOf(std.os.linux.sockaddr);
    const rc = std.os.linux.getpeername(handle, &addr, &len);
    if (rc != 0) return "?";
    if (addr.family == std.os.linux.AF.INET) {
        const in: *const std.os.linux.sockaddr.in = @ptrCast(@alignCast(&addr));
        const b = @as([4]u8, @bitCast(in.addr));
        return std.fmt.bufPrint(buf, "{d}.{d}.{d}.{d}", .{ b[0], b[1], b[2], b[3] }) catch "?";
    }
    return "?";
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

        const ctx = std.heap.page_allocator.create(ClientCtx) catch {
            stream.close(io);
            continue;
        };
        ctx.* = .{
            .stream = stream,
            .io = io,
            .allocator = std.heap.page_allocator,
        };

        const t = std.Thread.spawn(.{}, clientLoop, .{ctx}) catch |err| {
            Logger.serverInfo("Thread spawn failed  {any}", .{err});
            stream.close(io);
            std.heap.page_allocator.destroy(ctx);
            continue;
        };
        t.detach();
    }
}

fn clientLoop(ctx: *ClientCtx) void {
    defer {
        ctx.stream.close(ctx.io);
        ctx.allocator.destroy(ctx);
    }

    var arena = std.heap.ArenaAllocator.init(ctx.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var ipBuf: [64]u8 = undefined;
    const ip: []const u8 = if (builtin.os.tag == .windows)
        "client"
    else
        getPeerIp(ctx.stream.socket.handle, &ipBuf);

    Logger.setAddrStr(ip);
    Logger.connect();

    const stream = ctx.stream;
    const io = ctx.io;

    var rbuf: [4096]u8 = undefined;
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
        const msgVer: u16 = std.mem.readInt(u16, header[5..7], .big);
        _ = msgVer;

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

        Logger.packetIn(msgId, Logger.packetName(msgId), msgLen);

        Message.dispatch(alloc, msgId, payload, stream, io) catch |err| {
            Logger.clientErr("Dispatch failed on {d}  {any}", .{ msgId, err });
        };
    }
}
