
fragments: *Fragments; //does this need to exist?
name: string;
fragment_bank : [Skill_Fragment_Types.NBR] string; //doesnt need to exist
selected: *Entity;
valid: bool;

Skills_UI :: struct @SingletonComponent {
    is_open: bool;
}

open_skills_menu :: (q: Query) {
    input_states := get_singleton(q.world, Input_States);
    skills_ui := get_singleton(q.world, Skills_UI);

    if is_button_pressed(input_states, .OPEN_SKILLS_UI) {
        skills_ui.is_open = !skills_ui.is_open;
        if skills_ui.is_open {
            fragment_bank = SKILL_FRAGMENT_NAMES;
        }
    }
} @System(PreRender) @Write(Skills_UI) @Read(Input_States)

//not sure how to access a specific players info in a esc friendly way 
//should copy data and ship it when ready
//use a singleton to store the data
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
                //this spawns them in completely random order, perhaps fix
                for q : make_iter(q.world, Local_Player, Skill_Definition, Name, Fragments)
                {
                    names := query_get(q, Name);
                    selected_fragments := query_get(q, Fragments);
                    for 0..q.count-1 {
                        if (ImGui.Selectable(temp_c_string(tprint("%",names[it].name)))) {
                            selected = *q.entities[it];
                            fragments = *selected_fragments[it];
                            name = names[it].name;
                            valid = true;
                        }
                    }
                }
                ImGui.EndChild();
            }
            ImGui.SameLine();
            if valid {
                // Right
                {
                    ImGui.BeginGroup();
                    ImGui.BeginChild("item view", .{0,-ImGui.GetFrameHeightWithSpacing()}); // Leave room for 1 line below us
                    ImGui.Text(sprint("%", name));
                    //how to stop the title from appearing
                    ImGui.Separator();
                    if (ImGui.BeginTabBar("##Tabs", .ImGuiTabBarFlags_None))
                    {
                        //top drageables
                        if (ImGui.BeginTabItem("Fragments"))
                        {       
                            if (ImGui.BeginListBox("current fragments", .{400,100})){
                                for fragments.value
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

                                                fragments.value[it_index] = .{cast(Skill_Fragment_Types)payload_n,0};
                                            }
                                            ImGui.EndDragDropTarget();
                                        }
                                    ImGui.PopID();
                                }
                                ImGui.EndListBox();
                            }
                            if (ImGui.Button(temp_c_string("add"), .{40, 30}))
                            {
                                array_add(*fragments.value, .{.NONE,0});
                            }
                            ImGui.SameLine();
                            if (ImGui.Button(temp_c_string("remove"), .{70, 30}))
                            {
                                pop(*fragments.value);
                            }
                            ImGui.Separator();
                                //assumes no dupliates be carefull
                                current: [Skill_Fragment_Types.NBR] string;
                                for fragments.value {
                                    current[it_index] = SKILL_FRAGMENT_NAMES[it.type];
                                }
                                //bottom drageables
                                for fragment_bank
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

                                                fragments.value[cast(int)payload_n] = .{.NONE,0};
                                                
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
                    if (ImGui.Button("Save")) {}
                    ImGui.EndGroup();
                }
            }
        }
        ImGui.End();
    }
} @System(PreRender) @Write() @Read(Skills_UI)





    


