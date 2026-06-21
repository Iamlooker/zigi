const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");

const Sprite = @import("sprite.zig").Sprite;

const m = @import("maze.zig");
const Maze = m.Maze;
const Direction = m.Direction;

const p = @import("player.zig");
const Player = p.Player;
const Character = p.Character;

const Timer = @import("timer.zig").Timer;

const config = @import("config.zig");
const CELL_SIZE = config.CELL_SIZE;
const WALL_SIZE = config.WALL_SIZE;
const SPRITE_SIZE = config.SPRITE_SIZE;
const PADDING = config.PADDING;

pub fn main(init: std.process.Init) anyerror!void {
    const seed: u64 = if (builtin.mode == .Debug) blk: {
        break :blk 194;
    } else blk: {
        const timestamp = std.Io.Clock.now(.awake, init.io);
        break :blk @intCast(timestamp.toMilliseconds());
    };

    var prng: std.Random.DefaultPrng = .init(seed);
    const rand = prng.random();

    const allocator = init.gpa;

    var maze = try Maze.random(allocator, rand);
    defer maze.deinit(allocator);

    var sw: i32 = 1000;
    var sh: i32 = 1000;

    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(sw, sh, "zigi");
    defer rl.closeWindow();

    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    var cellSize: i32 = CELL_SIZE;
    var mazeTexture = try maze.bake(cellSize, WALL_SIZE);
    defer mazeTexture.unload();

    var music = try rl.loadMusicStream("resources/sfx/music.mp3");
    defer music.unload();
    music.looping = true;
    rl.setMusicVolume(music, 0.1);
    rl.playMusicStream(music);

    const retrySound = try rl.loadSound("resources/sfx/retry.wav");
    defer retrySound.unload();
    rl.setSoundVolume(retrySound, 0.3);

    const moveSound = try rl.loadSound("resources/sfx/move.wav");
    defer moveSound.unload();
    rl.setSoundVolume(moveSound, 0.1);

    var player: Player = try .init(maze.start, Character.random(rand));
    defer player.deinit();

    const SPRITE_FPS = 15;

    const IDLE_FRAMES = 4;
    var playerIdle: Sprite = try .init(allocator, player.texture, SPRITE_FPS, 0, IDLE_FRAMES, SPRITE_SIZE);
    defer playerIdle.deinit(allocator);

    const RUNNING_FRAMES = 6;
    var playerRunning: Sprite = try .init(allocator, player.texture, SPRITE_FPS, IDLE_FRAMES, RUNNING_FRAMES, SPRITE_SIZE);
    defer playerRunning.deinit(allocator);

    const PLAYER_RUN_TILL = 0.25;
    var playerRunTime: f32 = 0;

    var timer: Timer = .{ .io = init.io };

    rl.setTargetFPS(240);

    while (!rl.windowShouldClose()) {
        // Update data which raylib needs
        rl.updateMusicStream(music);

        // Update data which animation needs
        if (playerRunTime > 0) playerRunTime -= rl.getFrameTime();

        // Take input
        if (player.position != maze.end) {
            if (rl.isKeyPressed(.w)) {
                playerRunTime = PLAYER_RUN_TILL;
                const position = maze.cells[player.position];
                if (Direction.north.isPath(position)) {
                    player.sub(maze.width);
                    playNew(moveSound);
                }
            }
            if (rl.isKeyPressed(.s)) {
                playerRunTime = PLAYER_RUN_TILL;
                const position = maze.cells[player.position];
                if (Direction.south.isPath(position)) {
                    player.add(maze.width);
                    playNew(moveSound);
                }
            }
            if (rl.isKeyPressed(.d)) {
                playerRunTime = PLAYER_RUN_TILL;
                const position = maze.cells[player.position];
                if (Direction.east.isPath(position)) {
                    player.add(1);
                    playNew(moveSound);
                }
            }
            if (rl.isKeyPressed(.a)) {
                playerRunTime = PLAYER_RUN_TILL;
                const position = maze.cells[player.position];
                if (Direction.west.isPath(position)) {
                    player.sub(1);
                    playNew(moveSound);
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
            playNew(retrySound);
            rl.stopMusicStream(music);
            rl.playMusicStream(music);

            const newMaze = try Maze.random(allocator, rand);
            maze.deinit(allocator);
            maze = newMaze;

            cellSize = fitCell(sw, sh, maze.width, maze.height);

            const newMazeTexture = try maze.bake(cellSize, WALL_SIZE);
            mazeTexture.unload();
            mazeTexture = newMazeTexture;

            const newPlayer = try Player.init(maze.start, Character.random(rand));
            player.deinit();
            player = newPlayer;

            playerIdle.texture = player.texture;
            playerRunning.texture = player.texture;
            timer.reset();
        }

        const isPlayerAtStart = player.position == maze.start;
        const isPlayerAtEnd = player.position == maze.end;

        if (isPlayerAtStart and timer.start != null) timer.reset();
        if (!isPlayerAtStart and timer.start == null) timer.begin();
        if (isPlayerAtEnd) timer.stop();

        // Calculations happen after input is done, so the latest stuff can be shown in current frame
        if (rl.isWindowResized()) {
            sw = rl.getScreenWidth();
            sh = rl.getScreenHeight();

            cellSize = fitCell(sw, sh, maze.width, maze.height);

            const new = try maze.bake(cellSize, WALL_SIZE);
            mazeTexture.unload();
            mazeTexture = new;
        }

        const tex = mazeTexture.texture;

        const width: f32 = @floatFromInt(tex.width);
        const height: f32 = @floatFromInt(tex.height);

        const availW: f32 = @floatFromInt(sw);
        const availH: f32 = @floatFromInt(sh);

        // We round to fix the subpixel fringing
        const offX = @round((availW - width) / 2);
        const offY = @round((availH - height) / 2);

        const source: rl.Rectangle = .init(0, 0, width, -height);
        const dist: rl.Rectangle = .init(offX, offY, width, height);

        const playerX: f32 = @floatFromInt(@as(i32, @intCast(player.x(maze.width))) * cellSize);
        const playerY: f32 = @floatFromInt(@as(i32, @intCast(player.y(maze.width))) * cellSize);

        const playerRec: rl.Rectangle = .init(
            offX + playerX,
            offY + playerY,
            @floatFromInt(cellSize),
            @floatFromInt(cellSize),
        );

        // Final draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.ray_white);

        rl.drawTexturePro(tex, source, dist, .zero(), 0, .white);

        if (playerRunTime > 0) {
            playerRunning.draw(playerRec, .zero(), .white);
        } else {
            playerIdle.draw(playerRec, .zero(), .white);
        }

        if (isPlayerAtEnd) {
            rl.drawRectangle(0, 0, sw, sh, .init(255, 255, 255, 155));

            if (timer.duration) |d| {
                var buf: [64]u8 = undefined;
                const timeText = try std.fmt.bufPrintZ(&buf, "Finished in {f}", .{d});
                rl.drawText(timeText, 400, @divTrunc(sh, 2) - 60, 24, .black);
            }

            rl.drawText("[r]: Refresh [q]: Quit", 400, @divTrunc(sh, 2) - 24, 24, .black);
        } else {
            rl.drawText("[r]: Refresh [q]: Quit", 20, 20, 24, .black);
        }
    }
}

inline fn playNew(sound: rl.Sound) void {
    if (rl.isSoundPlaying(sound)) rl.stopSound(sound);
    rl.playSound(sound);
}

inline fn fitCell(sw: i32, sh: i32, mazeW: u16, mazeH: u16) i32 {
    const availW: f32 = @floatFromInt(sw);
    const availH: f32 = @floatFromInt(sh);
    const cell = @min(
        availW * (1 - 2 * PADDING) / @as(f32, @floatFromInt(mazeW)),
        availH * (1 - 2 * PADDING) / @as(f32, @floatFromInt(mazeH)),
    );
    return @intFromFloat(@max(cell, 4)); // floor, min 4px
}
