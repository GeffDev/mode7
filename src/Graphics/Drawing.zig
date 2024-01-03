const std = @import("std");
const api = @import("../api.zig");

// backends
const sdl = @import("Backends/SDL.zig");

pub const GraphicsError = error{
    InitFailure,
};

const Backend = enum {
    sdl,
};

pub const DrawingCore = struct {
    backend: Backend,
    sdl_backend: sdl.SDLBackend,

    const Self = @This();

    pub fn init() GraphicsError!Self {
        return Self{
            // TODO: get rid of hardcoded sdl backend
            .backend = .sdl,
            .sdl_backend = try sdl.SDLBackend.init(),
        };
    }

    pub fn deinit(self: *Self) void {
        self.sdl_backend.deinit(self.sdl_backend);
    }
};
