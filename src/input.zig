const rl = @import("raylib");

pub const Input = enum(usize) {
    left,
    down,
    right,
    jump,
};

const numInputs = @typeInfo(Input).Enum.fields.len;

pub const InputManager = struct {
    inputMap: [numInputs]rl.KeyboardKey,

    pub fn new(inputMap: [numInputs]rl.KeyboardKey) InputManager {
        return InputManager{
            .inputMap = inputMap,
        };
    }

    pub fn is_pressed(self: *InputManager, input: Input) bool {
        return rl.isKeyDown(self.inputMap[input]);
    }
};
