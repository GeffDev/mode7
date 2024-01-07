const std = @import("std");

const api = @import("../../api.zig");

const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub const SDLError = error{
    InitFailure,
    WindowCreationFailure,
    RendererCreationFailure,
    TextureCreationFailure,
    AllocError,
};

pub const SDLBackend = struct {
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    texture: *c.SDL_Texture,
    event: c.SDL_Event,

    target_fps_freq: u64,
    cur_fps_ticks: u64,
    prev_fps_ticks: u64,

    target_update_freq: u64,
    cur_update_ticks: u64,
    prev_update_ticks: u64,

    const Self = @This();

    pub fn init(drawing: *api.drawing.DrawingCore, engine: *api.engine.Engine, allocator: std.mem.Allocator) SDLError!Self {
        var sdl: Self = undefined;

        if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_EVENTS) != 0) {
            std.log.err("SDL Error: {s}", .{c.SDL_GetError()});
            return SDLError.InitFailure;
        }

        // TODO: does this fair well when rendering to non integer scales?
        _ = c.SDL_SetHint(c.SDL_HINT_RENDER_SCALE_QUALITY, "nearest");

        const flags: u32 = if (engine.game_options.borderless) c.SDL_WINDOW_ALLOW_HIGHDPI | c.SDL_WINDOW_BORDERLESS else c.SDL_WINDOW_ALLOW_HIGHDPI;

        sdl.window = c.SDL_CreateWindow(
            @as([*]const u8, @ptrCast(engine.game_options.game_title)),
            c.SDL_WINDOWPOS_CENTERED,
            c.SDL_WINDOWPOS_CENTERED,
            engine.game_options.win_res.x * engine.game_options.win_scale,
            engine.game_options.win_res.y * engine.game_options.win_scale,
            flags,
        ) orelse {
            std.log.err("SDL Error: {s}", .{c.SDL_GetError()});
            return SDLError.WindowCreationFailure;
        };

        if (engine.game_options.fullscreen) {
            c.SDL_RestoreWindow(sdl.window);
            _ = c.SDL_SetWindowFullscreen(sdl.window, c.SDL_WINDOW_FULLSCREEN_DESKTOP);
            _ = c.SDL_ShowCursor(c.SDL_FALSE);
        }

        sdl.renderer = c.SDL_CreateRenderer(sdl.window, -1, c.SDL_RENDERER_ACCELERATED) orelse {
            std.log.err("SDL Error: {s}", .{c.SDL_GetError()});
            return SDLError.RendererCreationFailure;
        };

        drawing.framebuffer = allocator.alloc(u16, @as(usize, @intCast(engine.game_options.res.x * engine.game_options.res.y))) catch |err| {
            std.log.err("failed to allocate fb! {s}", .{@errorName(err)});
            return SDLError.AllocError;
        };

        sdl.texture = c.SDL_CreateTexture(sdl.renderer, c.SDL_PIXELFORMAT_RGB565, c.SDL_TEXTUREACCESS_STREAMING, engine.game_options.res.x, engine.game_options.res.y) orelse {
            std.log.err("SDL Error: {s}", .{c.SDL_GetError()});
            return SDLError.TextureCreationFailure;
        };

        initFPSUpdateCap(&sdl, engine);

        return sdl;
    }

    pub fn deinit(self: *Self) void {
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }

    // TODO: i dont like this can we get rid of it
    extern fn SDL_LockTexture(
        texture: *c.SDL_Texture,
        rect: ?*c.SDL_Rect,
        pixels: **anyopaque,
        pitch: *i32,
    ) i32;
    fn copyFramebuffer(self: *Self, engine: *api.engine.Engine, drawing: *api.drawing.DrawingCore) void {
        var pitch: i32 = undefined;
        var pixels_uncast: *anyopaque = undefined;

        _ = SDL_LockTexture(self.texture, null, &pixels_uncast, &pitch);

        const pixels: [*]u16 = @ptrCast(@alignCast(pixels_uncast));

        for (0..@as(usize, @intCast(engine.game_options.res.x * engine.game_options.res.y))) |i| {
            pixels[i] = drawing.framebuffer[i];
        }

        c.SDL_UnlockTexture(self.texture);
    }

    pub fn render(self: *Self, engine: *api.engine.Engine) void {
        _ = c.SDL_RenderClear(self.renderer);

        self.copyFramebuffer(engine, &engine.drawing);
        _ = c.SDL_RenderCopy(self.renderer, self.texture, null, null);

        c.SDL_RenderPresent(self.renderer);
    }

    pub fn processEvents(self: *Self, engine: *api.engine.Engine) void {
        while (c.SDL_PollEvent(&self.event) == 1) {
            switch (self.event.type) {
                c.SDL_QUIT => {
                    engine.running = false;
                    break;
                },
                c.SDL_KEYDOWN => {
                    switch (self.event.key.keysym.scancode) {
                        c.SDL_SCANCODE_F1 => {
                            engine.game_options.win_scale += 1;
                            if (engine.game_options.win_scale == 4) {
                                engine.game_options.win_scale = 1;
                            }

                            self.refreshWindow(engine);
                        },
                        c.SDL_SCANCODE_RETURN => {
                            // what why does this work lol, shouldn't it be equal to 1?
                            if ((self.event.key.keysym.mod & c.KMOD_LALT) == 256) {
                                engine.game_options.fullscreen = !engine.game_options.fullscreen;
                                self.refreshWindow(engine);
                            }
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }
    }

    fn refreshWindow(self: *Self, engine: *api.engine.Engine) void {
        c.SDL_HideWindow(self.window);

        if (!engine.game_options.fullscreen) {
            _ = c.SDL_SetWindowFullscreen(self.window, 0);
            _ = c.SDL_ShowCursor(1);

            c.SDL_SetWindowSize(self.window, engine.game_options.win_res.x * engine.game_options.win_scale, engine.game_options.win_res.y * engine.game_options.win_scale);
            c.SDL_SetWindowPosition(self.window, c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED);
        } else {
            if (!engine.game_options.borderless) {
                _ = c.SDL_SetWindowFullscreen(self.window, c.SDL_WINDOW_FULLSCREEN_DESKTOP);
            } else {
                _ = c.SDL_SetWindowFullscreen(self.window, c.SDL_WINDOW_FULLSCREEN);
            }
            _ = c.SDL_ShowCursor(0);
        }

        c.SDL_ShowWindow(self.window);
    }

    fn initFPSUpdateCap(self: *Self, engine: *api.engine.Engine) void {
        self.target_fps_freq = c.SDL_GetPerformanceFrequency() / engine.game_options.refresh_rate;
        self.cur_fps_ticks = 0;
        self.prev_fps_ticks = 0;

        // update is locked to 60 ticks a sec
        self.target_update_freq = c.SDL_GetPerformanceFrequency() / 60;
        self.cur_update_ticks = 0;
        self.prev_update_ticks = 0;
    }

    pub fn checkFPSCap(self: *Self, engine: *api.engine.Engine) void {
        self.cur_fps_ticks = c.SDL_GetPerformanceCounter();
        if (self.cur_fps_ticks >= self.prev_fps_ticks + self.target_fps_freq) {
            engine.render_ready = true;
        } else {
            engine.render_ready = false;
        }
    }

    pub fn checkUpdateCap(self: *Self, engine: *api.engine.Engine) void {
        self.cur_update_ticks = c.SDL_GetPerformanceCounter();
        if (self.cur_update_ticks >= self.prev_update_ticks + self.target_update_freq) {
            engine.update_ready = true;
        } else {
            engine.update_ready = false;
        }
    }
};
