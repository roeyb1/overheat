UI_SCALE :: 1.5;

ui_size :: inline (size: Vector2) -> ImGui.ImVec2 {
    return ImGui.ImVec2.{size.x * UI_SCALE, size.y * UI_SCALE};
}

#load "healthbar.jai";