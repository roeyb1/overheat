Position :: struct @Component {
    using #as value: Vector2; @Sync @Interp @Predict
}

Velocity :: struct @Component {
    using #as value: Vector2; @Sync @Predict
}

Name :: struct @Component {
    name: string; @Sync
}

Camera :: struct @Component {
    // This should probably be handled with a more general projection matrix, but with a simple top down 2d camera
    // these are the only values we need to map from world -> view
    projection: Matrix4;

    // (Usually the player)
    entity_to_track: Entity;
}

Game_Viewport :: struct @SingletonComponent {
    main_camera: Entity;
}

Flip_Flags :: enum_flags u8 {
    NONE   :: 0;
    FLIP_X :: 1 << 0;
    FLIP_Y :: 1 << 1;
}

Sprite :: struct @Component {
    sheet_path: string; @Sync

    sheet: *SpriteSheet; @NoSerialize

    scale: Vector2 = .{1, 1}; @Sync;
    index: u32 = 0;
    z_order: u16 = 0; @Sync

    flip: Flip_Flags = 0;
}

/** Point light is a component that can be added to an entity to make it render a as a radial, point source light light */
Point_Light :: struct @Component {
    color: Vector3; @Sync
    radius: float; @Sync
    intensity: float; @Sync
}

Shadow_Caster :: struct @Component {
    box: AABB;
}

/** Entities with the Transient component will be destroyed automatically before the next frame */
Transient :: struct @Tag {}

destroy_transients :: (q: Query) {
    for 0..q.count-1 {
        entity_destroy(q.world, q.entities[it]);
    }
} @System(PreUpdate) @Write() @Read(Transient)