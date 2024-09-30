Spell_Instance :: struct @Tag {
}

//when a spell instance is spawned into the world it will be in a state where it gathers power known as Powering_Up, no interaction with the world.
//once a spell is fully charged or sent out for whatever reason it becomes Active and can interact with the world. 
Powering_Up :: struct @Component {}
Active :: struct @Component {}

Spell_Instance_Bundle :: struct @Bundle {
    spell_instance: Spell_Instance;
    power: Power; 
    energy_change_queue: Energy_Change_Queue; 
    powering_up: Powering_Up;
    duration: Duration;
    networking_id: Networked;
}

CastBy :: struct @Pair { }