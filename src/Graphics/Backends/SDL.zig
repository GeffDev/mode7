const std = @import("std");

const api = @import("../../api.zig");

const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub const SDLError = error{ InitFailure, WindowCreationFailure };

pub const SDLBackend = struct {
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,

    const Self = @This();

    pub fn init(engine: *api.engine.Engine) SDLError!Self {
        var sdl: Self = undefined;

        if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_EVENTS) != 0) {
            std.log.err("SDL Error: {s}", .{c.SDL_GetError()});
            return SDLError.InitFailure;
        }

        sdl.window = c.SDL_CreateWindow(
            @as([*]const u8, @ptrCast(engine.game_options.game_title)),
            c.SDL_WINDOWPOS_CENTERED,
            c.SDL_WINDOWPOS_CENTERED,
            engine.game_options.win_res.x * engine.game_options.win_scale,
            engine.game_options.win_res.y * engine.game_options.win_scale,
            c.SDL_WINDOW_ALLOW_HIGHDPI,
        ) orelse {
            std.log.err("SDL Error: {s}", .{c.SDL_GetError()});
            return SDLError.WindowCreationFailure;
        };

        return sdl;
    }

    pub fn deinit(self: *Self) void {
        _ = self; // autofix

        c.SDL_Quit();
    }
};
