const rl = @import("raylib");
const std = @import("std");

const input = @import("input.zig");
const math = @import("math.zig");
const tiled = @import("tiled.zig");

const Vec = math.Vec;

const World = struct {
    inputManager: input.InputManager,
    player: Player,
    asdf: rl.Rectangle,
    map: tiled.TiledMap,

    pub fn new(allocator: std.mem.Allocator, project_root: std.fs.Dir) !World {
        const inputManager = input.InputManager.new(.{
            rl.KeyboardKey.key_left,
            rl.KeyboardKey.key_down,
            rl.KeyboardKey.key_right,
            rl.KeyboardKey.key_space,
        });
        const player = Player.new(&inputManager);

        // TODO: try out with mapPath like this:
        const mapPath = try project_root.realpathAlloc(allocator, "./assets/kenney-pixel-platformer/Tiled/tilemap-example-a.tmx");
        // const mapPath = try project_root.realpathAlloc(allocator, "./assets/maps/home.tmx");
        defer allocator.free(mapPath);
        const map = try tiled.TiledMap.new(
            allocator,
            mapPath,
        );

        return World{
            .inputManager = inputManager,
            .player = player,
            .asdf = rl.Rectangle{
                .x = 100,
                .y = 400,
                .width = 100,
                .height = 40,
            },
            .map = map,
        };
    }

    pub fn deinit(self: *World) void {
        self.map.deinit();
    }

    pub fn render(self: *const World) void {
        self.player.render();
        self.map.render();
    }

    pub fn update(self: *World, frameTime: f32) void {
        self.player.update(self, frameTime);
    }
};

const Player = struct {
    const acceleration: f32 = 2000;
    const maxSpeed: f32 = 500;

    velocity: Vec,
    position: Vec,
    size: Vec,
    inputManager: *const input.InputManager,

    pub fn new(inputManager: *const input.InputManager) Player {
        return Player{
            .velocity = Vec.zero,
            .position = Vec.zero,
            .size = Vec.new(50, 50),
            .inputManager = inputManager,
        };
    }

    pub fn render(self: *const Player) void {
        rl.drawRectangleV(self.position.as_vector2(), self.size.as_vector2(), rl.Color.red);
    }

    pub fn update(self: *Player, world: *World, frameTime: f32) void {
        var direction = Vec.zero;

        const leftPressed = rl.isKeyDown(rl.KeyboardKey.key_left);
        const rightPressed = rl.isKeyDown(rl.KeyboardKey.key_right);
        if (leftPressed and !rightPressed) {
            direction = direction.add(Vec.left);
        } else if (!leftPressed and rightPressed) {
            direction = direction.add(Vec.right);
        }
        if (self.velocity.x != 0 and (direction.x == 0 or (direction.x != 0 and math.sign(direction.x) != math.sign(self.velocity.x)))) {
            direction.x += -self.velocity.normalized().x;
        }

        const upPressed = rl.isKeyDown(rl.KeyboardKey.key_up);
        const downPressed = rl.isKeyDown(rl.KeyboardKey.key_down);
        if (upPressed and !downPressed) {
            direction = direction.add(Vec.up);
        } else if (!upPressed and downPressed) {
            direction = direction.add(Vec.down);
        }
        if (self.velocity.y != 0 and (direction.y == 0 or (direction.y != 0 and math.sign(direction.y) != math.sign(self.velocity.y)))) {
            direction.y += -self.velocity.normalized().y;
        }

        self.velocity = self.velocity.add(direction.mul(acceleration).mul(frameTime));
        const mag = self.velocity.mag();
        if (mag > maxSpeed) {
            self.velocity = self.velocity.mul(maxSpeed / mag);
        }
        if (!leftPressed and !rightPressed and @abs(self.velocity.x * frameTime) < 1) {
            self.velocity.x = 0;
        }
        if (!upPressed and !downPressed and @abs(self.velocity.y * frameTime) < 1) {
            self.velocity.y = 0;
        }

        const collides = rl.checkCollisionRecs(
            rl.Rectangle{
                .x = self.position.x,
                .y = self.position.y,
                .width = 50,
                .height = 50,
            },
            world.asdf,
        );

        if (collides) {
            const midPos = self.position.add(Vec.new(25, 25));
            const theirMidPos = Vec.new(world.asdf.x + (world.asdf.width / 2), world.asdf.y + (world.asdf.height / 2));
            const diff = midPos.sub(theirMidPos);
            const normalizedDiff = Vec.new(diff.x / (25 + world.asdf.width / 2), diff.y / (25 + world.asdf.height / 2)).normalized();

            if (@abs(normalizedDiff.x) >= @abs(normalizedDiff.y)) {
                // Primarily horizontal collision.
                if (midPos.x < theirMidPos.x) {
                    self.position.x = world.asdf.x - 50;
                } else {
                    self.position.x = world.asdf.x + world.asdf.width;
                }
                self.velocity.x = -self.velocity.x * 0.5;
            } else {
                // Primarily vertical collision.
                if (midPos.y < theirMidPos.y) {
                    self.position.y = world.asdf.y - 50;
                } else {
                    self.position.y = world.asdf.y + world.asdf.height;
                }
                self.velocity.y = -self.velocity.y * 0.5;
            }
        } else {
            self.position = self.position.add(self.velocity.mul(frameTime));
        }
    }
};

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    rl.initWindow(640, 480, "raylib");
    defer rl.closeWindow();

    const allocator: std.mem.Allocator = std.heap.page_allocator;
    const projectRoot = std.fs.cwd();
    var world = try World.new(allocator, projectRoot);
    defer world.deinit();

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
        world.render();
        rl.drawRectangleRec(asdf, rl.Color.blue);
        rl.drawCircle(asdf.x, asdf.y, 10, rl.Color.white);

        const frameTime = rl.getFrameTime();
        world.update(frameTime);
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
