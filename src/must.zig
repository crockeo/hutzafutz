pub const MustError = error{
    WasNull,
};

pub fn must(comptime T: anytype, nullableT: ?T) !T {
    if (nullableT) |t| {
        return t;
    }
    return MustError.WasNull;
}
