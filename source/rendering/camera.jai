Camera :: struct {
    // This should probably be handled with a more general projection matrix, but with a simple top down 2d camera
    // these are the only values we need to map from world -> view
    projection: Matrix4;

    // (Usually the player)
    entity_to_track: Entity;
}

// #todo: we probably want this value to vary so that the window size can't just show you more of the world.
// The number of tiles visible should mostly remain a constant value
PIXELS_PER_METER :: 64;

compute_screen_projection :: () -> Matrix4 {
    scaled_window_half_width := (cast(float) g_window_width / 2.) / (PIXELS_PER_METER);
    scaled_window_half_height := (cast(float) g_window_height / 2.) / (PIXELS_PER_METER);
    return orthographic_projection_matrix(-scaled_window_half_width, scaled_window_half_width, -scaled_window_half_height, scaled_window_half_height, -1, 1);
}

update_camera_projections :: (world: *World) {
    for Query(*Camera).{world = world} {
        it.camera.projection = compute_screen_projection();
    }
}

update_camera_positions :: (world: *World) {
    SMOOTH_SPEED :: 15.;

    for Query(*Position, Camera).{world = world} {
        assert(is_entity_valid(world, it.camera.entity_to_track));

        target_location := get_component(*g_world, it.camera.entity_to_track, Position);
        assert(target_location != null);

        camera_dist_to_target := distance(target_location, it.position);

        alpha := camera_dist_to_target;

        // cubic easing function based on distance. further camera -> accelerate faster
        speed_factor := 1. - pow(1 - alpha, 3.);

        it.position.value = lerp(it.position, target_location, speed_factor * SMOOTH_SPEED * cast(float) g_delta_time);
    }
} @System

worldspace_to_viewspace :: (proj: Matrix4, view: Vector2, x: Vector2) -> Vector2 {
    clip := (proj * make_vector4(x - view, 0., 1.)).xy; // result in NDC centered at 0, 0
    ndc := (clip + .{1., -2.}) / 2.;
    screen := ndc * Vector2.{xx g_window_width, xx g_window_height};
    return screen;
}

viewspace_to_worldspace :: (camera: *Camera, v: Vector2) -> Vector2 {
    assert(false);
    return .{0, 0};
}
