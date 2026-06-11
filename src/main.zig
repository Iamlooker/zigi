const std = @import("std");
const m = @import("maze.zig");
const Maze = m.Maze;
const rl = @import("raylib");

// I think the best game for me would be a maze solver
// against some algorithm like A*
// with weird buff
pub fn main(init: std.process.Init) anyerror!void {
    const screenWidth = 1000;
    const screenHeight = 1000;

    const allocator = init.gpa;

    const timestamp = std.Io.Clock.now(.awake, init.io);
    const seed: u64 = @intCast(timestamp.toMilliseconds());

    var prng: std.Random.DefaultPrng = .init(seed);
    const rand = prng.random();

    var maze = try Maze.random(allocator, rand);
    defer maze.deinit(allocator);

    rl.initWindow(screenWidth, screenHeight, "zigi");
    defer rl.closeWindow();

    const wallSize = 3;
    const cellSize = 24;
    var marginX = (screenWidth - (maze.width * cellSize)) / 2;
    var marginY = (screenHeight - (maze.height * cellSize)) / 2;

    var playerPos = maze.start;

    rl.setTargetFPS(240);

    while (!rl.windowShouldClose()) {
        const player = maze.cells[playerPos];
        const playerN = ((player >> 3) & 1) != 0;
        const playerS = ((player >> 2) & 1) != 0;
        const playerE = ((player >> 1) & 1) != 0;
        const playerW = (player & 1) != 0;

        if (playerPos != maze.end) {
            if (rl.isKeyPressed(.w) and playerN) {
                playerPos -= maze.width;
            } else if (rl.isKeyPressed(.s) and playerS) {
                playerPos += maze.width;
            } else if (rl.isKeyPressed(.d) and playerE) {
                playerPos += 1;
            } else if (rl.isKeyPressed(.a) and playerW) {
                playerPos -= 1;
            }
        }

        if (rl.isKeyPressed(.q)) break;
        if (rl.isKeyPressed(.r)) {
            maze.deinit(allocator);
            maze = try Maze.random(allocator, rand);
            marginX = (screenWidth - (maze.width * cellSize)) / 2;
            marginY = (screenHeight - (maze.height * cellSize)) / 2;
            playerPos = maze.start;
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.light_gray);

        maze.draw(marginX, marginY, cellSize, wallSize, playerPos);

        rl.drawText("[r]: Refresh [q]: Quit", 20, 20, 24, .black);
    }
}
