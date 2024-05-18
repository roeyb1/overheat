// Bindings for Dear ImGui.

ImVec2      :: Vector2;
ImVec4      :: Vector4;
ImColor     :: Vector4;

ImVector :: struct (T: Type) {
    Size: s32;
    Capacity: s32;
    Data: *T;
}

ImDrawCallback :: #type (parent_list: *ImDrawList, cmd: *ImDrawCmd) #c_call;

IM_COL32 :: inline (r: u8, g: u8, b: u8, a: u8 = 255) -> u32 {
    return ((cast(ImU32)(a)) << IM_COL32_A_SHIFT)
         | ((cast(ImU32)(b)) << IM_COL32_B_SHIFT)
         | ((cast(ImU32)(g)) << IM_COL32_G_SHIFT)
         | ((cast(ImU32)(r)) << IM_COL32_R_SHIFT);
}

#scope_module

#import "Basic";
#import "Math";

#if OS == .WINDOWS {
    #load "windows.jai";
    user32 :: #library,system,link_always "user32";
} else {
    #load "unix.jai";
}

