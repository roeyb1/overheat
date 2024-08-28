LDTK_Tile :: struct {
    src: [2] s32;
    px: [2] s32;
    t: u32; // tile id
    f: u8;
}

LDTK_Entity :: struct {
    __identifier: string;
    __worldX: u32;
    __worldY: u32;
    width: u32;
    height: u32;
    __pivot: [2] float;
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


TILE_PIXEL_SIZE :: 32;

import_ldtk_level :: (world: *World, path: string) {
    old_allocator := context.allocator;
    context.allocator = temp;

    data, read_success := read_entire_file(path, log_errors=false);
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
                    if ldtk_entity.__identifier == "light" {
                        x := cast(float) (ldtk_entity.__worldX / xx layer.__gridSize);
                        y := cast(float) ((layer.__gridSize * layer.__cHei - xx ldtk_entity.__worldY) / layer.__gridSize);
                        light := entity_spawn(world);
                        ecs_add(world, light, Position, .{.{x,y}});
                        ecs_add(world, light, Point_Light, .{intensity = 2., color = .{ 255. / 255., 115. / 255., 23. / 255.}, radius = 10.});
                    } else if ldtk_entity.__identifier == "collider" {
                        x := (cast(float) ldtk_entity.__worldX / cast(float) TILE_PIXEL_SIZE) - ldtk_entity.__pivot[0];
                        y := cast(float)(layer.__gridSize * layer.__cHei - xx ldtk_entity.__worldY) / cast(float)(TILE_PIXEL_SIZE) + ldtk_entity.__pivot[1];
                        width := cast(float) ldtk_entity.width / cast(float) TILE_PIXEL_SIZE;
                        height := cast(float) ldtk_entity.height / cast(float) TILE_PIXEL_SIZE;
                        x += width / 2. - 0.5;
                        y -= height / 2. - 0.5;
                        
                        bounds := make_aabb(.{0, 0}, .{width, height});

                        collider := entity_spawn(world);
                        ecs_add(world, collider, Position, .{.{x,y} });
                        ecs_add(world, collider, Shadow_Caster, .{bounds});
                        ecs_add(world, collider, Collider_AABB, .{bounds, true});
                    } else if ldtk_entity.__identifier == "pack_spawner" {
                        x := (cast(float) ldtk_entity.__worldX / cast(float) TILE_PIXEL_SIZE) - ldtk_entity.__pivot[0];
                        y := cast(float)(layer.__gridSize * layer.__cHei - xx ldtk_entity.__worldY) / cast(float)(TILE_PIXEL_SIZE) + ldtk_entity.__pivot[1];

                        //spawn_enemy_pack(world, .{x, y}, 2, .BAT);
                    }
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
                tileset_filename = sprint("assets/%", str_slice);
            }
            load_spritesheet(tileset_filename, TILE_PIXEL_SIZE, 0, 0, 0, 0);

            spawn_entities_for_tiles(world, layer.autoLayerTiles, layer.__gridSize, layer.__cHei, tileset_filename, layer_index);
            spawn_entities_for_tiles(world, layer.gridTiles, layer.__gridSize, layer.__cHei, tileset_filename, layer_index);
        }
    }
}

spawn_entities_for_tiles :: (world: *World, tiles: [] LDTK_Tile, grid_size: u32, layer_height: u32, layer_spritesheet: string, layer_index: s64) {
    tile_size := 2. * cast(float) TILE_PIXEL_SIZE / cast(float) PIXELS_PER_METER;
    for tile : tiles {
        x := (cast(float) tile.px[0] / cast(float) TILE_PIXEL_SIZE);
        y := (cast(float) (grid_size * layer_height - xx tile.px[1]) / cast(float) TILE_PIXEL_SIZE);

        tile_entity := entity_spawn(world);

        pos := ecs_add(world, tile_entity, Position, .{.{x, y}});

        sprite: Sprite;
        sprite.sheet_path = layer_spritesheet;
        sprite.z_order = cast(u16) layer_index;
        sprite.scale = make_vector2(tile_size);
        sprite.index = tile.t;
        sprite.flip = cast(Flip_Flags) tile.f;
        ecs_add(world, tile_entity, Sprite, sprite);
    }
}

#import "jaison";
