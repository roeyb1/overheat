LDTK_Tile :: struct {
    src: [2] s32;
    px: [2] s32;
    t: u32; // tile id
}

LDTK_Entity :: struct {
    __identifier: string;
    __worldX: u32;
    __worldY: u32;
}

LDTK_Layer :: struct {
    __identifier: string;
    __type: string;
    intGridCsv: [..] s32;
    autoLayerTiles: [..] LDTK_Tile;
    gridTiles: [..] LDTK_Tile;
    entityInstances: [..] LDTK_Entity;
    __tilesetRelPath: string;
    __cWid: u32; // width in cells
    __cHei: u32; // height in cells
    __gridSize: u32; // height in cells
}

LDTK_Level :: struct {
    identifier: string;
    layerInstances: [..] LDTK_Layer;
    pxWid: s32;
    pxHei: s32;
}

LDTK_TOC_Entity_Instance :: struct {
    worldX: s32;
    worldY: s32;
}

LDTK_TOC_Entry :: struct {
    identifier: string;
    instancesData: [..] LDTK_TOC_Entity_Instance;
}

LDTK_Root :: struct {
    levels: [..] LDTK_Level;
    toc: [..] LDTK_TOC_Entry;
}

g_player_start: Vector2;

import_ldtk_level :: (world: *World) {
    old_allocator := context.allocator;
    context.allocator = temp;

    data, read_success := read_entire_file("assets/levels/prison/prison.ldtk", log_errors=false);
    assert(read_success);

    parse_success, root := json_parse_string(data, LDTK_Root, ignore_unknown=true);
    assert(parse_success);

    context.allocator = old_allocator;

    if root.levels.count == 0 then return;

    for root.toc {
        if it.identifier == "playerstart" {
            g_player_start = Vector2.{it.instancesData[0].worldX / 32., (root.levels[0].pxHei - it.instancesData[0].worldY) / 32.};
        }
    }

    for *level : root.levels {
        for *layer, layer_level : level.layerInstances {
            if layer.__type == "Entities" {
                for *ldtk_entity : layer.entityInstances {
                    if ldtk_entity.__identifier != "light" then continue;

                    x := cast(float) (ldtk_entity.__worldX / xx layer.__gridSize);
                    y := cast(float) ((layer.__gridSize * layer.__cHei - xx ldtk_entity.__worldY) / layer.__gridSize);
                    light := spawn_entity(world);
                    add_component(world, light, Position, .{.{x, y}});
                    add_component(world, light, Point_Light, .{intensity = 2., color = .{ 255. / 255., 147. / 255., 41./255.}, radius = 10.});
                }
            }

            if layer.__tilesetRelPath.count == 0 then continue;

            // the layer stack is inverted when importing from the ldtk file, so reverse it back here:
            layer_index := level.layerInstances.count - layer_level;

            // tilesetRelPath is relative to the ldtk file itself, we need to rebase the path to the assets directory
            tileset_filename: string;
            {
                index := find_index_from_left(layer.__tilesetRelPath, "tilemaps");
                str_slice := slice(layer.__tilesetRelPath, index, layer.__tilesetRelPath.count - index);
                tileset_filename = tprint("assets/%", str_slice);
            }
            layer_spritesheet := load_spritesheet(tileset_filename, TILE_PIXEL_SIZE, 0, 0);

            spawn_entities_for_tiles(world, layer.autoLayerTiles, layer.__gridSize, layer.__cHei, layer_spritesheet, layer_index);
            spawn_entities_for_tiles(world, layer.gridTiles, layer.__gridSize, layer.__cHei, layer_spritesheet, layer_index);
        }
    }
}

TILE_PIXEL_SIZE :: 32;

spawn_entities_for_tiles :: (world: *World, tiles: [] LDTK_Tile, grid_size: u32, layer_height: u32, layer_spritesheet: *SpriteSheet, layer_index: s64) {
    tile_size := 2. * cast(float) TILE_PIXEL_SIZE / cast(float) PIXELS_PER_METER;
    for tile : tiles {
        x := (cast(float) tile.px[0] / cast(float) TILE_PIXEL_SIZE);
        y := (cast(float) (grid_size * layer_height - xx tile.px[1]) / cast(float) TILE_PIXEL_SIZE);

        tile_entity := spawn_entity(world);

        pos := add_component(world, tile_entity, Position, .{value = .{x, y}});

        sprite: Sprite;
        sprite.sheet = layer_spritesheet;
        sprite.z_order = cast(u16) layer_index;
        sprite.scale = make_vector2(tile_size);
        sprite.index = tile.t;
        add_component(world, tile_entity, Sprite, sprite);

        // any layer above the custom ground is a collidable layer
        if layer_index > 1 {
            collider := add_component(world, tile_entity, Collider_AABB);
            collider.aabb = make_bounds(.{0, 0}, make_vector2(tile_size));
        }
    }
}

#import "jaison";
