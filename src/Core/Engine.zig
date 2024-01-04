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
    vsync: bool,
    refresh_rate: u64,
};

pub const Engine = struct {
    game_options: GameOptions,

    drawing: api.drawing.DrawingCore,

    const Self = @This();

    pub fn init(game_options: GameOptions) EngineError!Self {
        var engine: Engine = undefined;

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
};
