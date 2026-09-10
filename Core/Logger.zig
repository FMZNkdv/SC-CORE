const std = @import("std");
const builtin = @import("builtin");

threadlocal var addrBuf: [64]u8 = undefined;
threadlocal var addrLen: usize = 0;

fn termWidth() usize {
    if (builtin.os.tag == .windows) return 80;
    const Winsize = extern struct {
        ws_row: u16,
        ws_col: u16,
        ws_xpixel: u16,
        ws_ypixel: u16,
    };
    var ws: Winsize = std.mem.zeroes(Winsize);
    const TIOCGWINSZ: usize = switch (builtin.os.tag) {
        .macos, .ios => 0x40087468,
        else => 0x5413,
    };
    const rc = std.os.linux.syscall3(
        .ioctl,
        @as(usize, 1),
        TIOCGWINSZ,
        @intFromPtr(&ws),
    );
    if (rc != 0 or ws.ws_col < 20) return 80;
    return ws.ws_col;
}

fn emit(comptime fmt: []const u8, args: anytype) void {
    var buf: [512]u8 = undefined;
    const s = std.fmt.bufPrint(&buf, fmt, args) catch return;
    std.debug.print("{s}", .{s});
}

fn center(visible: usize) void {
    const W = termWidth();
    if (W > visible) {
        var i: usize = 0;
        while (i < (W - visible) / 2) : (i += 1) std.debug.print(" ", .{});
    }
}

pub fn setAddrStr(ip: []const u8) void {
    const copy_len = @min(ip.len, addrBuf.len);
    @memcpy(addrBuf[0..copy_len], ip[0..copy_len]);
    addrLen = copy_len;
}

pub fn getAddr() []const u8 {
    return addrBuf[0..addrLen];
}

pub fn banner() void {
    const lines = [6][]const u8{
        "       _____ ______  __________  ____  ______",
        "      / ___// ____/ / ____/ __ \\/ __ \\/ ____/",
        "      \\__ \\/ /   (_) /   / / / / /_/ / __/   ",
        "     ___/ / /____ / /___/ /_/ / _, _/ /___   ",
        "    /____/\\____(_)\\____/\\____/_/ |_/_____/   ",
        "     SUPERCELL:CORE | github.com/FMZNkdv",
    };
    const colors = [6][]const u8{
        "\x1b[38;2;0;255;255m",
        "\x1b[38;2;0;180;255m",
        "\x1b[38;2;80;100;255m",
        "\x1b[38;2;160;60;255m",
        "\x1b[38;2;220;40;220m",
        "\x1b[38;2;255;180;220m",
    };
    const lineLen = 46;
    emit("\n", .{});
    for (lines, 0..) |line, idx| {
        center(lineLen);
        emit("{s}\x1b[1m{s}\x1b[0m\n", .{ colors[idx], line });
    }
}

pub fn serverInfo(comptime fmt: []const u8, args: anytype) void {
    var buf: [256]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    center(10 + 2 + msg.len);
    emit("\x1b[36m\x1b[1m[ SERVER ]\x1b[0m  {s}\n", .{msg});
}

pub fn connect() void {
    const a = getAddr();
    center(2 + addrLen + 4 + 13);
    emit("\x1b[32m\x1b[1m[ {s} ]\x1b[0m\x1b[32m  ●  Connected\x1b[0m\n", .{a});
}

pub fn disconnect() void {
    const a = getAddr();
    center(2 + addrLen + 4 + 16);
    emit("\x1b[33m\x1b[1m[ {s} ]\x1b[0m\x1b[33m  ○  Disconnected\x1b[0m\n", .{a});
}

pub fn packetIn(id: u16, name: []const u8, _: usize) void {
    const a = getAddr();
    if (std.mem.eql(u8, name, "Unknown")) {
        var buf: [64]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Not Found ({d})", .{id}) catch return;
        center(2 + addrLen + 4 + 5 + msg.len);
        emit("\x1b[34m\x1b[1m[ {s} ]\x1b[0m\x1b[34m  ←  \x1b[0m\x1b[33m{s}\x1b[0m\n", .{ a, msg });
    } else {
        center(2 + addrLen + 4 + 5 + name.len);
        emit("\x1b[34m\x1b[1m[ {s} ]\x1b[0m\x1b[34m  ←  \x1b[0m{s}\n", .{ a, name });
    }
}

pub fn packetOut(id: u16, name: []const u8, _: usize) void {
    const a = getAddr();
    if (std.mem.eql(u8, name, "Unknown")) {
        var buf: [64]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Not Found ({d})", .{id}) catch return;
        center(2 + addrLen + 4 + 5 + msg.len);
        emit("\x1b[35m\x1b[1m[ {s} ]\x1b[0m\x1b[35m  →  \x1b[0m\x1b[33m{s}\x1b[0m\n", .{ a, msg });
    } else {
        center(2 + addrLen + 4 + 5 + name.len);
        emit("\x1b[35m\x1b[1m[ {s} ]\x1b[0m\x1b[35m  →  \x1b[0m{s}\n", .{ a, name });
    }
}

pub fn unknown(id: u16) void {
    const a = getAddr();
    var buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Not Found ({d})", .{id}) catch return;
    center(2 + addrLen + 4 + 5 + msg.len);
    emit("\x1b[33m\x1b[1m[ {s} ]\x1b[0m\x1b[33m  ?  {s}\x1b[0m\n", .{ a, msg });
}

pub fn clientErr(comptime fmt: []const u8, args: anytype) void {
    const a = getAddr();
    var buf: [256]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    center(2 + addrLen + 4 + 5 + msg.len);
    emit("\x1b[31m\x1b[1m[ {s} ]  ✗  {s}\x1b[0m\n", .{ a, msg });
}

pub fn packetName(id: u16) []const u8 {
    return switch (id) {
        10100 => "Hello",
        20100 => "Hello",
        else => "Unknown",
    };
}
