const std = @import("std");

pub const Stream = struct {
    allocator: std.mem.Allocator,
    buffer: std.ArrayListUnmanaged(u8),
    offset: usize,
    bitOffset: u4,

    pub fn init(allocator: std.mem.Allocator) Stream {
        return .{
            .allocator = allocator,
            .buffer = .{ .items = &.{}, .capacity = 0 },
            .offset = 0,
            .bitOffset = 0,
        };
    }

    pub fn initWithBytes(allocator: std.mem.Allocator, data: []const u8) !Stream {
        var self = init(allocator);
        try self.buffer.appendSlice(allocator, data);
        return self;
    }

    pub fn deinit(self: *Stream) void {
        self.buffer.deinit(self.allocator);
    }

    fn nextByte(self: *Stream) u8 {
        const b = self.buffer.items[self.offset];
        self.offset += 1;
        return b;
    }

    fn pushByte(self: *Stream, value: u8) !void {
        try self.buffer.append(self.allocator, value);
        self.offset += 1;
    }

    pub fn readByte(self: *Stream) u8 {
        self.bitOffset = 0;
        return self.nextByte();
    }

    pub fn readInt(self: *Stream) i32 {
        self.bitOffset = 0;
        const val = std.mem.readInt(i32, self.buffer.items[self.offset..][0..4], .big);
        self.offset += 4;
        return val;
    }

    pub fn readShort(self: *Stream) i16 {
        self.bitOffset = 0;
        const val = std.mem.readInt(i16, self.buffer.items[self.offset..][0..2], .big);
        self.offset += 2;
        return val;
    }

    pub fn readLong(self: *Stream) i64 {
        self.bitOffset = 0;
        const val = std.mem.readInt(i64, self.buffer.items[self.offset..][0..8], .big);
        self.offset += 8;
        return val;
    }

    pub fn readString(self: *Stream) ![]u8 {
        return self.readStringMax(9_000_000);
    }

    pub fn readStringMax(self: *Stream, maxCapacity: i32) ![]u8 {
        const length = self.readInt();
        if (length <= -1 or length > maxCapacity)
            return try self.allocator.dupe(u8, "");
        const ulen: usize = @intCast(length);
        const result = try self.allocator.dupe(
            u8,
            self.buffer.items[self.offset .. self.offset + ulen],
        );
        self.offset += ulen;
        return result;
    }

    pub fn readVInt(self: *Stream) i32 {
        self.bitOffset = 0;
        var value: u32 = 0;
        var b: u32 = self.nextByte();

        if ((b & 0x40) != 0) {
            value |= b & 0x3F;
            if ((b & 0x80) != 0) {
                b = self.nextByte();
                value |= (b & 0x7F) << 6;
                if ((b & 0x80) != 0) {
                    b = self.nextByte();
                    value |= (b & 0x7F) << 13;
                    if ((b & 0x80) != 0) {
                        b = self.nextByte();
                        value |= (b & 0x7F) << 20;
                        if ((b & 0x80) != 0) {
                            b = self.nextByte();
                            value |= (b & 0x7F) << 27;
                            return @bitCast(value | 0x80000000);
                        }
                        return @bitCast(value | 0xFFF00000);
                    }
                    return @bitCast(value | 0xFFFFE000);
                }
                return @bitCast(value | 0xFFFFFFC0);
            }
            return @bitCast(value | 0xFFFFFFC0);
        }

        value |= b & 0x3F;
        if ((b & 0x80) != 0) {
            b = self.nextByte();
            value |= (b & 0x7F) << 6;
            if ((b & 0x80) != 0) {
                b = self.nextByte();
                value |= (b & 0x7F) << 13;
                if ((b & 0x80) != 0) {
                    b = self.nextByte();
                    value |= (b & 0x7F) << 20;
                    if ((b & 0x80) != 0) {
                        b = self.nextByte();
                        value |= (b & 0x7F) << 27;
                    }
                }
            }
        }
        return @bitCast(value);
    }

    pub fn readVLong(self: *Stream) i64 {
        const high = self.readVInt();
        const low = self.readVInt();
        return (@as(i64, high) << 32) | (@as(i64, @as(u32, @bitCast(low))));
    }

    pub fn readBoolean(self: *Stream) bool {
        if (self.bitOffset == 0) {
            self.offset += 1;
        }
        const value = (self.buffer.items[self.offset - 1] & (@as(u8, 1) << @as(u3, @truncate(self.bitOffset)))) != 0;
        self.bitOffset = @truncate((self.bitOffset + 1) & 7);
        return value;
    }

    pub fn readDataReference(self: *Stream) [2]i32 {
        const a = self.readVInt();
        return .{ a, if (a == 0) 0 else self.readVInt() };
    }

    pub fn writeByte(self: *Stream, value: u8) !void {
        self.bitOffset = 0;
        try self.pushByte(value);
    }

    pub fn writeShort(self: *Stream, value: i16) !void {
        self.bitOffset = 0;
        var b: [2]u8 = undefined;
        std.mem.writeInt(i16, &b, value, .big);
        try self.buffer.appendSlice(self.allocator, &b);
        self.offset += 2;
    }

    pub fn writeInt(self: *Stream, value: i32) !void {
        self.bitOffset = 0;
        var b: [4]u8 = undefined;
        std.mem.writeInt(i32, &b, value, .big);
        try self.buffer.appendSlice(self.allocator, &b);
        self.offset += 4;
    }

    pub fn writeLong(self: *Stream, value: i64) !void {
        try self.writeInt(@truncate(value >> 32));
        try self.writeInt(@truncate(value));
    }

    pub fn writeVInt(self: *Stream, value: i32) !void {
        self.bitOffset = 0;
        const v: u32 = @bitCast(value);

        if (value >= 0) {
            if (value >= 64) {
                try self.pushByte(@truncate((v & 0x3F) | 0x80));
                if (value >= 0x2000) {
                    try self.pushByte(@truncate(((v >> 6) & 0x7F) | 0x80));
                    if (value >= 0x100000) {
                        try self.pushByte(@truncate(((v >> 13) & 0x7F) | 0x80));
                        if (value >= 0x8000000) {
                            try self.pushByte(@truncate(((v >> 20) & 0x7F) | 0x80));
                            try self.pushByte(@truncate((v >> 27) & 0xF));
                        } else {
                            try self.pushByte(@truncate((v >> 20) & 0x7F));
                        }
                    } else {
                        try self.pushByte(@truncate((v >> 13) & 0x7F));
                    }
                } else {
                    try self.pushByte(@truncate((v >> 6) & 0x7F));
                }
            } else {
                try self.pushByte(@truncate(v & 0x3F));
            }
        } else {
            if (value <= -0x40) {
                try self.pushByte(@truncate((v & 0x3F) | 0xC0));
                if (value <= -0x2000) {
                    try self.pushByte(@truncate(((v >> 6) & 0x7F) | 0x80));
                    if (value <= -0x100000) {
                        try self.pushByte(@truncate(((v >> 13) & 0x7F) | 0x80));
                        if (value <= -0x8000000) {
                            try self.pushByte(@truncate(((v >> 20) & 0x7F) | 0x80));
                            try self.pushByte(@truncate((v >> 27) & 0xF));
                        } else {
                            try self.pushByte(@truncate((v >> 20) & 0x7F));
                        }
                    } else {
                        try self.pushByte(@truncate((v >> 13) & 0x7F));
                    }
                } else {
                    try self.pushByte(@truncate((v >> 6) & 0x7F));
                }
            } else {
                try self.pushByte(@truncate((v & 0x3F) | 0x40));
            }
        }
    }

    pub fn writeVLong(self: *Stream, high: i32, low: i32) !void {
        try self.writeVInt(high);
        try self.writeVInt(low);
    }

    pub fn writeBoolean(self: *Stream, value: bool) !void {
        if (self.bitOffset == 0) {
            try self.buffer.append(self.allocator, 0);
            self.offset += 1;
        }
        if (value) {
            self.buffer.items[self.offset - 1] |=
                @as(u8, 1) << @as(u3, @truncate(self.bitOffset));
        }
        self.bitOffset = @truncate((self.bitOffset + 1) & 7);
    }

    pub fn writeString(self: *Stream, value: ?[]const u8) !void {
        if (value) |str| {
            if (str.len > 900_000) {
                try self.writeInt(-1);
                return;
            }
            try self.writeInt(@intCast(str.len));
            try self.buffer.appendSlice(self.allocator, str);
            self.offset += str.len;
        } else {
            try self.writeInt(-1);
        }
    }

    pub fn writeStringReference(self: *Stream, value: []const u8) !void {
        if (value.len > 900_000) {
            try self.writeInt(-1);
            return;
        }
        try self.writeInt(@intCast(value.len));
        try self.buffer.appendSlice(self.allocator, value);
        self.offset += value.len;
    }

    pub fn writeDataReference(self: *Stream, classId: i32, instanceId: i32) !void {
        if (classId < 1) {
            try self.writeVInt(0);
        } else {
            try self.writeVInt(classId);
            try self.writeVInt(instanceId);
        }
    }

    pub fn writeBytes(self: *Stream, data: ?[]const u8) !void {
        if (data) |buf| {
            try self.writeInt(@intCast(buf.len));
            try self.buffer.appendSlice(self.allocator, buf);
            self.offset += buf.len;
        } else {
            try self.writeInt(-1);
        }
    }

    pub fn writeHex(self: *Stream, hex: []const u8) !void {
        if (hex.len % 2 != 0) return error.OddHexLength;
        var i: usize = 0;
        while (i < hex.len) : (i += 2) {
            const byte = std.fmt.parseInt(u8, hex[i .. i + 2], 16) catch
                return error.InvalidHexChar;
            try self.buffer.append(self.allocator, byte);
            self.offset += 1;
        }
    }
};

