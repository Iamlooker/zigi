const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");

const a = @import("sprite.zig");
const Sprite = a.Sprite;

const m = @import("maze.zig");
const Maze = m.Maze;
const Direction = m.Direction;

const p = @import("player.zig");
const Player = p.Player;
const Character = p.Character;

const config = @import("config.zig");
const CELL_SIZE = config.CELL_SIZE;
const SPRITE_SIZE = config.SPRITE_SIZE;
const PADDING = config.PADDING;

pub fn main(init: std.process.Init) anyerror!void {
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

    var sw: i32 = 1000;
    var sh: i32 = 1000;

    var layout = fit(sw, sh, maze);

    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(sw, sh, "zigi");
    defer rl.closeWindow();

    var mazeTexture = try maze.bake();
    defer mazeTexture.unload();

    rl.initAudioDevice();
    defer rl.closeAudioDevice();

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

    var player: Player = try .init(maze.start, Character.random(rand));
    defer player.deinit();

    const SPRITE_FPS = 15;

    const IDLE_FRAMES = 4;

    var playerIdle: Sprite = try .init(allocator, player.texture, SPRITE_FPS, 0, IDLE_FRAMES, SPRITE_SIZE);
    defer playerIdle.deinit(allocator);

    const RUNNING_FRAMES = 6;
    var playerRunning: Sprite = try .init(allocator, player.texture, SPRITE_FPS, IDLE_FRAMES, RUNNING_FRAMES, SPRITE_SIZE);
    defer playerRunning.deinit(allocator);

    const PLAYER_RUN_TILL = 0.2;
    var spriteIdleTimer: f32 = 0;

    var timer: Timer = .{};

    rl.setTargetFPS(240);

    while (!rl.windowShouldClose()) {
        rl.updateMusicStream(music);

        const nsw = rl.getScreenWidth();
        const nsh = rl.getScreenHeight();
        if (sw != nsw or sh != nsh) {
            sw = nsw;
            sh = nsh;

            layout = fit(sw, sh, maze);
        }

        const isPlayerAtStart = player.position == maze.start;
        const isPlayerAtEnd = player.position == maze.end;

        // Movement before state calculation
        if (!isPlayerAtEnd) {
            if (rl.isKeyPressed(.w)) {
                spriteIdleTimer = PLAYER_RUN_TILL;
                const position = maze.cells[player.position];
                if (Direction.north.isPath(position)) {
                    player.sub(maze.width);
                    playNew(moveSound);
                }
            }
            if (rl.isKeyPressed(.s)) {
                spriteIdleTimer = PLAYER_RUN_TILL;
                const position = maze.cells[player.position];
                if (Direction.south.isPath(position)) {
                    player.add(maze.width);
                    playNew(moveSound);
                }
            }
            if (rl.isKeyPressed(.d)) {
                spriteIdleTimer = PLAYER_RUN_TILL;
                const position = maze.cells[player.position];
                if (Direction.east.isPath(position)) {
                    player.add(1);
                    playNew(moveSound);
                }
            }
            if (rl.isKeyPressed(.a)) {
                spriteIdleTimer = PLAYER_RUN_TILL;
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

            const newMazeTexture = try maze.bake();
            mazeTexture.unload();
            mazeTexture = newMazeTexture;

            layout = fit(sw, sh, maze);

            const newPlayer = try Player.init(maze.start, Character.random(rand));
            player.deinit();
            player = newPlayer;

            playerIdle.texture = player.texture;
            playerRunning.texture = player.texture;
            timer.reset();
        }

        const playerX: f32 = @floatFromInt(player.x(maze.width) * CELL_SIZE);
        const playerY: f32 = @floatFromInt(player.y(maze.width) * CELL_SIZE);

        if (!isPlayerAtStart) timer.begin(init.io);
        if (isPlayerAtEnd) timer.stop(init.io);

        if (spriteIdleTimer > 0) spriteIdleTimer -= rl.getFrameTime();

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.light_gray);

        const tex = mazeTexture.texture;
        const texW: f32 = @floatFromInt(tex.width);
        const texH: f32 = @floatFromInt(tex.height);
        rl.drawTexturePro(
            tex,
            .init(0, 0, texW, -texH),
            .init(layout.x, layout.y, texW * layout.scale, texH * layout.scale),
            .zero(),
            0,
            .white,
        );

        const px = layout.x + playerX * layout.scale;
        const py = layout.y + playerY * layout.scale;
        const ps = SPRITE_SIZE * layout.scale;
        if (spriteIdleTimer > 0) {
            playerRunning.draw(.init(px, py, ps, ps), .zero(), .white);
        } else {
            playerIdle.draw(.init(px, py, ps, ps), .zero(), .white);
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

const Timer = struct {
    start: ?std.Io.Timestamp = null,
    duration: ?std.Io.Duration = null,

    fn begin(self: *Timer, io: std.Io) void {
        if (self.start == null) self.start = std.Io.Clock.now(.awake, io);
    }
    fn stop(self: *Timer, io: std.Io) void {
        if (self.duration != null) return;
        const s = self.start orelse return; // skip, no quit
        self.duration = s.durationTo(std.Io.Clock.now(.awake, io));
    }
    fn reset(self: *Timer) void {
        self.start = null;
        self.duration = null;
    }
};

inline fn playNew(sound: rl.Sound) void {
    if (rl.isSoundPlaying(sound)) rl.stopSound(sound);
    rl.playSound(sound);
}

const Layout = struct { scale: f32, x: f32, y: f32 };

inline fn fit(sw: i32, sh: i32, maze: Maze) Layout {
    const mw: f32 = @floatFromInt(maze.width * CELL_SIZE);
    const mh: f32 = @floatFromInt(maze.height * CELL_SIZE);
    const fsw: f32 = @floatFromInt(sw);
    const fsh: f32 = @floatFromInt(sh);
    const availW = fsw - 2 * PADDING;
    const availH = fsh - 2 * PADDING;
    const scale = @min(availW / mw, availH / mh);
    return .{
        .scale = scale,
        .x = (fsw - mw * scale) / 2,
        .y = (fsh - mh * scale) / 2,
    };
}
