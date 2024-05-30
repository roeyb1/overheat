Anim_State :: enum u8 {
    CHARACTER_IDLE_DEFINITION;
    CHARACTER_WALK_DEFINITION;
}

Anim_State_Component :: struct {
    using #as value: Anim_State;
}

