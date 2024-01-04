const std = @import("std");

const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub const SDLError = error{InitFailure};

pub const SDLBackend = struct {
    const Self = @This();

    pub fn init() SDLError!Self {
        if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_EVENTS) != 0) {
            std.log.err("SDL Error: {s}", .{c.SDL_GetError()});
            return SDLError.InitFailure;
        }

        return Self{};
    }

    pub fn deinit(self: *Self) void {
        _ = self; // autofix

        c.SDL_Quit();
    }
};
