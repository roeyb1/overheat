Spell_Instance :: struct @Tag {
}

Spell_Instance_Bundle :: struct @Bundle {
    power: Power; 
    power_change_queue: Power_Change_Queue; 
    spell_instance: Spell_Instance;
    duration: Duration;
}

CastBy :: struct @Pair { }