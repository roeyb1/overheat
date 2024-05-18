#scope_module

ImVector :: struct (T: Type) {
    Size: s32;
    Capacity: s32;
    Data: *T;
}

#if OS == .WINDOWS {
    #load "windows.jai";
} else {
    #load "unix.jai";
}

#import "ImGui";
