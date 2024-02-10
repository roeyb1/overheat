#scope_export

SpriteSheet :: struct {
    texture: *Simp.Texture;

    /** Size of a single sprite in the sheet: (only supports square sprites for now) */
    extent: u32;

    /** distance between entries in the sprite sheet, if it is not packed. */
    x_offset: u32;
    y_offset: u32;
}

// just for now, store some common stuff globally until we have a proper map loading system with asset references
g_dungeon_tiles: *SpriteSheet;
g_default_grid: *Simp.Texture;
g_large_font: *Simp.Dynamic_Font;

load_all_assets :: () {
    stbi_set_flip_vertically_on_load(1);

    g_dungeon_tiles = load_spritesheet("assets/dungeon_tiles.png", 16, 0, 0);
    g_default_grid = load_texture("assets/grid.png");

    // #todo: move this to a table
    g_large_font = Simp.load_font("assets", "monogram.ttf", 38);

    log("Asset loading complete");
}

get_spritesheet :: (filename: string) -> *SpriteSheet {
    result := table_find_pointer(*sprite_sheets, filename);
    assert(result != null);
    return result;
}

load_spritesheet :: (filename: string, extent: u32, x_offset: u32, y_offset: u32) -> *SpriteSheet {
    key := copy_string(filename);
    texture := load_texture(filename);

    result := table_add(*sprite_sheets, key, .{texture, extent, x_offset, y_offset});
    assert(result != null);

    return result;
}

get_texture :: (filename: string) -> *Simp.Texture {
    result := table_find_pointer(*textures, filename);
    if result == null then result = load_texture(filename);
    assert(result != null);
    
#import "Hash_Table";

    return result;
}

load_texture :: (filename: string) -> *Simp.Texture {
    key := copy_string(filename);
    result := table_add(*textures, key, .{});
    success := Simp.texture_load_from_file(result, filename);
    assert(success);

    log("Loaded new texture asset: %", filename);

    return result;
}

#scope_file

sprite_sheets: Table(string, SpriteSheet);
textures: Table(string, Simp.Texture);

#import "Hash_Table";
#import "stb_image";