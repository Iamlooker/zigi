const std = @import("std");
const rl = @import("raylib");

pub fn main() anyerror!void {
    const screenWidth = 1000;
    const screenHeight = 800;

    rl.initWindow(screenWidth, screenHeight, "zigi");
    defer rl.closeWindow();

    const speed = 4.0;
    const radius = 15;

    var ballPos: rl.Vector2 = .init(screenWidth / 2, screenHeight / 2);
    const eliminationRec: rl.Rectangle = .init(0, 4 * screenHeight / 5, screenWidth, screenHeight / 5);

    rl.setTargetFPS(240);

    while (!rl.windowShouldClose()) {
        var isLost = rl.checkCollisionCircleRec(ballPos, radius, eliminationRec);
        if (isLost) {
            if (rl.isKeyDown(.enter)) {
                ballPos = .init(screenWidth / 2, screenHeight / 2);
                isLost = false;
            }
        } else {
            const finalSpeed = rl.getFrameTime() * 60 * speed;
            if (rl.isKeyDown(.w) and ballPos.y > 0) ballPos.y -= finalSpeed;
            if (rl.isKeyDown(.s) and ballPos.y < screenHeight) ballPos.y += finalSpeed;
            if (rl.isKeyDown(.a) and ballPos.x > 0) ballPos.x -= finalSpeed;
            if (rl.isKeyDown(.d) and ballPos.x < screenWidth) ballPos.x += finalSpeed;
        }

        rl.beginDrawing();
        rl.clearBackground(.light_gray);

        rl.drawCircleV(ballPos, radius, .dark_blue);

        rl.drawRectangleRec(eliminationRec, if (isLost) .dark_gray else .red);

        if (isLost) {
            // Need to find a way to actually center this guy horizontally
            rl.drawText("You lost! Press [Enter] to restart", (screenWidth / 5) + 20, screenHeight / 3, 32, .red);
        }

        rl.endDrawing();
    }
}
