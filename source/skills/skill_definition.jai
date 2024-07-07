Skill_Inventory :: struct @Component {
    skills : [..] Entity; 
}

Skill_Definition :: struct @Component {}

To_Cast :: struct @Component {
    value: bool;
}

Fragments :: struct @Component {
    value: [..] Skill_Fragment;
}

Skill_Fragment :: struct {
    type: Skill_Fragment_Types;
    value: u64;
}

Skill_Fragment_Types :: enum u8 {
    None;
    Projectile;
    Ignite;
    Haste;
    Self;
}

Test :: struct @Component {
    value: float;
}

SKILL_FRAGMENT_NAMES :: #run enum_names(Skill_Fragment_Types);
NUM_SKILL_FRAGMENTS :: #run enum_highest_value(Skill_Fragment_Types);

Skill_Definition_Bundle :: struct @Bundle {
    skill_definition: Skill_Definition;
    networking_id: Networking_ID;
    name: Name;
    fragments: Fragments;
    to_cast: To_Cast;
    cooldown: Cooldown;
    power: Test;
}

initialize_skills :: (world: *World, entity: Entity, number_of_skills: s64, networking_id: u64) {
    inventory := get_component(world, entity, Skill_Inventory);
    for 0 .. number_of_skills-1 {

        new_skill_definition := spawn_entity_from_bundle(*g_world, Skill_Definition_Bundle.{
            name = .{sprint("skill no.%", it)},
            networking_id = .{networking_id},
            cooldown = .{0.5,0},
            power = .{pow(50,(1. + it))+300}
        });

        array_add(*inventory.skills, new_skill_definition);
    }
}

skills_to_fire :: (q: Query) {
    casted_skills := query_get(q, To_Cast);
    names := query_get(q, Name);
    networking_ids := query_get(q, Networking_ID);

    for 0..q.count-1 {
        if casted_skills[it].value {
            fire_skill(q.world, q.entities[it],networking_ids[it]);

            casted_skills[it].value = false;
        }
    }
} @System(PostUpdate) @Write() @Read(Skill_Definition,To_Cast,Name,Networking_ID)

use_skill0 :: (q: Query) {
    player_commands := query_get(q, Player_Commands);
    skill_inventories := query_get(q, Skill_Inventory);
    networking_ids := query_get(q, Networking_ID);

    
    for 0..q.count-1 {
        skill := skill_inventories[it].skills[0]; //@Todo shit
        


        if get_component(q.world, q.entities[it],Local_Player){
            << get_component(q.world, q.entities[it],Current_Target) = .{get_mouse_worldspace()};
            broadcast_skill_targeting(networking_ids[it], get_mouse_worldspace());
        }

        << get_component(*g_world, skill, To_Cast) = .{player_commands[it].attack1};
    }

} @System(PreUpdate) @Write() @Read(Player_Commands,Skill_Inventory)

use_skill1 :: (q: Query) {
    player_commands := query_get(q, Player_Commands);
    skill_inventories := query_get(q, Skill_Inventory);
    networking_ids := query_get(q, Networking_ID);

    
    for 0..q.count-1 {
        skill := skill_inventories[it].skills[1]; //@Todo shit


        if get_component(q.world, q.entities[it],Local_Player){
            << get_component(q.world, q.entities[it],Current_Target) = .{get_mouse_worldspace()};
            broadcast_skill_targeting(networking_ids[it], get_mouse_worldspace());
        }

        << get_component(*g_world, skill, To_Cast) = .{player_commands[it].attack2};
    }
    
} @System(PreUpdate) @Write() @Read(Player_Commands,Skill_Inventory)