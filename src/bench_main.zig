const std = @import("std");

const bench = @import("bench.zig");
const Maze = @import("maze.zig").Maze;

fn benchCarve(allocator: std.mem.Allocator, size: u16) !void {
    var prng: std.Random.DefaultPrng = .init(42);
    const rand = prng.random();
    var m = try Maze.init(allocator, rand, 0, 0, size, size);
    m.deinit(allocator);
}

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var thread: std.Io.Threaded = .init(allocator, .{});
    defer thread.deinit();

    const sizes = [_]u16{ 32, 64, 128, 256, 512, 1024, 2048, 4096 };
    for (sizes) |size| {
        const stats = try bench.run(
            thread.io(),
            .{ .warmup = 2, .iters = 20 },
            benchCarve,
            .{ allocator, size },
        );

        std.debug.print("maze={d}², {f}\n", .{ size, stats });
    }
}
