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

    data, read_success := read_entire_file("assets/levels/prison/prison.ldtk", log_errors=true);
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
                    add_component(world, light, Point_Light, .{intensity = 1., color = .{ 255. / 255., 147. / 255., 41./255.}, radius = 5.});
                }
            }

            if layer.__tilesetRelPath.count == 0 then continue;

            // the layer stack is inverted when importing from the ldtk file, so reverse it back here:
            layer_index := level.layerInstances.count - layer_level;

            tile_size := 2 * cast(float) layer.__gridSize / cast(float) PIXELS_PER_METER;

            // tilesetRelPath is relative to the ldtk file itself, we need to rebase the path to the assets directory
            tileset_filename: string;
            {
                index := find_index_from_left(layer.__tilesetRelPath, "tilemaps");
                str_slice := slice(layer.__tilesetRelPath, index, layer.__tilesetRelPath.count - index);
                tileset_filename = tprint("assets/%", str_slice);
            }
            layer_spritesheet := load_spritesheet(tileset_filename, layer.__gridSize, 0, 0);

            for tile : layer.autoLayerTiles {
                x := cast(float) (tile.px[0] / xx layer.__gridSize);
                y := cast(float) ((layer.__gridSize * layer.__cHei - xx tile.px[1]) / layer.__gridSize);

                tile_entity := spawn_entity(world);

                pos := add_component(*g_world, tile_entity, Position, .{value = .{x, y}});

                ground_sprite: Sprite;
                ground_sprite.sheet = layer_spritesheet;
                ground_sprite.z_order = cast(u16) layer_index;
                ground_sprite.scale = make_vector2(tile_size);
                ground_sprite.index = tile.t;
                add_component(*g_world, tile_entity, Sprite, ground_sprite);

                // any layer above the custom ground is a collidable layer
                if layer_index > 1 {
                    collider := add_component(world, tile_entity, Collider_AABB);
                    collider.aabb = make_bounds(.{0, 0}, make_vector2(tile_size));
                }
            }
        }
    }

}

#import "jaison";
