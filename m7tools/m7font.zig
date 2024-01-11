const std = @import("std");

pub const FontError = error{
    FileOpenFailure,
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

pub fn packm7fntFile(file_name: []const u8) !void {
    _ = file_name;
}
