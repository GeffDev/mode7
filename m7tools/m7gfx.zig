const std = @import("std");

pub const GfxError = error{
    FileOpenFailure,
    WrongChannelSpec,
    ExtNotFound,
    AllocFailure,
    FileCreationFailure,
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

pub fn packGfxFile(file_path: [:0]const u8, allocator: std.mem.Allocator) !void {
    var x: i32 = 0;
    var y: i32 = 0;
    var found_channels: i32 = 0;
    const file_data: [*]u8 = stbi_load(file_path, &x, &y, &found_channels, 3) orelse {
        std.log.err("failed to open file!", .{});
        return GfxError.FileOpenFailure;
    };
    std.log.info("width: {}, height: {}, channels: {}", .{ x, y, found_channels });

    if (found_channels != 3) {
        std.log.err("channels must be RGB, preferably 16 bit!", .{});
        return GfxError.WrongChannelSpec;
    }

    var f_name_pos: usize = 0;
    if (std.mem.indexOfScalar(u8, file_path, '/')) |pos| {
        f_name_pos = pos;
    }
    const ext_index = std.mem.indexOfScalar(u8, file_path, '.') orelse {
        std.log.err("file extension not found, exiting", .{});
        return GfxError.ExtNotFound;
    };

    var mg_name = allocator.alloc(u8, (ext_index - f_name_pos) + 3) catch {
        std.log.err("failed to allocate string for file name", .{});
        return GfxError.AllocFailure;
    };
    std.mem.copyForwards(u8, mg_name, file_path[f_name_pos..ext_index]);
    std.mem.copyForwards(u8, mg_name[ext_index - f_name_pos ..], ".mg");

    const mg_file = std.fs.cwd().createFile(mg_name, .{}) catch |err| {
        std.log.err("failed to create m7gfx file! {s}", .{@errorName(err)});
        return GfxError.FileCreationFailure;
    };

    _ = try mg_file.writer().write("MG");
    _ = try mg_file.writer().writeInt(i32, x, .little);
    _ = try mg_file.writer().writeInt(i32, y, .little);

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
                    _ = try mg_file.writer().writeByte(prev_colour.r);
                    _ = try mg_file.writer().writeByte(prev_colour.g);
                    _ = try mg_file.writer().writeByte(prev_colour.b);
                    _ = try mg_file.writer().writeByte(@intCast(0));
                }
            } else {
                _ = try mg_file.writer().writeByte(prev_colour.r);
                _ = try mg_file.writer().writeByte(prev_colour.g);
                _ = try mg_file.writer().writeByte(prev_colour.b);
                _ = try mg_file.writer().writeByte(@intCast(0xFF));
                _ = try mg_file.writer().writeByte(repeat);
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
                _ = try mg_file.writer().writeByte(prev_colour.r);
                _ = try mg_file.writer().writeByte(prev_colour.g);
                _ = try mg_file.writer().writeByte(prev_colour.b);
                _ = try mg_file.writer().writeByte(@intCast(0));
            }
        } else {
            _ = try mg_file.writer().writeByte(prev_colour.r);
            _ = try mg_file.writer().writeByte(prev_colour.g);
            _ = try mg_file.writer().writeByte(prev_colour.b);
            _ = try mg_file.writer().writeByte(@intCast(0xFF));
            _ = try mg_file.writer().writeByte(repeat);
        }
    }

    stbi_image_free(file_data);
    mg_file.close();
}
