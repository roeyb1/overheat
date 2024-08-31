Level :: struct @Component {
    path: string; @Sync
}

on_level_load :: (world: *World, entity: Entity) {
    level := ecs_get(world, entity, Level);

    import_ldtk_level(world, level.path);
} @Event(EcsOnAdd,Level)

#load "ldtk_import.jai";