const std = @import("std");
const rl = @import("raylib");

pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 450;
    const radius = 25;

    const minXConstraint = radius;
    const maxXConstraint = screenWidth - radius;
    // lock to bottom 3/4
    const minYConstraint = (screenHeight / 4) + radius;
    const maxYConstraint = screenHeight - radius;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow();

    var ballX: i32 = screenWidth / 2;
    var ballY: i32 = 3 * screenHeight / 4;

    rl.setTargetFPS(240);

    while (!rl.windowShouldClose()) {
        // Could have used: rl.checkCollisionCircleLine(center: Vector2, radius: f32, p1: Vector2, p2: Vector2)
        if ((rl.isKeyDown(.up) or rl.isKeyDown(.w)) and ballY > minYConstraint) ballY -= 2.0;
        if ((rl.isKeyDown(.down) or rl.isKeyDown(.s)) and ballY < maxYConstraint) ballY += 2.0;
        if ((rl.isKeyDown(.left) or rl.isKeyDown(.a)) and ballX > minXConstraint) ballX -= 2.0;
        if ((rl.isKeyDown(.right) or rl.isKeyDown(.d)) and ballX < maxXConstraint) ballX += 2.0;

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.ray_white);

        rl.drawCircle(ballX, ballY, radius, .dark_gray);

        rl.drawRectangle(0, 0, screenWidth, screenHeight / 4, rl.Color.init(255, 179, 179, 255));
    }
}
