Skills_UI :: struct @SingletonComponent {
    is_open: bool;
    selected: s64;
    fragments: *Fragments;
    name: string;
    valid: bool;
    networking_id: Networking_ID; 
}

open_skills_menu :: (q: Query) {
    input_states := get_singleton(q.world, Input_States);
    skills_ui := get_singleton(q.world, Skills_UI);
    

    if is_button_pressed(input_states, .OPEN_SKILLS_UI) {
        skills_ui.is_open = !skills_ui.is_open;
        skills_ui.networking_id = get_component(q.world, g_local_player, Networking_ID);
    }
} @System(PreRender) @Write(Skills_UI) @Read(Input_States)

show_ui_skills :: (q: Query) {
    skills_ui := get_singleton(q.world, Skills_UI);
    
    if skills_ui.is_open {
        if ImGui.Begin("Skills", null, .ImGuiWindowFlags_MenuBar) {
             if (ImGui.BeginMenuBar())
            {
                if (ImGui.BeginMenu("File"))
                {
                    if (ImGui.MenuItem("Close", "k")) { 
                        skills_ui.is_open = false; 
                    }
                    ImGui.EndMenu();
                }
                ImGui.EndMenuBar();
            }
            // Left
            {
                ImGui.BeginChild("left pane", .{150,0}, .ImGuiChildFlags_Border | .ImGuiChildFlags_ResizeX);
                for query : make_iter(q.world, Local_Player, Skill_Inventory)
                {
                    inventories := query_get(query,Skill_Inventory);
                    for 0.. query.count-1{
                        for inventories[it].skills {
                            names := get_component(query.world, it, Name).name;
                            selected_fragments := get_component(query.world, it, Fragments);

                            if (ImGui.Selectable(temp_c_string(tprint("%",names)))) {
                                skills_ui.selected = it_index;
                                skills_ui.fragments = selected_fragments;
                                skills_ui.name = names;
                                skills_ui.valid = true;
                            }
                        }
                    }
                }
                ImGui.EndChild();
            }
            ImGui.SameLine();
            if  skills_ui.valid {
                // Right
                {
                    ImGui.BeginGroup();
                    ImGui.BeginChild("item view", .{0,-ImGui.GetFrameHeightWithSpacing()}); // Leave room for 1 line below us
                    ImGui.Text(sprint("%", skills_ui.name));
                    //how to stop the title from appearing
                    ImGui.Separator();
                    if (ImGui.BeginTabBar("##Tabs", .ImGuiTabBarFlags_None))
                    {
                        //top drageables
                        if (ImGui.BeginTabItem("Fragments"))
                        {       
                            if (ImGui.BeginListBox("current fragments", .{400,100})){
                                for skills_ui.fragments.value
                                    {
                                    ImGui.PushID(*it_index);
                                    ImGui.SameLine();
                                    ImGui.Button(temp_c_string(sprint("%",SKILL_FRAGMENT_NAMES[it.type])), .{60, 60});

                                    if (ImGui.BeginDragDropSource(.ImGuiDragDropFlags_None))
                                        {
                                            // Set payload to carry the index of our item
                                            ImGui.SetDragDropPayload("potato", *it_index, size_of(int));
                                            // Display preview (could be anything, e.g. when dragging an image we could decide to display
                                            // the filename and a small preview of the image, etc.)
                                            ImGui.Text("Remove %", SKILL_FRAGMENT_NAMES[it.type]);
                                            ImGui.EndDragDropSource();
                                        }
                                        if (ImGui.BeginDragDropTarget())
                                        {
                                            payload := ImGui.AcceptDragDropPayload("potato");
                                            if (payload)
                                            {
                                                assert(payload.DataSize == size_of(int));
                                                payload_n := <<cast(*int)payload.Data;

                                                skills_ui.fragments.value[it_index] = .{cast(Skill_Fragment_Types)payload_n,0};
                                            }
                                            ImGui.EndDragDropTarget();
                                        }
                                    ImGui.PopID();
                                }
                                ImGui.EndListBox();
                            }
                            if (ImGui.Button(temp_c_string("add"), .{40, 30}))
                            {
                                array_add(*skills_ui.fragments.value, .{.NONE,0});
                            }
                            ImGui.SameLine();
                            if (ImGui.Button(temp_c_string("remove"), .{70, 30}))
                            {
                                pop(*skills_ui.fragments.value);
                            }
                            ImGui.Separator();
                                //assumes no dupliates be carefull
                                current: [Skill_Fragment_Types.NBR] string;
                                for skills_ui.fragments.value {
                                    current[it_index] = SKILL_FRAGMENT_NAMES[it.type];
                                }
                                //bottom drageables
                                for SKILL_FRAGMENT_NAMES
                                {   
                                    //create the buttons in a 3x grid
                                    if !array_find(current,it) {
                                        ImGui.PushID(*it_index);
                                        if ((it_index % 3) != 0)
                                            ImGui.SameLine();
                                        ImGui.Button(temp_c_string(SKILL_FRAGMENT_NAMES[it_index]), .{60, 60});

                                        // Our buttons are both drag sources and drag targets here!
                                        if (ImGui.BeginDragDropSource(.ImGuiDragDropFlags_None))
                                        {
                                            // Set payload to carry the index of our item
                                            ImGui.SetDragDropPayload("potato", *it_index, size_of(int));

                                            // Display preview (could be anything, e.g. when dragging an image we could decide to display
                                            // the filename and a small preview of the image, etc.)
                                            ImGui.Text("Add %", it);
                                            ImGui.EndDragDropSource();
                                        }
                                        if (ImGui.BeginDragDropTarget())
                                        {
                                            payload := ImGui.AcceptDragDropPayload("potato");
                                            if (payload)
                                            {
                                                assert(payload.DataSize == size_of(int));
                                                payload_n := <<cast(*int)payload.Data; 

                                                skills_ui.fragments.value[cast(int)payload_n] = .{.NONE,0};
                                                
                                            }
                                            ImGui.EndDragDropTarget();
                                        }
                                        ImGui.PopID();
                                    }
                                }
                            ImGui.EndTabItem();
                        }
                        if (ImGui.BeginTabItem("Details"))
                        {
                            ImGui.Text("ID: 0123456789");
                            ImGui.EndTabItem();
                        }
                        ImGui.EndTabBar();
                    }
                    ImGui.EndChild();
                    if (ImGui.Button("Revert")) {}
                    ImGui.SameLine();
                    if (ImGui.Button("Save")) {
                        broadcast_skill_change(skills_ui.networking_id,skills_ui.selected,skills_ui.fragments.value);
                    }
                    ImGui.EndGroup();
                }
            }
        }
        ImGui.End();
    }
} @System(PreRender) @Write() @Read(Skills_UI)

broadcast_skill_change :: (networking_id: Networking_ID, skill_to_update: s64, skill_info: [..] Skill_Fragment) {

    player_skill_update_packet: Player_Skill_Update_Packet;
    player_skill_update_packet.networking_id = networking_id.id;
    player_skill_update_packet.skill_to_update = skill_to_update;
    player_skill_update_packet.skill_info = skill_info;

    networking_send_packet(*player_skill_update_packet);
    
}





    


