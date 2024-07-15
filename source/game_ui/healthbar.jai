draw_enemy_health_bar :: (q: Query) {
    healths := query_get(q, Health);
    positions := query_get(q, Position);
    colliders := query_get_opt(q, Collider_AABB); // we can use the bounds of the entity to position the healthbar above them

    viewport := get_singleton(q.world, Game_Viewport);
    camera := get_component(q.world, viewport.main_camera, Camera);
    camera_pos := get_component(q.world, viewport.main_camera, Position);

    HEALTHBAR_SIZE := ui_size(Vector2.{50, 5});

    ImGui.PushStyleColor(.PlotHistogram, HEALTH_COLOR);
    ImGui.PushStyleVar(.FrameRounding, 2);

    for 0..q.count-1 {
        if equals(healths[it].value, healths[it].max) then continue;

        worldspace_pos := positions[it];
        if colliders {
            worldspace_pos.y += box_extent(colliders[it]).y;
        }
        view_pos := worldspace_to_viewspace(camera.projection, camera_pos, worldspace_pos);
        ImGui.SetNextWindowPos(view_pos - .{HEALTHBAR_SIZE.x / 2., HEALTHBAR_SIZE.y});
        if ImGui.Begin(temp_c_string(tprint("HealthBar##%", q.entities[it].raw)), null, .NoTitleBar | .NoScrollbar |.NoCollapse | .NoBackground | .NoSavedSettings | .AlwaysAutoResize | .NoResize | .NoMove) {
            ImGui.ProgressBar(healths[it].value / healths[it].max, HEALTHBAR_SIZE, "");
        }
        ImGui.End();
    }

    ImGui.PopStyleVar();
    ImGui.PopStyleColor();
} @System(PreRender) @Write() @Read(Enemy,Health,Position,Game_Viewport) @OptionalRead(Collider_AABB)

draw_local_player_health_bar :: (q: Query) {
    healths := query_get(q, Health);
    positions := query_get(q, Position);
    colliders := query_get_opt(q, Collider_AABB); // we can use the bounds of the entity to position the healthbar above them

    viewport := get_singleton(q.world, Game_Viewport);
    camera := get_component(q.world, viewport.main_camera, Camera);
    camera_pos := get_component(q.world, viewport.main_camera, Position);

    HEALTHBAR_SIZE := ui_size(Vector2.{50, 6});

    ImGui.PushStyleVar(.FrameRounding, 2);
    ImGui.PushStyleVar(.ItemSpacing, .{0, 0});

    for 0..q.count-1 {
        worldspace_pos := positions[it];
        if colliders {
            worldspace_pos.y += box_extent(colliders[it]).y;
        }
        view_pos := worldspace_to_viewspace(camera.projection, camera_pos, worldspace_pos);
        ImGui.SetNextWindowPos(view_pos - .{HEALTHBAR_SIZE.x / 2., 2 * HEALTHBAR_SIZE.y});
        if ImGui.Begin(temp_c_string(tprint("HealthBar##%", q.entities[it].raw)), null, .NoTitleBar | .NoScrollbar |.NoCollapse | .NoBackground | .NoSavedSettings | .AlwaysAutoResize | .NoResize | .NoMove) {
            ImGui.PushStyleColor(.PlotHistogram, HEALTH_COLOR);
            ImGui.ProgressBar(healths[it].value / healths[it].max, HEALTHBAR_SIZE, "");
            ImGui.PopStyleColor();

            ImGui.PushStyleColor(.PlotHistogram, RESOURCE_COLOR);
            ImGui.ProgressBar(healths[it].value / healths[it].max, HEALTHBAR_SIZE, "");
            ImGui.PopStyleColor();
        }
        ImGui.End();
    }

    ImGui.PopStyleVar();
    ImGui.PopStyleVar();
} @System(PreRender) @Write() @Read(Local_Player,Health,Position,Game_Viewport) @OptionalRead(Collider_AABB)

draw_remote_player_health_bar :: (q: Query) {
    healths := query_get(q, Health);
    positions := query_get(q, Position);
    colliders := query_get_opt(q, Collider_AABB); // we can use the bounds of the entity to position the healthbar above them

    viewport := get_singleton(q.world, Game_Viewport);
    camera := get_component(q.world, viewport.main_camera, Camera);
    camera_pos := get_component(q.world, viewport.main_camera, Position);

    HEALTHBAR_SIZE :: #run ui_size(Vector2.{50, 5});

    ImGui.PushStyleVar(.FrameRounding, 2);
    ImGui.PushStyleVar(.ItemSpacing, .{0, 0});
    ImGui.PushStyleColor(.PlotHistogram, HEALTH_COLOR);
    for 0..q.count-1 {
        worldspace_pos := positions[it];
        if colliders {
            worldspace_pos.y += box_extent(colliders[it]).y;
        }
        view_pos := worldspace_to_viewspace(camera.projection, camera_pos, worldspace_pos);
        ImGui.SetNextWindowPos(view_pos - .{HEALTHBAR_SIZE.x / 2., HEALTHBAR_SIZE.y});
        if ImGui.Begin(temp_c_string(tprint("HealthBar##%", q.entities[it].raw)), null, .NoTitleBar | .NoScrollbar |.NoCollapse | .NoBackground | .NoSavedSettings | .AlwaysAutoResize | .NoResize | .NoMove) {
            ImGui.ProgressBar(healths[it].value / healths[it].max, HEALTHBAR_SIZE, "");
        }
        ImGui.End();
    }
    ImGui.PopStyleColor();
    ImGui.PopStyleVar();
    ImGui.PopStyleVar();
} @System(PreRender) @Write() @Read(Remote_Player,Health,Position,Game_Viewport) @OptionalRead(Collider_AABB)