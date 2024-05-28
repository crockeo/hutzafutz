const rl = @import("raylib");
const std = @import("std");

const must = @import("must.zig").must;
const xml = @import("xml.zig");

const TiledMapError = error{
    InvalidFormat,
};

pub const TiledMap = struct {
    tilesets: std.ArrayList(Tileset),
    layers: std.ArrayList(Layer),

    pub fn new(allocator: std.mem.Allocator, path: []const u8) !TiledMap {
        var file = try std.fs.openFileAbsolute(path, std.fs.File.OpenFlags{});
        defer file.close();

        const contents = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(contents);

        const document = try xml.parse(allocator, contents);
        defer document.deinit();

        var tilesets = std.ArrayList(Tileset).init(allocator);
        {
            var tilesetElements = document.root.findChildrenByTag("tileset");
            while (tilesetElements.next()) |tilesetElement| {
                try tilesets.append(try Tileset.fromXML(allocator, path, tilesetElement));
            }
        }

        var layers = std.ArrayList(Layer).init(allocator);
        {
            var layerElements = document.root.findChildrenByTag("layer");
            while (layerElements.next()) |layerElement| {
                try layers.append(try Layer.fromXML(allocator, layerElement));
            }
        }

        return TiledMap{
            .tilesets = tilesets,
            .layers = layers,
        };
    }

    pub fn deinit(self: *TiledMap) void {
        for (self.tilesets.items) |tileset| {
            tileset.deinit();
        }
        self.tilesets.deinit();

        for (self.layers.items) |layer| {
            layer.deinit();
        }
        self.layers.deinit();
    }

    pub fn render(self: *TiledMap) void {
        for (self.layers.items) |item| {
            item.render(&self.tilesets.items[0]);
        }
    }
};

const Tileset = struct {
    tileWidth: i64,
    tileHeight: i64,
    columns: i64,
    texture: rl.Texture2D,

    fn fromXML(allocator: std.mem.Allocator, path: []const u8, tileset: *const xml.Element) !Tileset {
        const source = try std.fs.path.resolve(
            allocator,
            &[_][]const u8{
                try must([]const u8, std.fs.path.dirname(path)),
                try must([]const u8, tileset.getAttribute("source")),
            },
        );
        defer allocator.free(source);

        var file = try std.fs.openFileAbsolute(source, std.fs.File.OpenFlags{});
        defer file.close();

        const contents = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(contents);

        const document = try xml.parse(allocator, contents);
        defer document.deinit();

        const tileWidth = try std.fmt.parseInt(i64, try must([]const u8, document.root.getAttribute("tilewidth")), 10);
        const tileHeight = try std.fmt.parseInt(i64, try must([]const u8, document.root.getAttribute("tileheight")), 10);
        const columns = try std.fmt.parseInt(i64, try must([]const u8, document.root.getAttribute("columns")), 10);


        const imageElement = try must(*xml.Element, document.root.findChildByTag("image"));
        const imageSource = try std.fs.path.resolve(
            allocator,
            &[_][]const u8{
                try must([]const u8, std.fs.path.dirname(source)),
                try must([]const u8, imageElement.getAttribute("source")),
            },
        );
        defer allocator.free(imageSource);

        const texture = rl.loadTexture(@ptrCast(imageSource));
        return Tileset{
            .tileWidth = tileWidth,
            .tileHeight = tileHeight,
            .columns = columns,
            .texture = texture,
        };
    }

    fn deinit(self: Tileset) void {
        rl.unloadTexture(self.texture);
    }

    fn render(self: Tileset, tile: i64, offset: rl.Vector2) void {
        const col = @mod(tile - 1, self.columns);
        const row = @divTrunc(tile - 1, self.columns);
        rl.drawTextureRec(
            self.texture,
            rl.Rectangle{
                .x = @floatFromInt(col * self.tileWidth),
                .y = @floatFromInt(row * self.tileHeight),
                .width = @floatFromInt(self.tileWidth),
                .height = @floatFromInt(self.tileHeight),
            },
            offset,
            rl.Color.white,
        );
    }
};

const Layer = struct {
    chunks: std.ArrayList(Chunk),

    fn fromXML(allocator: std.mem.Allocator, layer: *const xml.Element) !Layer {
        const data = layer.findChildByTag("data") orelse return TiledMapError.InvalidFormat;
        const encoding = data.getAttribute("encoding") orelse return TiledMapError.InvalidFormat;
        if (!std.mem.eql(u8, encoding, "csv")) {
            return TiledMapError.InvalidFormat;
        }

        var chunks = std.ArrayList(Chunk).init(allocator);
        {
            var chunkElements = data.findChildrenByTag("chunk");
            while (chunkElements.next()) |chunkElement| {
                try chunks.append(try Chunk.fromXML(allocator, chunkElement));
            }
        }

        return Layer{ .chunks = chunks };
    }

    fn deinit(self: Layer) void {
        for (self.chunks.items) |chunk| {
            chunk.deinit();
        }
        self.chunks.deinit();
    }

    fn render(self: Layer, tileset: *Tileset) void {
        for (self.chunks.items) |chunk| {
            chunk.render(tileset);
        }
    }
};

const Chunk = struct {
    x: i64,
    y: i64,
    width: i64,
    height: i64,
    tiles: std.ArrayList(usize),

    fn fromXML(allocator: std.mem.Allocator, chunk: *xml.Element) !Chunk {
        const x = try std.fmt.parseInt(
            i64,
            chunk.getAttribute("x") orelse return TiledMapError.InvalidFormat,
            10,
        );
        const y = try std.fmt.parseInt(
            i64,
            chunk.getAttribute("y") orelse return TiledMapError.InvalidFormat,
            10,
        );
        const width = try std.fmt.parseInt(
            i64,
            chunk.getAttribute("width") orelse return TiledMapError.InvalidFormat,
            10,
        );
        const height = try std.fmt.parseInt(
            i64,
            chunk.getAttribute("height") orelse return TiledMapError.InvalidFormat,
            10,
        );

        var tiles = try std.ArrayList(usize).initCapacity(allocator, @intCast(width * height));
        const content = switch (chunk.children[0]) {
            .char_data => |content| content,
            else => return TiledMapError.InvalidFormat,
        };
        var parts = std.mem.tokenizeAny(u8, content, ", \n");
        while (parts.next()) |part| {
            try tiles.append(try std.fmt.parseInt(usize, part, 10));
        }
        return Chunk{
            .x = x,
            .y = y,
            .width = width,
            .height = height,
            .tiles = tiles,
        };
    }

    fn deinit(self: Chunk) void {
        self.tiles.deinit();
    }

    fn render(self: Chunk, tileset: *Tileset) void {
        const xOffset = self.x * tileset.tileWidth;
        const yOffset = self.y * tileset.tileHeight;
        var i: i64 = 0;
        for (self.tiles.items) |tile| {
            if (tile == 0) {
                i += 1;
                continue;
            }

            const col = @mod(i, self.width);
            const row = @divTrunc(i, self.width);
            tileset.render(
                @intCast(tile),
                rl.Vector2{
                    .x = @floatFromInt(xOffset + col * tileset.tileWidth),
                    .y = @floatFromInt(yOffset + row * tileset.tileHeight),
                },
            );

            i += 1;
        }
    }
};
