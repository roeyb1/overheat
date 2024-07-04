UI_SCALE :: 1.5;

ui_size :: inline (size: Vector2) -> ImGui.ImVec2 {
    return ImGui.ImVec2.{size.x * UI_SCALE, size.y * UI_SCALE};
}

HEALTH_COLOR :: #run ImGui.IM_COL32(204, 0, 0);
RESOURCE_COLOR :: #run ImGui.IM_COL32(53, 120, 200);


#load "healthbar.jai";
#load "hud.jai";
#load "widgets.jai";