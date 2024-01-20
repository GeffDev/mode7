const std = @import("std");

const gfx = @import("m7gfx.zig");
const fnt = @import("m7font.zig");

const log_type: @import("std").log.Level = .info;

fn printHelp() void {
    std.log.info("HELP:", .{});
    std.log.info("--packmg <filename>: pack image file into m7gfx file", .{});
    std.log.info("--packfont <img_filename>: pack image and fnt file (bmfont format) into a m7font file", .{});
    std.log.info("--packdata: pack \"Data/\" dir into a \"Data.msa\" file", .{});
}

pub fn main() !void {
    std.log.info("m7tools, version 1\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    var args = try std.process.ArgIterator.initWithAllocator(alloc);
    defer args.deinit();

    _ = args.next();

    if (args.next()) |arg| {
        if (std.mem.eql(u8, "--packmg", arg)) {
            if (args.next()) |path| {
                gfx.packGfxFile(path, alloc) catch |err| {
                    std.log.err("failed to pack m7gfx file! {s}", .{@errorName(err)});
                };
            } else {
                std.log.err("no file path provided!", .{});
            }
        } else if (std.mem.eql(u8, "--packmf", arg)) {
            if (args.next()) |path| {
                fnt.packm7fntFile(path, alloc) catch |err| {
                    std.log.err("failed to pack m7font file! {s}", .{@errorName(err)});
                };
            } else {
                std.log.err("no file path provided!", .{});
            }
        }
    } else {
        printHelp();
    }
}
