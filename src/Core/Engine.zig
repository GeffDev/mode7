const std = @import("std");

const api = @import("../api.zig");

pub const EngineError = error{
    GraphicsInitFailure,
};

pub const GameOptions = struct {
    game_title: []const u8,
    res: api.util.Vector2,
    win_res: api.util.Vector2,
    win_scale: i32,
    fullscreen: bool,
    borderless: bool,
    vsync: bool,
    refresh_rate: u64,
};

pub const Engine = struct {
    allocator: std.mem.Allocator,

    game_options: GameOptions,

    drawing: api.drawing.DrawingCore,

    running: bool,
    update_ready: bool,
    render_ready: bool,

    const Self = @This();

    pub fn init(game_options: GameOptions) EngineError!Self {
        var engine: Engine = undefined;
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        engine.allocator = gpa.allocator();

        engine.game_options = game_options;

        engine.drawing = api.drawing.DrawingCore.init(&engine) catch |err| {
            std.log.err("failed to initialise graphics! {s}", .{@errorName(err)});
            return EngineError.GraphicsInitFailure;
        };

        return engine;
    }

    pub fn deinit(self: *Self) void {
        self.drawing.deinit();
    }

    pub fn run(self: *Self, update_func: *const fn () void) EngineError!void {
        self.running = true;

        while (self.running) {
            self.drawing.processEvents(self);

            self.drawing.checkUpdateCap(self);
            if (self.update_ready) {
                update_func();
            }

            self.drawing.checkFPSCap(self);
            if (self.render_ready) {
                self.drawing.render(self);
            }
        }

        self.deinit();
    }
};
