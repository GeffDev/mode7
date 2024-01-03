const std = @import("std");

const sdl = @import("zsdl");

pub const SDLError = error{InitFailure};

pub const SDLBackend = struct {
    const Self = @This();

    pub fn init() SDLError!Self {
        sdl.init(.{ .video = true, .events = true }) catch |err| {
            std.log.err("SDL Error: {s}", .{@errorName(err)});
            return SDLError.InitFailure;
        };

        return Self{};
    }

    pub fn deinit(self: *Self) void {
        _ = self; // autofix

        sdl.quit();
    }
};
