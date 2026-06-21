const std = @import("std");
const rl = @import("raylib");

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

    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
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

    pub fn bake(self: Self, cSize: i32, wSize: i32) !rl.RenderTexture2D {
        const w: i32 = @as(i32, self.width) * cSize + wSize;
        const h: i32 = @as(i32, self.height) * cSize + wSize;

        const target: rl.RenderTexture2D = try .init(w, h);

        target.begin();
        defer target.end();

        rl.clearBackground(.blank);

        rl.drawRectangle(
            @as(i32, @intCast(self.start % self.width)) * cSize,
            @as(i32, @intCast(self.start / self.width)) * cSize,
            cSize,
            cSize,
            .lime,
        );

        rl.drawRectangle(
            @as(i32, @intCast(self.end % self.width)) * cSize,
            @as(i32, @intCast(self.end / self.width)) * cSize,
            cSize,
            cSize,
            .maroon,
        );

        for (self.cells, 0..) |cell, index| {
            const x: i32 = @intCast(index % self.width);
            const y: i32 = @intCast(index / self.width);

            const px = x * cSize;
            const py = y * cSize;

            // `+ WALL_SIZE` so the right corner is closed
            if (Direction.north.isWall(cell)) rl.drawRectangle(px, py, cSize + wSize, wSize, .black);
            if (Direction.south.isWall(cell)) rl.drawRectangle(px, py + cSize, cSize + wSize, wSize, .black);

            if (Direction.east.isWall(cell)) rl.drawRectangle(px + cSize, py, wSize, cSize, .black);
            if (Direction.west.isWall(cell)) rl.drawRectangle(px, py, wSize, cSize, .black);
        }

        return target;
    }
};

pub const Direction = enum(u4) {
    north = 0b1000,
    south = 0b0100,
    east = 0b0010,
    west = 0b0001,

    pub fn opposite(self: Direction) Direction {
        return switch (self) {
            .north => .south,
            .south => .north,
            .east => .west,
            .west => .east,
        };
    }

    pub fn isWall(self: Direction, cell: u4) bool {
        const bit = @intFromEnum(self);
        return (cell & bit) != bit;
    }

    pub fn isPath(self: Direction, cell: u4) bool {
        return !self.isWall(cell);
    }
};

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

    var neighbors: [4]Direction = undefined;

    var stack: std.ArrayList(u32) = try .initCapacity(allocator, count / 4);
    defer stack.deinit(allocator);

    var current: u32 = start;

    var n: usize = 0;

    while (true) {
        const x = current % width;
        const y = current / width;

        n = 0;
        if (y > 0 and cells[current - width] == 0) {
            neighbors[n] = .north;
            n += 1;
        }
        if (y < height - 1 and cells[current + width] == 0) {
            neighbors[n] = .south;
            n += 1;
        }
        if (x > 0 and cells[current - 1] == 0) {
            neighbors[n] = .west;
            n += 1;
        }
        if (x < width - 1 and cells[current + 1] == 0) {
            neighbors[n] = .east;
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
        const dir = neighbors[rand.uintLessThan(usize, n)];
        const oppositeDir = dir.opposite();

        const next = switch (dir) {
            .north => current - width,
            .south => current + width,
            .east => current + 1,
            .west => current - 1,
        };
        cells[current] |= @intFromEnum(dir);
        cells[next] |= @intFromEnum(oppositeDir);

        current = next;
    }

    return cells;
}
