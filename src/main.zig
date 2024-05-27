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

    pub inline fn as_vector2(self: Vec) rl.Vector2 {
        return rl.Vector2{
            .x = self.x,
            .y = self.y,
        };
    }
};

fn sign(value: f32) i32 {
    if (value < 0) {
        return -1;
    }
    if (value > 0) {
        return 1;
    }
    return 0;
}

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    rl.initWindow(640, 480, "raylib");
    defer rl.closeWindow();

    const acceleration: f32 = 2000;
    const maxSpeed: f32 = 500;
    var velocity: Vec = Vec.zero;
    var position: Vec = Vec.zero;

    const asdf = rl.Rectangle{
        .x = 100,
        .y = 400,
        .width = 100,
        .height = 40,
    };

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
        rl.drawCircle(@intFromFloat(position.x), @intFromFloat(position.y), 10, rl.Color.orange);

        rl.drawRectangleRec(asdf, rl.Color.blue);
        rl.drawCircle(asdf.x, asdf.y, 10, rl.Color.white);

        const frameTime = rl.getFrameTime();

        var direction = Vec.zero;

        const leftPressed = rl.isKeyDown(rl.KeyboardKey.key_left);
        const rightPressed = rl.isKeyDown(rl.KeyboardKey.key_right);
        if (leftPressed and !rightPressed) {
            direction = direction.add(Vec.left);
        } else if (!leftPressed and rightPressed) {
            direction = direction.add(Vec.right);
        }
        if (velocity.x != 0 and (direction.x == 0 or (direction.x != 0 and sign(direction.x) != sign(velocity.x)))) {
            direction.x += -velocity.normalized().x;
        }

        const upPressed = rl.isKeyDown(rl.KeyboardKey.key_up);
        const downPressed = rl.isKeyDown(rl.KeyboardKey.key_down);
        if (upPressed and !downPressed) {
            direction = direction.add(Vec.up);
        } else if (!upPressed and downPressed) {
            direction = direction.add(Vec.down);
        }
        if (velocity.y != 0 and (direction.y == 0 or (direction.y != 0 and sign(direction.y) != sign(velocity.y)))) {
            direction.y += -velocity.normalized().y;
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

        const collides = rl.checkCollisionRecs(
            rl.Rectangle{
                .x = position.x,
                .y = position.y,
                .width = 50,
                .height = 50,
            },
            asdf,
        );
        if (collides) {
            const midPos = position.add(Vec.new(25, 25));
            const theirMidPos = Vec.new(asdf.x + (asdf.width / 2), asdf.y + (asdf.height / 2));
            const diff = midPos.sub(theirMidPos);
            const normalizedDiff = Vec.new(diff.x / (25 + asdf.width / 2), diff.y / (25 + asdf.height / 2)).normalized();

            if (@abs(normalizedDiff.x) >= @abs(normalizedDiff.y)) {
                // Primarily horizontal collision.
                if (midPos.x < theirMidPos.x) {
                    position.x = asdf.x - 50;
                } else {
                    position.x = asdf.x + asdf.width;
                }
                velocity.x = 0;
            } else {
                // Primarily vertical collision.
                if (midPos.y < theirMidPos.y) {
                    position.y = asdf.y - 50;
                } else {
                    position.y = asdf.y + asdf.height;
                }
                velocity.y = 0;
            }
        } else {
            position = position.add(velocity.mul(frameTime));
        }
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
