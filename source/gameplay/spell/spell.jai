Spell :: struct @Component {
    components: [..] Type;
}

Spell_Bundle :: struct @Bundle {
    spell: Spell;
}

TriggeredBy :: struct @Pair { }

//when a spell is spawned into the world it will be in a state where it gathers power known as Spell_Charging, no interaction with the world.
//once a spell is fully charged or sent out for whatever reason it becomes Spell_Active and can interact with the world. 
Spell_Charging :: struct @Tag {}

Spell_Active :: struct @Tag {}

test_spell :: (world: *World, spell: Entity) {
    log("spell cast");
}



