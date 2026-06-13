const std = @import("std");
const rl = @import("raylib");

const a = @import("animation.zig");
const Sprite = a.Sprite;

const m = @import("maze.zig");
const Maze = m.Maze;

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

    const wallSize = 2;
    const cellSize = 24;
    var marginX = (screenWidth - (maze.width * cellSize)) / 2;
    var marginY = (screenHeight - (maze.height * cellSize)) / 2;

    var playerPos = maze.start;

    const characters = [_][:0]const u8{
        "resources/sprites/doux.png",
        "resources/sprites/mort.png",
        "resources/sprites/tard.png",
        "resources/sprites/vita.png",
    };

    var selectedCharacter = characters[rand.uintLessThan(usize, characters.len)];

    var texture = try rl.loadTexture(selectedCharacter);
    defer rl.unloadTexture(texture);

    const SPRITE_FPS = 15;

    const IDLE_FRAMES = 4;
    var playerIdle: Sprite = .{
        .fps = SPRITE_FPS,
        .texture = texture,
        .frames = try allocator.alloc(rl.Rectangle, IDLE_FRAMES),
    };
    defer allocator.free(playerIdle.frames);
    for (0..IDLE_FRAMES) |i| {
        const iF: f32 = @floatFromInt(i);
        playerIdle.frames[i] = .init(iF * 24, 0, 24, 24);
    }

    const RUNNING_FRAMES = 6;
    var playerRunning: Sprite = .{
        .fps = SPRITE_FPS,
        .texture = texture,
        .frames = try allocator.alloc(rl.Rectangle, RUNNING_FRAMES),
    };
    defer allocator.free(playerRunning.frames);
    for (0..RUNNING_FRAMES) |i| {
        const iF: f32 = @floatFromInt(i);
        playerRunning.frames[i] = .init((iF * 24) + 96, 0, 24, 24);
    }

    const PLAYER_RUN_TILL = 0.2;
    var playerIdleTimer: f32 = 0;

    rl.setTargetFPS(240);

    while (!rl.windowShouldClose()) {
        const cell = maze.cells[playerPos];
        const cellCanN = ((cell >> 3) & 1) != 0;
        const cellCanS = ((cell >> 2) & 1) != 0;
        const cellCanE = ((cell >> 1) & 1) != 0;
        const cellCanW = (cell & 1) != 0;

        const playerX: f32 = @floatFromInt((playerPos % maze.width) * cellSize);
        const playerY: f32 = @floatFromInt((playerPos / maze.width) * cellSize);

        if (playerIdleTimer > 0) playerIdleTimer -= rl.getFrameTime();

        if (playerPos != maze.end) {
            if (rl.isKeyPressed(.w) and cellCanN) {
                playerPos -= maze.width;
                playerIdleTimer = PLAYER_RUN_TILL;
            } else if (rl.isKeyPressed(.s) and cellCanS) {
                playerPos += maze.width;
                playerIdleTimer = PLAYER_RUN_TILL;
            } else if (rl.isKeyPressed(.d) and cellCanE) {
                playerPos += 1;
                playerIdleTimer = PLAYER_RUN_TILL;
            } else if (rl.isKeyPressed(.a) and cellCanW) {
                playerPos -= 1;
                playerIdleTimer = PLAYER_RUN_TILL;
            }
        }

        if (rl.isKeyPressed(.q)) break;
        if (rl.isKeyPressed(.r)) {
            maze.deinit(allocator);
            rl.unloadTexture(texture);

            maze = try Maze.random(allocator, rand);
            marginX = (screenWidth - (maze.width * cellSize)) / 2;
            marginY = (screenHeight - (maze.height * cellSize)) / 2;
            playerPos = maze.start;

            selectedCharacter = characters[rand.uintLessThan(usize, characters.len)];
            texture = try rl.loadTexture(selectedCharacter);

            playerIdle.texture = texture;
            playerRunning.texture = texture;
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.light_gray);

        maze.draw(marginX, marginY, cellSize, wallSize);

        if (playerIdleTimer > 0) {
            playerRunning.draw(
                .init(marginX + playerX, marginY + playerY, 24, 24),
                .zero(),
                .white,
            );
        } else {
            playerIdle.draw(
                .init(marginX + playerX, marginY + playerY, 24, 24),
                .zero(),
                .white,
            );
        }

        if (playerPos == maze.end) {
            rl.drawRectangle(0, 0, screenWidth, screenHeight, .init(255, 255, 255, 155));
            rl.drawText("[r]: Refresh [q]: Quit", 400, (screenHeight / 2) - 24, 24, .black);
        } else {
            rl.drawText("[r]: Refresh [q]: Quit", 20, 20, 24, .black);
        }
    }
}
