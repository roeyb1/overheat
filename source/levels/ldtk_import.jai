LDTK_Tile :: struct {
    src: [2] s32;
    px: [2] s32;
    t: u32; // tile id
}

LDTK_Layer :: struct {
    __identifier: string;
    intGridCsv: [..] s32;
    autoLayerTiles: [..] LDTK_Tile;
    gridTiles: [..] LDTK_Tile;
    __tilesetRelPath: string;
    __cWid: u32; // width in cells
    __cHei: u32; // height in cells
    __gridSize: u32; // height in cells
}

LDTK_Level :: struct {
    identifier: string;
    layerInstances: [..] LDTK_Layer;
}

LDTK_Root :: struct {
    levels: [..] LDTK_Level;
}

import_ldtk_level :: (world: *World) {
    old_allocator := context.allocator;
    context.allocator = temp;

    data, read_success := read_entire_file("assets/levels/prison/prison.ldtk", log_errors=true);
    assert(read_success);

    parse_success, root := json_parse_string(data, LDTK_Root, ignore_unknown=true);
    assert(parse_success);

    context.allocator = old_allocator;

    load_success := false;
    for *level : root.levels {
        // only parse level_0:
        if level.identifier != "level_0" then continue;
        
        for *layer, layer_level : level.layerInstances {
            log("layer: %", layer.__identifier);

            if layer.__tilesetRelPath.count == 0 then continue;

            // tilesetRelPath is relative to the ldtk file itself, we need to rebase the path to the assets directory
            tileset_filename: string;
            {
                index := find_index_from_left(layer.__tilesetRelPath, "tilemaps");
                str_slice := slice(layer.__tilesetRelPath, index, layer.__tilesetRelPath.count - index);
                tileset_filename = tprint("assets/%", str_slice);
            }
            layer_spritesheet := load_spritesheet(tileset_filename, layer.__gridSize, 0, 0);

            // @todo: collisions based on intgrid
            //for value : layer.intGridCsv {
            //    if value == 0 then continue;
            //    x := cast(float) (it_index % layer.__cWid);
            //    y := cast(float) (layer.__cHei - (it_index / layer.__cWid));
            //}

            for tile : layer.autoLayerTiles {
                x := cast(float) (tile.px[0] / xx layer.__gridSize);
                y := cast(float) ((layer.__gridSize * layer.__cHei - xx tile.px[1]) / layer.__gridSize);

                wall := spawn_entity(world);
                pos := add_component(*g_world, wall, Position, .{value = .{x, y}});

                ground_sprite: Sprite;
                ground_sprite.sheet = layer_spritesheet;
                ground_sprite.z_order = cast(u16) (level.layerInstances.count - layer_level);
                ground_sprite.scale = make_vector2(layer.__gridSize / 32.);
                ground_sprite.index = tile.t;
                add_component(*g_world, wall, Sprite, ground_sprite);
            }
        }
    }

}

#import "jaison";
