show_scene_graph_window :: (open: *bool) {
    if ImGui.Begin("Scene Graph") {

        ImGui.InputText("##Filter", filter_text.data, 64);

        for q : iter_make(*g_world) {

            if archetype_type_has(q.current_archetype, cid_get(*g_world, Hidden_From_SceneGraph)) then continue;

            for entity : q.entities {
                name := ifx ecs_has(*g_world, entity, Name) then ecs_get(*g_world, entity, Name).name else "Entity";
                label := tprint("%", entity.raw);
                
                if filter_text[0] == 0 || matches_filter(name, to_string(filter_text.data)) {
                    if ImGui.TreeNode(temp_c_string(label), "% [%v%]", name, entity.index, entity.generation) {
                        
                        draw_entry_for_entity(*g_world, entity);

                        ImGui.TreePop();
                    }
                }
            }
        }
    }

    ImGui.End();
}

#scope_file

draw_entry_for_entity :: (world: *World, entity: Entity) {
    cids := entity_types_get(world, entity);
    for cid : cids {
        cti := cid_to_type_info(world, cid);

        // for now, skip displaying pair components.
        if cti.is_pair then continue;

        ti := cti.ti;

        if ImGui.TreeNode(temp_c_string(ti.name)) {

            ImGui.TreePop();
        }
    }
}

filter_text: [64] u8;

matches_filter :: (text: string, filter: string) -> bool {
    return find_index_from_left(to_lower_copy_new(text,, temp), to_lower_copy_new(filter,, temp)) != -1;
}