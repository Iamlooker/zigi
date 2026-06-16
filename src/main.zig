const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");

const a = @import("animation.zig");
const Sprite = a.Sprite;

const m = @import("maze.zig");
const Maze = m.Maze;

pub fn main(init: std.process.Init) anyerror!void {
    const screenWidth = 1000;
    const screenHeight = 1000;

    const allocator = init.gpa;

    const seed: u64 = if (builtin.mode == .Debug) blk: {
        break :blk 194;
    } else blk: {
        const timestamp = std.Io.Clock.now(.awake, init.io);
        break :blk @intCast(timestamp.toMilliseconds());
    };

    var prng: std.Random.DefaultPrng = .init(seed);
    const rand = prng.random();

    var maze = try Maze.random(allocator, rand);
    defer maze.deinit(allocator);

    rl.initWindow(screenWidth, screenHeight, "zigi");
    defer rl.closeWindow();

    rl.initAudioDevice();
    defer rl.closeAudioDevice();

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

    var music = try rl.loadMusicStream("resources/sfx/music.mp3");
    defer music.unload();
    rl.setMusicVolume(music, 0.1);
    music.looping = true;
    rl.playMusicStream(music);

    const retrySound = try rl.loadSound("resources/sfx/retry.wav");
    defer retrySound.unload();
    rl.setSoundVolume(retrySound, 0.3);

    const moveSound = try rl.loadSound("resources/sfx/move.wav");
    defer moveSound.unload();
    rl.setSoundVolume(moveSound, 0.1);

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
    var spriteIdleTimer: f32 = 0;

    var playerStartTime: ?std.Io.Timestamp = null;
    var finishDuration: ?std.Io.Duration = null;

    rl.setTargetFPS(240);

    while (!rl.windowShouldClose()) {
        rl.updateMusicStream(music);
        const cell = maze.cells[playerPos];

        const isPlayerAtStart = playerPos == maze.start;
        const isPlayerAtEnd = playerPos == maze.end;

        // Movement before state calculation
        if (!isPlayerAtEnd) {
            if (rl.isKeyPressed(.w)) {
                spriteIdleTimer = PLAYER_RUN_TILL;
                if (((cell >> 3) & 1) != 0) {
                    playerPos -= maze.width;
                    if (!rl.isSoundPlaying(moveSound)) rl.stopSound(moveSound);
                    rl.playSound(moveSound);
                }
            } else if (rl.isKeyPressed(.s)) {
                spriteIdleTimer = PLAYER_RUN_TILL;
                if (((cell >> 2) & 1) != 0) {
                    playerPos += maze.width;
                    if (!rl.isSoundPlaying(moveSound)) rl.stopSound(moveSound);
                    rl.playSound(moveSound);
                }
            } else if (rl.isKeyPressed(.d)) {
                spriteIdleTimer = PLAYER_RUN_TILL;
                if (((cell >> 1) & 1) != 0) {
                    playerPos += 1;
                    if (!rl.isSoundPlaying(moveSound)) rl.stopSound(moveSound);
                    rl.playSound(moveSound);
                }
            } else if (rl.isKeyPressed(.a)) {
                spriteIdleTimer = PLAYER_RUN_TILL;
                if ((cell & 1) != 0) {
                    playerPos -= 1;
                    if (!rl.isSoundPlaying(moveSound)) rl.stopSound(moveSound);
                    rl.playSound(moveSound);
                }
            }
        }

        if (rl.isKeyPressed(.q)) break;
        if (rl.isKeyPressed(.m)) {
            if (rl.isMusicStreamPlaying(music)) {
                rl.stopMusicStream(music);
            } else {
                rl.playMusicStream(music);
            }
        }
        if (rl.isKeyPressed(.r)) {
            rl.playSound(retrySound);
            rl.stopMusicStream(music);
            rl.playMusicStream(music);
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

        const playerX: f32 = @floatFromInt((playerPos % maze.width) * cellSize);
        const playerY: f32 = @floatFromInt((playerPos / maze.width) * cellSize);

        if (isPlayerAtStart) playerStartTime = null;

        if (playerStartTime == null and isPlayerAtStart) {
            playerStartTime = std.Io.Clock.now(.awake, init.io);
        }

        if (finishDuration == null and isPlayerAtEnd) {
            const now = std.Io.Clock.now(.awake, init.io);
            const start = playerStartTime orelse return;
            finishDuration = start.durationTo(now);
        }

        if (spriteIdleTimer > 0) spriteIdleTimer -= rl.getFrameTime();

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.light_gray);

        maze.draw(marginX, marginY, cellSize, wallSize);

        if (spriteIdleTimer > 0) {
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

        if (isPlayerAtEnd) {
            rl.drawRectangle(0, 0, screenWidth, screenHeight, .init(255, 255, 255, 155));

            if (finishDuration) |d| {
                var buf: [64]u8 = undefined;
                const timeText = try std.fmt.bufPrintZ(&buf, "Finished in {f}", .{d});
                rl.drawText(timeText, 400, (screenHeight / 2) - 60, 24, .black);
            }

            rl.drawText("[r]: Refresh [q]: Quit", 400, (screenHeight / 2) - 24, 24, .black);
        } else {
            rl.drawText("[r]: Refresh [q]: Quit", 20, 20, 24, .black);
        }
    }
}
