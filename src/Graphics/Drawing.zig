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
        if (self.backend == .sdl) {
            self.sdl_backend.deinit();
        }
    }

    pub fn render(self: *Self) void {
        if (self.backend == .sdl) {
            self.sdl_backend.render();
        }
    }

    pub fn processEvents(self: *Self, engine: *api.engine.Engine) void {
        if (self.backend == .sdl) {
            self.sdl_backend.processEvents(engine);
        }
    }

    pub fn checkFPSCap(self: *Self, engine: *api.engine.Engine) void {
        if (self.backend == .sdl) {
            self.sdl_backend.checkFPSCap(engine);
        }
    }

    pub fn checkUpdateCap(self: *Self, engine: *api.engine.Engine) void {
        if (self.backend == .sdl) {
            self.sdl_backend.checkUpdateCap(engine);
        }
    }
};
