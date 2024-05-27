const rl = @import("raylib");
const std = @import("std");

const Vec = struct {
    x: f32,
    y: f32,

    pub inline fn new(x: f32, y: f32) Vec {
        return Vec{
            .x = x,
            .y = y,
        };
    }

    const zero = Vec.new(0, 0);
    const left = Vec.new(-1, 0);
    const right = Vec.new(1, 0);
    const up = Vec.new(0, -1);
    const down = Vec.new(0, 1);

    pub inline fn add(self: Vec, other: Vec) Vec {
        return Vec.new(self.x + other.x, self.y + other.y);
    }

    pub inline fn inverse(self: Vec) Vec {
        return Vec.new(-self.x, -self.y);
    }

    pub inline fn sub(self: Vec, other: Vec) Vec {
        return self.add(other.inverse());
    }

    pub inline fn mul(self: Vec, magnitude: f32) Vec {
        return Vec.new(self.x * magnitude, self.y * magnitude);
    }

    pub inline fn magSqrd(self: Vec) f32 {
        return self.x * self.x + self.y * self.y;
    }

    pub inline fn mag(self: Vec) f32 {
        return @sqrt(self.magSqrd());
    }

    pub inline fn normalized(self: Vec) Vec {
        const magnitude = self.mag();
        return Vec.new(self.x / magnitude, self.y / magnitude);
    }
};

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    rl.initWindow(640, 480, "raylib");
    defer rl.closeWindow();

    const acceleration: f32 = 2000;
    const maxSpeed: f32 = 500;
    var velocity: Vec = Vec.zero;
    var position: Vec = Vec.zero;

    rl.setTargetFPS(60);
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.white);
        rl.drawRectangle(
            @intFromFloat(position.x),
            @intFromFloat(position.y),
            50,
            50,
            rl.Color.red,
        );

        const frameTime = rl.getFrameTime();

        var direction = Vec.zero;

        const leftPressed = rl.isKeyDown(rl.KeyboardKey.key_left);
        const rightPressed = rl.isKeyDown(rl.KeyboardKey.key_right);
        if (leftPressed and !rightPressed) {
            direction = direction.add(Vec.left);
        } else if (!leftPressed and rightPressed) {
            direction = direction.add(Vec.right);
        } else if (velocity.x != 0) {
            direction.x = -velocity.normalized().x;
        }

        const upPressed = rl.isKeyDown(rl.KeyboardKey.key_up);
        const downPressed = rl.isKeyDown(rl.KeyboardKey.key_down);
        if (upPressed and !downPressed) {
            direction = direction.add(Vec.up);
        } else if (!upPressed and downPressed) {
            direction = direction.add(Vec.down);
        } else if (velocity.y != 0) {
            direction.y = -velocity.normalized().y;
        }

        velocity = velocity.add(direction.mul(acceleration).mul(frameTime));
        const mag = velocity.mag();
        if (mag > maxSpeed) {
            velocity = velocity.mul(maxSpeed / mag);
        }
        if (!leftPressed and !rightPressed and @abs(velocity.x * frameTime) < 1) {
            velocity.x = 0;
        }
        if (!upPressed and !downPressed and @abs(velocity.y * frameTime) < 1) {
            velocity.y = 0;
        }

        position = position.add(velocity.mul(frameTime));
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}