pub const Writer = struct {
    s: *Stream,

    pub fn init(stream: *Stream) Writer {
        return .{ .s = stream };
    }

    pub fn int(w: Writer, v: i32) void {
        w.s.writeInt(v) catch unreachable;
    }
    pub fn short(w: Writer, v: i16) void {
        w.s.writeShort(v) catch unreachable;
    }
    pub fn byte(w: Writer, v: u8) void {
        w.s.writeByte(v) catch unreachable;
    }
    pub fn vint(w: Writer, v: i32) void {
        w.s.writeVInt(v) catch unreachable;
    }
    pub fn str(w: Writer, v: ?[]const u8) void {
        w.s.writeString(v) catch unreachable;
    }
    pub fn strRef(w: Writer, v: []const u8) void {
        w.s.writeStringReference(v) catch unreachable;
    }
    pub fn long(w: Writer, a: i32, b: i32) void {
        w.s.writeInt(a) catch unreachable;
        w.s.writeInt(b) catch unreachable;
    }
    pub fn longLong(w: Writer, v: i64) void {
        w.s.writeLong(v) catch unreachable;
    }
    pub fn vlong(w: Writer, a: i32, b: i32) void {
        w.s.writeVLong(a, b) catch unreachable;
    }
    pub fn boolean(w: Writer, v: bool) void {
        w.s.writeBoolean(v) catch unreachable;
    }
    pub fn hex(w: Writer, v: []const u8) void {
        w.s.writeHex(v) catch unreachable;
    }
    pub fn bytes(w: Writer, v: ?[]const u8) void {
        w.s.writeBytes(v) catch unreachable;
    }
    pub fn dataRef(w: Writer, a: i32, b: i32) void {
        w.s.writeDataReference(a, b) catch unreachable;
    }
};
