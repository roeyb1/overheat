UI_SCALE :: 1.5;

ui_size :: inline (size: Vector2) -> ImGui.ImVec2 {
    return ImGui.ImVec2.{size.x * UI_SCALE, size.y * UI_SCALE};
}

HEALTH_COLOR :: #run ImGui.IM_COL32(255, 0, 0);
RESOURCE_COLOR :: #run ImGui.IM_COL32(66, 150, 250);


#load "healthbar.jai";
#load "hud.jai";