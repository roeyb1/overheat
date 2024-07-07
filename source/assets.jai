#scope_export

TextureHandle :: enum u32 {}

SpriteSheet :: struct {
    texture: TextureHandle;

    /** Size of a single sprite in the sheet: (only supports square sprites for now) */
    extent: u32;

    /** distance between entries in the sprite sheet, if it is not packed. */
    x_offset: u32;
    y_offset: u32;

    /** amount of sprite contained in the sprite sheet. */
    width_in_sprites: u32;
    heigth_in_sprites: u32;
}

// just for now, store some common stuff globally until we have a proper map loading system with asset references
g_default_grid: TextureHandle;
g_point_light_texture: TextureHandle;

load_all_assets :: () {
    stbi_set_flip_vertically_on_load(1);

    g_default_grid = load_texture("assets/grid.png");
    g_point_light_texture = load_texture("assets/point_light.png");

    load_spritesheet("assets/players/player_character1.png",48, 0, 0,23,4);
    load_spritesheet("assets/players/player_character2.png", 48, 0, 0,23,4);
    load_spritesheet("assets/enemies/skeleton.png", 32, 0, 0, 10, 4);
    load_spritesheet("assets/enemies/bat2.png", 96, 0, 0, 15, 4);

    log("Asset loading complete");
}

get_spritesheet :: (filename: string) -> *SpriteSheet {
    result := table_find_pointer(*sprite_sheets, filename);
    assert(result != null);
    return result;
}

load_spritesheet :: (filename: string, extent: u32, x_offset: u32, y_offset: u32, width_in_sprites: u32, heigth_in_sprites: u32) -> *SpriteSheet {
    // check if we already have this spritesheet in the asset cache:
    result := table_find_pointer(*sprite_sheets, filename);
    if result != null then return result;

    key := copy_string(filename);
    texture := load_texture(filename);

    result = table_add(*sprite_sheets, key, .{texture, extent, x_offset, y_offset,width_in_sprites, heigth_in_sprites});
    assert(result != null);

    return result;
}

get_texture :: (filename: string) -> TextureHandle {
    result := table_find_pointer(*textures, filename);
    if result == null then return load_texture(filename);

    return << result;
}

load_texture :: (filename: string) -> TextureHandle {
    #if CLIENT {
        key := copy_string(filename);
        result := table_add(*textures, key, 0);
        texture := texture_load(filename);
        << result = texture;

        log("Loaded new texture asset: %", filename);
        return << result;
    } else {
        return 0;
    }
}

#scope_file

sprite_sheets: Table(string, SpriteSheet);
textures: Table(string, TextureHandle);

#import "Hash_Table";
#import "stb_image";
