const std = @import("std");
const rl = @import("raylib");

pub const Player = struct {
    position: u32,
    texture: rl.Texture2D,

    const Self = @This();

    pub fn init(
        position: u32,
        character: Character,
    ) !Self {
        return .{
            .position = position,
            .texture = try rl.loadTexture(character.path()),
        };
    }

    pub fn deinit(self: Self) void {
        self.texture.unload();
    }

    pub fn x(self: Self, mazeWidth: u16) u32 {
        return self.position % mazeWidth;
    }

    pub fn y(self: Self, mazeWidth: u16) u32 {
        return self.position / mazeWidth;
    }

    pub fn add(self: *Self, amount: u32) void {
        self.position += amount;
    }

    pub fn sub(self: *Self, amount: u32) void {
        self.position -= amount;
    }
};

pub const Character = enum {
    doux,
    mort,
    tard,
    vita,
    pub fn random(rand: std.Random) Character {
        return rand.enumValue(Character);
    }

    pub fn path(self: Character) [:0]const u8 {
        return switch (self) {
            .doux => "resources/sprites/doux.png",
            .mort => "resources/sprites/mort.png",
            .tard => "resources/sprites/tard.png",
            .vita => "resources/sprites/vita.png",
        };
    }
};
