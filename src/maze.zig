const std = @import("std");
const rl = @import("raylib");

const bench = @import("bench.zig");

/// [start] is starting cell index
/// [end] is winning cell index
/// [width] is in number of cells
/// [height] is in number of cells
/// [cells] is array of 4 bit integer, 4 bits can define 4 direction, where 1 -> path, 0 -> wall
pub const Maze = struct {
    width: u16,
    height: u16,
    start: u32,
    end: u32,
    cells: []u4,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        rand: std.Random,
        start: u32,
        end: u32,
        width: u16,
        height: u16,
    ) !Self {
        return .{
            .start = start,
            .end = end,
            .width = width,
            .height = height,
            .cells = try carve(allocator, rand, start, width, height),
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.cells);
    }

    pub fn format(self: Self, writer: *std.Io.Writer) !void {
        try writer.print(
            "Maze {{ {d}->{d}, size: {d}x{d} }}",
            .{ self.start, self.end, self.width, self.height },
        );
    }

    pub fn random(
        allocator: std.mem.Allocator,
        rand: std.Random,
    ) !Self {
        const width = rand.intRangeLessThan(u16, 12, 32);
        const height = rand.intRangeLessThan(u16, 8, 24);
        const start = rand.uintLessThan(u32, width * height);
        const end = rand.uintLessThan(u32, width * height);
        return init(allocator, rand, start, end, width, height);
    }

    pub fn draw(
        self: Self,
        posX: i32,
        posY: i32,
        cellSize: i32,
        wallSize: i32,
    ) void {
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const index = y * self.width + x;

                const cellX: i32 = @intCast(x);
                const cellY: i32 = @intCast(y);

                const px: i32 = posX + (cellX * cellSize);
                const py: i32 = posY + (cellY * cellSize);

                const cell = self.cells[index];
                const N = ((cell >> 3) & 1) == 0;
                const S = ((cell >> 2) & 1) == 0;
                const E = ((cell >> 1) & 1) == 0;
                const W = (cell & 1) == 0;

                // `+ wallSize` so the right corner is closed
                if (N) rl.drawRectangle(px, py, cellSize + wallSize, wallSize, .black);
                if (S) rl.drawRectangle(px, py + cellSize, cellSize + wallSize, wallSize, .black);

                if (E) rl.drawRectangle(px + cellSize, py, wallSize, cellSize, .black);
                if (W) rl.drawRectangle(px, py, wallSize, cellSize, .black);

                if (index == self.start) rl.drawRectangle(
                    px + wallSize,
                    py + wallSize,
                    cellSize - wallSize,
                    cellSize - wallSize,
                    .lime,
                );

                if (index == self.end) rl.drawRectangle(
                    px + wallSize,
                    py + wallSize,
                    cellSize - wallSize,
                    cellSize - wallSize,
                    .maroon,
                );
            }
        }
    }
};

// I could rather use only South and East borders so the drawing is easier but calculations are little tougher (not significant though)
const North: u4 = 0b1000;
const South: u4 = 0b0100;
const East: u4 = 0b0010;
const West: u4 = 0b0001;

/// Cells generator based on a stack based approach
///
/// https://en.wikipedia.org/wiki/Maze_generation_algorithm
fn carve(
    allocator: std.mem.Allocator,
    rand: std.Random,
    start: u32,
    width: u16,
    height: u16,
) ![]u4 {
    const count: usize = @as(usize, width) * @as(usize, height);
    const cells = try allocator.alloc(u4, count);
    @memset(cells, 0);

    const visited = try allocator.alloc(bool, count);
    defer allocator.free(visited);
    @memset(visited, false);

    var stack: std.ArrayList(u32) = try .initCapacity(allocator, width);
    defer stack.deinit(allocator);

    try stack.append(allocator, start);
    visited[start] = true;

    while (stack.items.len > 0) {
        const current = stack.getLastOrNull() orelse break;
        const x = current % width;
        const y = current / width;

        var neighbors: std.ArrayList(u4) = try .initCapacity(allocator, 4);
        defer neighbors.deinit(allocator);

        if (y > 0 and !visited[current - width]) {
            try neighbors.append(allocator, North);
        }
        if (y < height - 1 and !visited[current + width]) {
            try neighbors.append(allocator, South);
        }
        if (x > 0 and !visited[current - 1]) {
            try neighbors.append(allocator, West);
        }
        if (x < width - 1 and !visited[current + 1]) {
            try neighbors.append(allocator, East);
        }

        if (neighbors.items.len == 0) {
            _ = stack.pop();
            continue;
        }

        // random direction
        const dirIndex = rand.uintLessThan(usize, neighbors.items.len);
        const dir: u4 = neighbors.items[dirIndex];
        const oppositeDir = switch (dir) {
            North => South,
            South => North,
            East => West,
            West => East,
            else => unreachable,
        };

        const next = switch (dir) {
            North => current - width,
            South => current + width,
            East => current + 1,
            West => current - 1,
            else => unreachable,
        };
        cells[current] |= dir;
        cells[next] |= oppositeDir;

        visited[next] = true;
        try stack.append(allocator, next);
    }

    return cells;
}

fn benchCarve(allocator: std.mem.Allocator) !void {
    var prng: std.Random.DefaultPrng = .init(42);
    const rand = prng.random();
    var m = try Maze.init(allocator, rand, 0, 0, 32, 32);
    m.deinit(allocator);
}

test "benchmark maze generation" {
    const allocator = std.testing.allocator;

    var thread: std.Io.Threaded = .init(allocator, .{});
    defer thread.deinit();

    const stats = try bench.run(
        thread.io(),
        .{ .warmup = 2, .iters = 20 },
        benchCarve,
        .{allocator},
    );

    // Sanity, not a perf threshold (those are flaky in CI).
    try std.testing.expectEqual(@as(usize, 20), stats.iters);
    try std.testing.expect(stats.min_ns <= stats.meanNs());
    try std.testing.expect(stats.meanNs() <= stats.max_ns);

    std.debug.print("maze 32x32: {f}\n", .{stats});
}
