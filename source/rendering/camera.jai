
compute_screen_projection :: () -> Matrix4 {
    scaled_window_half_width := (cast(float) g_window_width / 2.) / (PIXELS_PER_METER);
    scaled_window_half_height := (cast(float) g_window_height / 2.) / (PIXELS_PER_METER);
    return orthographic_projection_matrix(-scaled_window_half_width, scaled_window_half_width, -scaled_window_half_height, scaled_window_half_height, -1, 1);
}

update_camera_projections :: (q: Query) {
    if g_window_resized_this_frame {
        cameras := query_get(q, Camera);

        for 0..q.count-1 {
            cameras[it].projection = compute_screen_projection();
        }
    }
} @System(PreRender) @Write(Camera) @Read()

set_camera_follow_target :: (world: *World, entity: Entity) {
    viewport := ecs_singleton_get(*g_world, Game_Viewport);

    camera := ecs_get(*g_world, viewport.main_camera, Camera);
    cam_pos := ecs_get(*g_world, viewport.main_camera, Position);

    << cam_pos = .{ ecs_get(world, entity, Position).value };
    camera.entity_to_track = entity;

} @Event(EcsOnAdd,Local_Player)

update_camera_positions :: (q: Query) {
    SMOOTH_SPEED :: 15.;

    camera_positions := query_get(q, Position);
    camera := query_get(q, Camera);

    for 0..q.count-1 {
        if !entity_is_valid(q.world, camera[it].entity_to_track) continue;

        target_location := ecs_get(q.world, camera[it].entity_to_track, Position);
        assert(target_location != null);

        camera_dist_to_target := distance(target_location, camera_positions[it]);

        alpha := camera_dist_to_target;

        // cubic easing function based on distance. further camera -> accelerate faster
        speed_factor := 1. - pow(1 - alpha, 3.);

        camera_positions[it].value = lerp(camera_positions[it], target_location, speed_factor * SMOOTH_SPEED * cast(float) g_delta_time);
    }
} @System(PreRender) @Write(Position) @Read(Camera)

worldspace_to_viewspace :: (proj: Matrix4, view: Vector2, x: Vector2) -> Vector2 {
    clip := (proj * make_vector4(x - view, 0., 1.)).xy; // result in NDC centered at 0, 0
    clip.y *= -1;
    ndc := (clip + .{1., 1.}) / 2.;
    screen := ndc * Vector2.{xx g_window_width, xx g_window_height};
    return screen;
}

viewspace_to_worldspace :: (proj: Matrix4, view: Vector2, screen: Vector2) -> Vector2 {
    ndc := screen / Vector2.{xx g_window_width, xx g_window_height};
    clip := ndc * 2. - .{1., 1.};
    clip.y *= -1;
    world := inverse(proj) * make_vector4(clip, 0., 1.);
    world += make_vector4(view, 0, 0);
    return world.xy;
}
