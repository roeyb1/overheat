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

        data := ecs_get(world, entity, cid);
        if ImGui.TreeNode(temp_c_string(ti.name)) {
            draw_members_property_editor(data, ti);
            ImGui.TreePop();
        }
    }
}

draw_members_property_editor :: (data: *void, ti: *Type_Info_Struct) {
    last_offset := 0;

    max_length_name: string;
    for member : ti.members {
        // skip #placed members
        if member.offset_in_bytes < last_offset then continue;
        if member.name.count > max_length_name.count then max_length_name = member.name;
    }
    name_align := ImGui.CalcTextSize(max_length_name).x + ImGui.CalcTextSize("  ").x;

    last_offset = 0;

    for member : ti.members {
        // skip #placed members
        if member.offset_in_bytes < last_offset then continue;

        draw_property_editor(data + member.offset_in_bytes, member.name, member.type, name_align);

        last_offset = member.offset_in_bytes;
    }
}

draw_property_editor :: (data: *void, name: string, ti: *Type_Info, align_char_width: float) {
    default_size: ImGui.ImVec2 = ImGui.CalcTextSize("  00.0  ");
    label := temp_c_string(tprint("##%", name));

    name_size := ImGui.CalcTextSize(tprint("%", name));
    align_spacing := align_char_width - name_size.x;

    if ti.type == {
        case .BOOL;

            ImGui.Text("%", name);
            ImGui.SameLine(spacing=align_spacing);

            index : s32 = xx <<cast(*bool)data;
            if ImGui.Combo(label, *index, "false\0true\0\0") { <<cast(*bool)data = xx index; };

        case .INTEGER;
            ImGui.Text("%", name);
            ImGui.SameLine(spacing=align_spacing);

            ImGui.PushItemWidth(default_size.x);
            ImGui.DragInt(label, data);
            ImGui.PopItemWidth();

        case .FLOAT;
            ImGui.Text("%", name);
            ImGui.SameLine(spacing=align_spacing);

            ImGui.PushItemWidth(default_size.x);
            ImGui.DragFloat(label, data, format="%.1f");
            ImGui.PopItemWidth();

        case .ENUM;
            info_enum := cast(*Type_Info_Enum) ti;
            ImGui.Text("%", name);
            ImGui.SameLine(spacing=align_spacing);

            if info_enum.enum_type_flags & .FLAGS {
                // #todo: flags
                ImGui.Text("(flags)");
            } else {
                value := Reflection.get_enum_value(data, info_enum);
                value_name := "";
                for info_enum.names {
                    if value == info_enum.values[it_index]  value_name = it;
                }

                if ImGui.BeginCombo(label, temp_c_string(value_name)) {
                    for info_enum.names {
                        is_selected := value == info_enum.values[it_index];
                        if ImGui.Selectable(temp_c_string(it), is_selected, size=*default_size) {
                            Reflection.set_enum_value(data, info_enum, info_enum.values[it_index]);
                        }
                        if is_selected ImGui.SetItemDefaultFocus();
                    }

                    ImGui.EndCombo();
                }
            }

        case .STRING;
            ImGui.Text("%", name);
            ImGui.SameLine(spacing=align_spacing);

            s := << cast(*string) data;
            if s.count ImGui.InputText(label, s.data, xx s.count, ImGui.InputTextFlags.ReadOnly);    // @@ We could allow editing of strings too.
            else ImGui.InputText(label, "(null)", 6, ImGui.InputTextFlags.ReadOnly);

        case .POINTER;
            ImGui.Text("%", name);
            ImGui.SameLine(spacing=align_spacing);

            ImGui.Text("(pointer)");

        case .STRUCT;
            ImGui.Text("%", name);
            ImGui.SameLine(spacing=align_spacing);

            struct_info := cast(*Type_Info_Struct) ti;
            if ImGui.TreeNode(temp_c_string(tprint("%##%", name, struct_info.name))) {
                draw_members_property_editor(data, struct_info);
                ImGui.TreePop();
            }
        
        case;
            ImGui.Text("");
    }
}

filter_text: [64] u8;

matches_filter :: (text: string, filter: string) -> bool {
    return find_index_from_left(to_lower_copy_new(text,, temp), to_lower_copy_new(filter,, temp)) != -1;
}

Reflection :: #import "Reflection";