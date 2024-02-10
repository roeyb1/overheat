Camera :: struct {
    position: Vector2;

    // This should probably be handled with a more general projection matrix, but with a simple top down 2d camera
    // these are the only values we need to map from world -> view
    width: float;
    height: float;

    // (Usually the player)
    entity_to_track: *Entity;
}

// #todo: we probably want this value to vary so that the window size can't just show you more of the world.
// The number of tiles visible should mostly remain a constant value
PIXELS_PER_METER :: 32;

update_camera_position :: (using self: *Camera, delta_time: float64) {
    assert(entity_to_track != null);

    target_location := entity_to_track.position;
    // Lookahead
    // target_location += unit_vector(entity_to_track.velocity) * LOOKAHEAD;

    camera_dist_to_target := distance(target_location, position);

    SMOOTH_SPEED :: 15.;

    alpha := camera_dist_to_target;

    // cubic easing function based on distance. further camera -> accelerate faster
    speed_factor := 1. - pow(1 - alpha, 3.);

    position = lerp(position, target_location, speed_factor * SMOOTH_SPEED * cast(float) delta_time);
}

worldspace_to_viewspace :: inline (camera: *Camera, v: Vector2) -> Vector2 {
    return (v - camera.position) * PIXELS_PER_METER + make_vector2((camera.width) / 2., (camera.height) / 2.);
}

viewspace_to_worldspace :: (camera: *Camera, v: Vector2) -> Vector2 {
    return ((v - make_vector2(camera.width / 2. , camera.height / 2.)) / PIXELS_PER_METER) + camera.position;
}