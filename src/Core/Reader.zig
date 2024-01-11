const std = @import("std");

const api = @import("../api.zig");

pub const ReaderError = error{
    FileNotFound,
    StatNotRetrievable,
    AllocFailure,
    EOF,
};

pub const DataFile = struct {
    use_data_file: bool,
    data_file_handle: ?std.fs.File,

    const Self = @This();

    pub fn init(file_name: []const u8) Self {
        var data_file: DataFile = std.mem.zeroes(DataFile);

        const file_handle = std.fs.cwd().openFile(file_name, .{}) catch |err| {
            std.log.info("data file not found! {s}", .{@errorName(err)});

            data_file.use_data_file = false;
            data_file.data_file_handle = null;
            return data_file;
        };

        data_file.use_data_file = true;
        data_file.data_file_handle = file_handle;
        return data_file;
    }

    pub fn deinit(self: *Self) void {
        if (self.use_data_file) {
            self.data_file_handle.?.close();
        }
    }
};

pub const File = struct {
    file_size: u64,
    file_data: []u8,
    file_offset: u64,

    const Self = @This();

    pub fn load(reader: *DataFile, file_name: []const u8, allocator: std.mem.Allocator) ReaderError!File {
        var file: File = std.mem.zeroes(File);

        if (!reader.use_data_file) {
            var file_handle = std.fs.cwd().openFile(file_name, .{}) catch |err| {
                std.log.err("file not found! {s}", .{@errorName(err)});
                return ReaderError.FileNotFound;
            };

            const stat = file_handle.stat() catch |err| {
                std.log.err("failed to get file info! {s}", .{@errorName(err)});
                return ReaderError.StatNotRetrievable;
            };
            file.file_size = stat.size;

            file.file_data = file_handle.readToEndAlloc(allocator, std.math.maxInt(usize)) catch |err| {
                std.log.err("failed to allocate file buffer! {s}", .{@errorName(err)});
                return ReaderError.AllocFailure;
            };

            file_handle.close();
        } else {}

        return file;
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.file_data);
    }

    pub fn readByte(self: *Self) ReaderError!u8 {
        if (self.file_offset >= self.file_size) {
            return ReaderError.EOF;
        }
        const local_buffer: u8 = self.file_data[self.file_offset];
        self.file_offset += 1;
        return local_buffer;
    }

    pub fn readSignedByte(self: *Self) ReaderError!i8 {
        if (self.file_offset >= self.file_size) {
            return ReaderError.EOF;
        }
        const local_buffer: i8 = @intCast(self.file_data[self.file_offset]);
        self.file_offset += 1;
        return local_buffer;
    }

    pub fn readByteArr(self: *Self, buffer: []u8, bytes_to_read: u64) ReaderError!void {
        if (self.file_offset + bytes_to_read >= self.file_size) {
            return ReaderError.EOF;
        }

        for (0..buffer.len) |i| {
            buffer[i] = self.file_data[self.file_offset];
            self.file_offset += 1;
        }
    }

    pub fn readInt(self: *Self, allocator: std.mem.Allocator) ReaderError!i32 {
        const byte_buf: []u8 = allocator.alloc(u8, 4) catch |err| {
            std.log.err("failed to allocate byte buf! {s}", .{@errorName(err)});
            return ReaderError.AllocFailure;
        };
        try self.readByteArr(byte_buf, 4);

        const endian = @import("builtin").cpu.arch.endian();

        //ew
        var int: i32 = 0;

        var int1: i32 = byte_buf[3];
        int1 <<= 24;
        var int2: i32 = byte_buf[2];
        int2 <<= 16;
        var int3: i32 = byte_buf[1];
        int3 <<= 8;
        const int4: i32 = byte_buf[0];
        int = int1 | int2 | int3 | int4;

        allocator.free(byte_buf);
        if (endian == .big) {
            int = @byteSwap(int);
        }
        return int;
    }
};
