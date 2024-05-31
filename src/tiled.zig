const rl = @import("raylib");
const std = @import("std");

const must = @import("must.zig").must;
const xml = @import("xml.zig");

const c = @cImport({
    @cInclude("stdlib.h");
    @cInclude("tmx.h");
    @cInclude("tmx_utils.h");
});

pub const MapError = error{
    Unknown,
    InvalidArgument,
    AllocationError,
    NoAccess,
    FileNotFound,
    FileFormatError,
    CompressionError,
    FunctionalityDisabled,
    Base64BadData,
    ZlibBadData,
    XMLBadData,
    ZstdBadData,
    CSVBadData,
    MissingElement,
};

export fn globalTMXLoadImage(path: [*c]const u8) ?*anyopaque {
    const texture2D: *rl.Texture2D = @ptrCast(@alignCast(c.malloc(@sizeOf(rl.Texture2D)) orelse return null));
    texture2D.* = rl.loadTexture(std.mem.span(path));
    return texture2D;
}

export fn globalTMXFreeImage(ptr: ?*anyopaque) void {
    c.free(ptr);
}

pub const Map = struct {
    tmx_map: *c.tmx_map,

    pub fn init(path: []const u8) !Map {
        if (c.tmx_img_load_func == null) {
            c.tmx_img_load_func = globalTMXLoadImage;
        }
        if (c.tmx_img_free_func == null) {
            c.tmx_img_free_func = globalTMXFreeImage;
        }
        const tmx_map: *c.tmx_map = c.tmx_load(@ptrCast(path)) orelse return getCurrentError();
        return Map{
            .tmx_map = tmx_map,
        };
    }

    pub fn deinit(self: *Map) void {
        c.tmx_map_free(self.tmx_map);
    }

    pub fn render(self: *const Map) void {
        var maybeLayer: ?*c.tmx_layer = self.tmx_map.ly_head;
        while (maybeLayer) |layer| {
            defer maybeLayer = layer.next;
            if (layer.visible == 0) {
                continue;
            }

            switch (layer.type) {
                c.L_GROUP => @panic("todo"),
                c.L_OBJGR => @panic("todo"),
                c.L_IMAGE => @panic("todo"),
                c.L_LAYER => self.renderTileLayer(layer),
                else => @panic("Unrecognized layer type"),
            }
        }
    }

    fn renderTileLayer(self: *const Map, layer: *c.tmx_layer) void {
        for (0..self.tmx_map.width*self.tmx_map.tile_height) |i| {
            const gid = layer.content.gids[i];
            if (gid < 0 or gid > self.tmx_map.tilecount) {
                // TODO: why do these exist in the map? what are we supposed to do with them?
                continue;
            }

            if (self.tmx_map.tiles[gid] == null) {
                continue;
            }
            const tile = self.tmx_map.tiles[gid].*;
            const tileset = tile.tileset;

            var maybeTexture: ?*rl.Texture2D = null;
            if (tile.image) |img| {
                maybeTexture = @ptrCast(@alignCast(img.*.resource_image));
            } else {
                maybeTexture = @ptrCast(@alignCast(tileset.*.image.*.resource_image));
            }
            const texture: *rl.Texture2D = maybeTexture orelse @panic("Texture should have been set on tile or tileset, but it was not.");

            const source = rl.Rectangle{
                .x = @floatFromInt(tile.ul_x),
                .y = @floatFromInt(tile.ul_y),
                .width = @floatFromInt(tileset.*.tile_width),
                .height = @floatFromInt(tileset.*.tile_height),
            };

            const col = i % self.tmx_map.width;
            const row = i / self.tmx_map.height;
            const position = rl.Vector2{
                .x = @floatFromInt(col * tileset.*.tile_width),
                .y = @floatFromInt(row * tileset.*.tile_height),
            };
            rl.drawTextureRec(
                texture.*,
                source,
                position,
                rl.Color.white,
            );
        }
    }
};

fn getCurrentError() MapError {
    switch (c.tmx_errno) {
        c.E_UNKN => return MapError.Unknown,
        c.E_INVAL => return MapError.InvalidArgument,
        c.E_ALLOC => return MapError.AllocationError,
        c.E_ACCESS => return MapError.NoAccess,
        c.E_NOENT => return MapError.FileNotFound,
        c.E_FORMAT => return MapError.FileFormatError,
        c.E_ENCCMP => return MapError.CompressionError,
        c.E_FONCT => return MapError.FunctionalityDisabled,
        c.E_BDATA => return MapError.Base64BadData,
        c.E_ZDATA => return MapError.ZlibBadData,
        c.E_XDATA => return MapError.XMLBadData,
        c.E_ZSDATA => return MapError.ZstdBadData,
        c.E_CDATA => return MapError.CSVBadData,
        c.E_MISSEL => return MapError.MissingElement,
        else => @panic("getCurrentError() called with unknown or unset TMX error."),
    }
}
