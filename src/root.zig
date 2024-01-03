const std = @import("std");

pub const api = @import("api.zig");

const log_type: std.log.Level = .info;

pub fn main() !void {
    std.log.info("cd24", .{});
}
