const std = @import("std");

pub const FontError = error{
    FileOpenFailure,
    ExtNotFound,
    AllocFailure,
    FileCreationFailure,
    WrongChannelSpec,
    ParseFailure,
};

pub const FontData = struct {
    id: u8,
    x: u8,
    y: u8,
    width: u8,
    height: u8,
    x_offset: i8,
    y_offset: i8,
    x_advance: u8,
};

pub const Colour = struct { r: u8, g: u8, b: u8 };

extern fn stbi_load(
    filename: [*:0]const u8,
    x: *c_int,
    y: *c_int,
    channels_in_file: *c_int,
    desired_channels: c_int,
) ?[*]u8;

extern fn stbi_image_free(stbi_file_retval: *anyopaque) void;

// TODO: improve error handling
pub fn packm7fntFile(file_path: [:0]const u8, allocator: std.mem.Allocator) !void {
    var f_name_pos: usize = 0;
    if (std.mem.indexOfScalar(u8, file_path, '/')) |pos| {
        f_name_pos = pos;
    }
    const ext_index = std.mem.indexOfScalar(u8, file_path, '.') orelse {
        std.log.err("file extension not found, exiting", .{});
        return FontError.ExtNotFound;
    };

    var fnt_name = allocator.alloc(u8, (ext_index - f_name_pos) + 4) catch {
        std.log.err("failed to allocate string for file name", .{});
        return FontError.AllocFailure;
    };
    std.mem.copyForwards(u8, fnt_name, file_path[f_name_pos..ext_index]);
    std.mem.copyForwards(u8, fnt_name[ext_index - f_name_pos ..], ".fnt");

    var mf_name = allocator.alloc(u8, (ext_index - f_name_pos) + 3) catch {
        std.log.err("failed to allocate string for file name", .{});
        return FontError.AllocFailure;
    };
    std.mem.copyForwards(u8, mf_name, file_path[f_name_pos..ext_index]);
    std.mem.copyForwards(u8, mf_name[ext_index - f_name_pos ..], ".mf");

    const mf_file = std.fs.cwd().createFile(mf_name, .{}) catch |err| {
        std.log.err("failed to create m7font file! {s}", .{@errorName(err)});
        return FontError.FileCreationFailure;
    };

    const fnt_file = std.fs.cwd().openFile(fnt_name, .{}) catch |err| {
        std.log.err("failed to open bmfont file! {s}", .{@errorName(err)});
        return FontError.FileCreationFailure;
    };
    var line: ?[]u8 = try fnt_file.reader().readUntilDelimiterOrEofAlloc(allocator, '\n', std.math.maxInt(usize));
    line = try fnt_file.reader().readUntilDelimiterOrEofAlloc(allocator, '\n', std.math.maxInt(usize));
    line = try fnt_file.reader().readUntilDelimiterOrEofAlloc(allocator, '\n', std.math.maxInt(usize));
    line = try fnt_file.reader().readUntilDelimiterOrEofAlloc(allocator, '\n', std.math.maxInt(usize));

    // get char count
    const eql_index = std.mem.indexOfScalar(u8, line.?, '=') orelse {
        std.log.err("failed to parse char count!", .{});
        return FontError.ParseFailure;
    };
    const value_str = std.mem.trim(u8, line.?[eql_index + 1 ..], "\r\n\t ");
    const char_count = try std.fmt.parseInt(usize, value_str, 10);
    std.log.info("char count: {}", .{char_count});

    var font_data: [0x100]FontData = std.mem.zeroes([0x100]FontData);
    for (0..char_count) |i| {
        line = try fnt_file.reader().readUntilDelimiterOrEofAlloc(allocator, '\n', std.math.maxInt(usize));
        var values = std.mem.tokenizeAny(u8, line.?, "char id= x= y= width= height= xoffset= yoffset= xadvance=");
        font_data[i].id = try std.fmt.parseInt(u8, values.next().?, 10);
        font_data[i].x = try std.fmt.parseInt(u8, values.next().?, 10);
        font_data[i].y = try std.fmt.parseInt(u8, values.next().?, 10);
        font_data[i].width = try std.fmt.parseInt(u8, values.next().?, 10);
        font_data[i].height = try std.fmt.parseInt(u8, values.next().?, 10);
        font_data[i].x_offset = try std.fmt.parseInt(i8, values.next().?, 10);
        font_data[i].y_offset = try std.fmt.parseInt(i8, values.next().?, 10);
        font_data[i].x_advance = try std.fmt.parseInt(u8, values.next().?, 10);
    }

    _ = try mf_file.writer().write("MF");

    for (0..font_data.len) |i| {
        _ = try mf_file.writer().writeByte(font_data[i].id);
        _ = try mf_file.writer().writeByte(font_data[i].x);
        _ = try mf_file.writer().writeByte(font_data[i].y);
        _ = try mf_file.writer().writeByte(font_data[i].width);
        _ = try mf_file.writer().writeByte(font_data[i].height);
        _ = try mf_file.writer().writeByte(@bitCast(font_data[i].x_offset));
        _ = try mf_file.writer().writeByte(@bitCast(font_data[i].y_offset));
        _ = try mf_file.writer().writeByte(font_data[i].x_advance);
    }

    var x: i32 = 0;
    var y: i32 = 0;
    var found_channels: i32 = 0;
    const file_data: [*]u8 = stbi_load(file_path, &x, &y, &found_channels, 3) orelse {
        std.log.err("failed to open file!", .{});
        return FontError.FileOpenFailure;
    };
    std.log.info("width: {}, height: {}, channels: {}", .{ x, y, found_channels });

    if (found_channels != 3) {
        std.log.err("channels must be RGB, preferably 16 bit!", .{});
        return FontError.WrongChannelSpec;
    }

    _ = try mf_file.writer().writeInt(i32, x, .little);
    _ = try mf_file.writer().writeInt(i32, y, .little);

    var colour: Colour = std.mem.zeroes(Colour);
    var prev_colour: Colour = std.mem.zeroes(Colour);
    var repeat: u8 = 0;

    for (0..@intCast(x * y)) |i| {
        colour.r = file_data[i * @as(usize, @intCast(found_channels))];
        colour.g = file_data[i * @as(usize, @intCast(found_channels)) + 1];
        colour.b = file_data[i * @as(usize, @intCast(found_channels)) + 2];

        if (i == 0 or colour.r != prev_colour.r or colour.g != prev_colour.g or colour.b != prev_colour.b or repeat == 255) {
            if (repeat <= 2) {
                for (0..repeat) |_| {
                    _ = try mf_file.writer().writeByte(prev_colour.r);
                    _ = try mf_file.writer().writeByte(prev_colour.g);
                    _ = try mf_file.writer().writeByte(prev_colour.b);
                    _ = try mf_file.writer().writeByte(@intCast(0));
                }
            } else {
                _ = try mf_file.writer().writeByte(prev_colour.r);
                _ = try mf_file.writer().writeByte(prev_colour.g);
                _ = try mf_file.writer().writeByte(prev_colour.b);
                _ = try mf_file.writer().writeByte(@intCast(0xFF));
                _ = try mf_file.writer().writeByte(repeat);
            }

            repeat = 1;
            prev_colour = colour;
        } else {
            repeat += 1;
        }
    }

    if (repeat > 0) {
        if (repeat <= 2) {
            for (0..repeat) |_| {
                _ = try mf_file.writer().writeByte(prev_colour.r);
                _ = try mf_file.writer().writeByte(prev_colour.g);
                _ = try mf_file.writer().writeByte(prev_colour.b);
                _ = try mf_file.writer().writeByte(@intCast(0));
            }
        } else {
            _ = try mf_file.writer().writeByte(prev_colour.r);
            _ = try mf_file.writer().writeByte(prev_colour.g);
            _ = try mf_file.writer().writeByte(prev_colour.b);
            _ = try mf_file.writer().writeByte(@intCast(0xFF));
            _ = try mf_file.writer().writeByte(repeat);
        }
    }

    stbi_image_free(file_data);
}
