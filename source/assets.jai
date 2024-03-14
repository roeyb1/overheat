#scope_export

Texture :: struct {
    
}

SpriteSheet :: struct {
    texture: *Texture;

    /** Size of a single sprite in the sheet: (only supports square sprites for now) */
    extent: s32;

    /** distance between entries in the sprite sheet, if it is not packed. */
    x_offset: u32;
    y_offset: u32;
}

// just for now, store some common stuff globally until we have a proper map loading system with asset references
g_dungeon_tiles: *SpriteSheet;
g_default_grid: *Texture;
g_local_player_sprite: *SpriteSheet;
g_player_sprite: *SpriteSheet;

load_all_assets :: () {
    stbi_set_flip_vertically_on_load(1);

    g_dungeon_tiles = load_spritesheet("assets/dungeon_tiles.png", 32, 0, 0);
    g_local_player_sprite = load_spritesheet("assets/orc_mage_walk.png", 64, 0, 0);
    g_player_sprite = load_spritesheet("assets/orc_mage_walk_2.png", 64, 0, 0);
    g_default_grid = load_texture("assets/grid.png");

    log("Asset loading complete");
}

get_spritesheet :: (filename: string) -> *SpriteSheet {
    result := table_find_pointer(*sprite_sheets, filename);
    assert(result != null);
    return result;
}

load_spritesheet :: (filename: string, extent: s32, x_offset: u32, y_offset: u32) -> *SpriteSheet {
    key := copy_string(filename);
    texture := load_texture(filename);

    result := table_add(*sprite_sheets, key, .{texture, extent, x_offset, y_offset});
    assert(result != null);

    return result;
}

get_texture :: (filename: string) -> *Texture {
    result := table_find_pointer(*textures, filename);
    if result == null then result = load_texture(filename);
    assert(result != null);

    return result;
}

load_texture :: (filename: string) -> *Texture {
    key := copy_string(filename);
    result := table_add(*textures, key, .{});
    //texture, success := load_texture_from_file(filename);
    //<< result = texture;
    //assert(success);

    log("Loaded new texture asset: %", filename);

    return result;
}

#scope_file

sprite_sheets: Table(string, SpriteSheet);
textures: Table(string, Texture);

#import "Hash_Table";
#import "stb_image";