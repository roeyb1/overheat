Spell_Instance :: struct @Tag {
}

Spell_Instance_Bundle :: struct @Bundle {
    power: Power; 
    energy_change_queue: Energy_Change_Queue; 
    spell_instance: Spell_Instance;
    duration: Duration;
    networking_id: Networked;
}

CastBy :: struct @Pair { }