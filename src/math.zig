const rl = @import("raylib");

pub const Vec = struct {
    x: f32,
    y: f32,

    pub inline fn new(x: f32, y: f32) Vec {
        return Vec{
            .x = x,
            .y = y,
        };
    }

    pub const zero = Vec.new(0, 0);
    pub const left = Vec.new(-1, 0);
    pub const right = Vec.new(1, 0);
    pub const up = Vec.new(0, -1);
    pub const down = Vec.new(0, 1);

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

pub fn sign(value: f32) i32 {
    if (value < 0) {
        return -1;
    }
    if (value > 0) {
        return 1;
    }
    return 0;
}
