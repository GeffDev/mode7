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

    pub fn init(engine: *api.engine.Engine) GraphicsError!Self {
        return Self{
            // TODO: get rid of hardcoded sdl backend
            .backend = .sdl,
            .sdl_backend = sdl.SDLBackend.init(engine) catch |err| {
                std.log.err("failed to initialise sdl! {s}", .{@errorName(err)});
                return GraphicsError.InitFailure;
            },
        };
    }

    pub fn deinit(self: *Self) void {
        self.sdl_backend.deinit(self.sdl_backend);
    }
};
