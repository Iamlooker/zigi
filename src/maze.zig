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

    var neighbors: [4]u4 = undefined;

    var stack: std.ArrayList(u32) = try .initCapacity(allocator, width);
    defer stack.deinit(allocator);

    var current: u32 = start;

    var n: usize = 0;

    while (true) {
        const x = current % width;
        const y = current / width;

        n = 0;
        if (y > 0 and cells[current - width] == 0) {
            neighbors[n] = North;
            n += 1;
        }
        if (y < height - 1 and cells[current + width] == 0) {
            neighbors[n] = South;
            n += 1;
        }
        if (x > 0 and cells[current - 1] == 0) {
            neighbors[n] = West;
            n += 1;
        }
        if (x < width - 1 and cells[current + 1] == 0) {
            neighbors[n] = East;
            n += 1;
        }

        if (n == 0) {
            // Dead end: jump back to the last decision point.
            if (stack.items.len == 0) break;
            current = stack.pop().?;
            continue;
        }

        // Only push to stack if neighbors > 0
        if (n > 1) try stack.append(allocator, current);

        // random direction
        const dir: u4 = neighbors[rand.uintLessThan(usize, n)];
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

        current = next;
    }

    return cells;
}

fn benchCarve(allocator: std.mem.Allocator, size: u16) !void {
    var prng: std.Random.DefaultPrng = .init(42);
    const rand = prng.random();
    var m = try Maze.init(allocator, rand, 0, 0, size, size);
    m.deinit(allocator);
}

test "benchmark maze generation" {
    const allocator = std.testing.allocator;

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
