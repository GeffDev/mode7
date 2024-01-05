const std = @import("std");

const api = @import("../api.zig");

// backends
const sdl = @import("Backends/SDL.zig");

pub const GraphicsError = error{
    InitFailure,
};

const RenderType = enum {
    software,
    hardware,
};

const Backend = enum {
    sdl,
};

pub const DrawingCore = struct {
    backend: Backend,
    render_type: RenderType,
    sdl_backend: sdl.SDLBackend,
    framebuffer: []u16,

    const Self = @This();

    pub fn init(engine: *api.engine.Engine) GraphicsError!Self {
        var core: DrawingCore = undefined;

        // TODO: don't hardcode sdl backend
        core.backend = .sdl;
        // or the render type lol
        core.render_type = .software;

        core.sdl_backend = sdl.SDLBackend.init(&core, engine, engine.allocator) catch |err| {
            std.log.err("failed to initialise sdl! {s}", .{@errorName(err)});
            return GraphicsError.InitFailure;
        };

        return core;
    }

    pub fn deinit(self: *Self) void {
        if (self.backend == .sdl) {
            self.sdl_backend.deinit();
        }
    }

    pub fn render(self: *Self, engine: *api.engine.Engine) void {
        if (self.backend == .sdl) {
            self.sdl_backend.render(engine);
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
