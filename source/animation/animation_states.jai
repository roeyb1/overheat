Anim_State :: enum u8 {
    IDLE;
    WALK;
}

Anim_State_Component :: struct {
    using #as value: Anim_State;
}

