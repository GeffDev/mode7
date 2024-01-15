const std = @import("std");

const api = @import("../api.zig");

// backends
const sdl = @import("Backends/SDL.zig");

pub const GraphicsError = error{
    InitFailure,
    OutOfBounds,
};

pub const GfxError = error{
    FileNotFound,
    AllocFailure,
    InvalidFile,
};

const RenderType = enum {
    software,
    hardware,
};

const Backend = enum {
    sdl,
};

const Colour = struct {
    r: u8,
    g: u8,
    b: u8,
};

inline fn rgb888ToRgb565(r: u8, g: u8, b: u8) u16 {
    var short: u16 = 0;

    // ew again
    var short1: u16 = r >> 3;
    short1 <<= 11;
    var short2: u16 = g >> 2;
    short2 <<= 5;
    const short3: u16 = b >> 3;
    short = short1 | short2 | short3;
    return short;
}

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

    pub inline fn getPixel(gfx: *Graphic, coords: api.util.Vector2) GraphicsError!u16 {
        if (coords.x < gfx.size.x and coords.x >= 0 and coords.y < gfx.size.y and coords.y >= 0) {
            return rgb888ToRgb565(gfx.data[@as(usize, @intCast((coords.y * gfx.size.x) + coords.x))].r, gfx.data[@as(usize, @intCast((coords.y * gfx.size.x) + coords.x))].g, gfx.data[@as(usize, @intCast((coords.y * gfx.size.x) + coords.x))].b);
        } else {
            return GraphicsError.OutOfBounds;
        }
    }

    pub fn clearScreen(self: *Self, colour: Colour, engine: *api.engine.Engine) void {
        for (0..@as(usize, @intCast(engine.game_options.res.x * engine.game_options.res.y))) |i| {
            self.framebuffer[i] = rgb888ToRgb565(colour.r, colour.g, colour.b);
        }
    }

    pub fn drawSprite(self: *Self, gfx: *Graphic, sprite_pos: api.util.Vector2, sprite_res: api.util.Vector2, sprite_coords: api.util.Vector2, engine: *api.engine.Engine) GraphicsError!void {
        var current_fb_pos = api.util.Vector2{ .x = sprite_pos.x, .y = sprite_pos.y };

        for (@as(usize, @intCast(sprite_coords.y))..@as(usize, @intCast(sprite_coords.y + sprite_res.y))) |y| {
            for (@as(usize, @intCast(sprite_coords.x))..@as(usize, @intCast(sprite_coords.x + sprite_res.x))) |x| {
                const colour = try getPixel(gfx, .{ .x = @as(i32, @intCast(x)), .y = @as(i32, @intCast(y)) });

                // 16 bit magenta (255 0 255)
                if (colour == 0xF81F) {
                    current_fb_pos.x += 1;
                    continue;
                }

                if (current_fb_pos.x < engine.game_options.res.x and current_fb_pos.x >= 0 and current_fb_pos.y < engine.game_options.res.y and current_fb_pos.y >= 0) {
                    self.framebuffer[@as(usize, @intCast((current_fb_pos.y * engine.game_options.res.x) + current_fb_pos.x))] = colour;
                }

                current_fb_pos.x += 1;
            }

            current_fb_pos.y += 1;
            current_fb_pos.x = sprite_pos.x;
        }
    }
};

pub const Graphic = struct {
    size: api.util.Vector2,
    data: []Colour,

    const Self = @This();

    pub fn load(engine: *api.engine.Engine, file_name: []const u8, allocator: std.mem.Allocator) !Self {
        var graphic: Self = std.mem.zeroes(Self);
        var file = api.reader.File.load(&engine.reader, file_name, allocator) catch |err| {
            std.log.err("failed to load m7gfx file! {s}", .{@errorName(err)});
            return GfxError.FileNotFound;
        };

        const header: []u8 = try allocator.alloc(u8, 2);
        try file.readByteArr(header, 2);
        if (!std.mem.eql(u8, header, "MG")) {
            std.log.err("{s} is not a valid m7gfx file!", .{file_name});
            return GfxError.InvalidFile;
        }
        allocator.free(header);

        graphic.size.x = try file.readInt(allocator);
        graphic.size.y = try file.readInt(allocator);

        graphic.data = allocator.alloc(Colour, @as(usize, @intCast(graphic.size.x * graphic.size.y))) catch {
            std.log.err("failed to allocate pixel data for {s}", .{file_name});
            return GfxError.AllocFailure;
        };

        var i: usize = 0;
        while (i < @as(usize, @intCast(graphic.size.x * graphic.size.y))) {
            var colour: Colour = std.mem.zeroes(Colour);
            colour.r = try file.readByte();
            colour.g = try file.readByte();
            colour.b = try file.readByte();
            const rle_sign: u8 = try file.readByte();

            if (rle_sign == 0xFF) {
                const repeat: usize = @as(usize, try file.readByte());

                for (0..repeat) |_| {
                    graphic.data[i] = colour;
                    i += 1;
                }
            } else {
                graphic.data[i] = colour;
                i += 1;
            }
        }

        file.deinit(allocator);
        return graphic;
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};
