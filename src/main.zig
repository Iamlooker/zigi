const std = @import("std");
const rl = @import("raylib");

pub fn main() anyerror!void {
    const screenWidth = 1000;
    const screenHeight = 800;

    rl.initWindow(screenWidth, screenHeight, "zigi");
    defer rl.closeWindow();

    const speed = 4.0;
    const radius = 15;
    const endgameText = "You lost! Press [Enter] to restart";
    const textWidth = rl.measureText(endgameText, 32);
    const textX = @divTrunc(screenWidth - textWidth, 2);

    const eliminationRec: rl.Rectangle = .init(0, 4 * screenHeight / 5, screenWidth, screenHeight / 5);

    const dBallX = screenWidth / 2;
    const dBallY = screenHeight / 2;
    var ballPos: rl.Vector2 = .init(dBallX, dBallY);

    rl.setTargetFPS(240);

    while (!rl.windowShouldClose()) {
        var isLost = rl.checkCollisionCircleRec(ballPos, radius, eliminationRec);
        if (rl.isKeyDown(.q)) break;
        if (isLost) {
            if (rl.isKeyDown(.enter)) {
                ballPos = .init(dBallX, dBallY);
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
            rl.drawText(endgameText, textX, screenHeight / 3, 32, .red);
        }

        rl.endDrawing();
    }
}
