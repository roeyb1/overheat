Camera :: struct {
    position: Vector2;

    // This should probably be handled with a more general projection matrix, but with a simple top down 2d camera
    // these are the only values we need to map from world -> view
    width: float;
    height: float;

    entity_to_track: *Entity;
}

// #todo: we probably want this value to vary so that the window size can't just show you more of the world.
// The number of tiles visible should mostly remain a constant value
PIXELS_PER_METER :: 32;

update_camera_position :: (using self: *Camera, delta_time: float64) {
    assert(entity_to_track != null);

    // #todo: some smoothing functions, lookahead, etc. Make this more interesting than a simple lock on camera.
    position = entity_to_track.position;
}

worldspace_to_viewspace :: inline (camera: *Camera, v: Vector2) -> Vector2 {
    return v * PIXELS_PER_METER + make_vector2((camera.width) / 2., (camera.height) / 2.);
}

viewspace_to_worldspace :: (camera: *Camera, v: Vector2) -> Vector2 {
    // #todo:
    assert(false);
    return .{0, 0};
}