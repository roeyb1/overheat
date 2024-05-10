Camera :: struct {
    position: Vector2;

    // This should probably be handled with a more general projection matrix, but with a simple top down 2d camera
    // these are the only values we need to map from world -> view
    projection: Matrix4;

    // (Usually the player)
    entity_to_track: *Entity;
}

// #todo: we probably want this value to vary so that the window size can't just show you more of the world.
// The number of tiles visible should mostly remain a constant value
PIXELS_PER_METER :: 64;

recompute_camera_projection :: (using self: *Camera) {
    scaled_window_half_width := (cast(float) g_window_width / 2.) / (PIXELS_PER_METER);
    scaled_window_half_height := (cast(float) g_window_height / 2.) / (PIXELS_PER_METER);
    projection = orthographic_projection_matrix(-scaled_window_half_width, scaled_window_half_width, -scaled_window_half_height, scaled_window_half_height, -1, 1);
}

update_camera_position :: (using self: *Camera, delta_time: float64) {
    assert(entity_to_track != null);

    //target_location := entity_to_track.position;
    target_location := Vector2.{};
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
    result := camera.projection * make_vector4(v - camera.position, 0., 1.);
    return Vector2.{ result.x, result.y };
}

viewspace_to_worldspace :: (camera: *Camera, v: Vector2) -> Vector2 {
    assert(false);
    return .{0, 0};
}