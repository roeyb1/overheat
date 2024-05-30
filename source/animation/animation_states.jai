Anim_State :: enum u8 {
    CHARACTER_IDLE_TEMPLATE;
    CHARACTER_WALK_TEMPLATEING;
}

//has an s or an assertion fails at component_storage
Anim_State_Component :: struct {
    using #as value: Anim_State;
}

