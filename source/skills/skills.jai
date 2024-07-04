Skill :: struct @Component {}

Skill_Definition :: struct @Component {}

Skill_Inventory :: struct @Component {
    skills : [..] Entity; 
}

Target_Entity :: struct @Component {
    value: Entity;
}

To_Cast :: struct @Component {
    value: bool;
}

Current_Target :: struct @Component {
    value: Vector2;
}

Fragments :: struct @Component {
    value: [..] Skill_Fragment;
}

Skill_Fragment :: struct {
    type: Skill_Fragment_Types;
    value: u64;
}

Skill_Fragment_Types :: enum u8 {
    NONE;
    PROJECT;
    SELF;
    TOUCH;
    FOCUS;
    IGNITE;
    Haste;
    NBR;  
}

//need a better way this will blow cock when the enum has 100 entries
SKILL_FRAGMENT_NAMES ::
    string .[
    "",   
    "Project",
    "Self",
    "Touch",
    "Focus",
    "Ignite",
    "Haste",
    ];


Skill_Definition_Bundle :: struct @Bundle {
    skill_definition: Skill_Definition;
    networking_id: Networking_ID;
    name: Name;
    fragments: Fragments;
    to_cast: To_Cast;
    cooldown: Cooldown;
}

Skill_Instance_Bundle :: struct @Bundle {
    target_entity: Target_Entity;
}

//take a skill component directly
initialize_skills :: (world: *World, entity: Entity, number_of_skills: s64, networking_id: u64) {
    inventory := get_component(world, entity, Skill_Inventory);
    for 0 .. number_of_skills-1 {

        new_skill_definition := spawn_from_bundle(*g_world, Skill_Definition_Bundle.{
            name = .{sprint("skill no.%", it)},
            networking_id = .{networking_id},
            cooldown = .{0.5,0},
        });

        array_add(*inventory.skills, new_skill_definition
        );
    }
}

skills_to_fire :: (q: Query) {

    casted_skills := query_get(q, To_Cast);
    names := query_get(q, Name);
    networking_ids := query_get(q, Networking_ID);

    for 0..q.count-1 {
        if(casted_skills[it].value){
            print("you casted % \n",names[it].name);

            fire_skill(q.world, q.entities[it],networking_ids[it]);

            casted_skills[it].value = false;
        }
    }
} @System(PostUpdate) @Write() @Read(Skill_Definition,To_Cast,Name,Networking_ID)


fire_skill :: (world: *World, skill: Entity, casting_entity: Networking_ID) {
    cooldown := get_component(world, skill, Cooldown);
    if cooldown.current_value <= 0 {

        cooldown.current_value = cooldown.base_value;  

        valid,player := get_player_by_networking_id(world,casting_entity);

        if valid {
            skill_instance := spawn_from_bundle(*g_world, Skill_Instance_Bundle.{
            target_entity = .{player},
            });

            for get_component(world, skill, Fragments).value {
                add_component_by_fragment(world ,skill_instance, player, it);
            } 
        }
    }
}

add_component_by_fragment :: (world: *World, skill: Entity,  casting_entity: Entity, fragment: Skill_Fragment) {
    if fragment.type == {
        case .PROJECT;
     
            add_project(world,skill,3,casting_entity);
        case .TOUCH;
     
            add_touch(world,skill,3,casting_entity);
        case .SELF;

            add_self(world,skill,3,casting_entity);
        case .FOCUS;

            add_focus(world, skill,3);
        case .IGNITE;

            add_ignite(world,skill,3);
        case .Haste;

            add_haste(world,skill,3, get_component(world, skill, Target_Entity).value );

    }
}

use_skill0 :: (q: Query) {
    player_commands := query_get(q, Player_Commands);
    skill_inventories := query_get(q, Skill_Inventory);
    networking_ids := query_get(q, Networking_ID);

    
    for 0..q.count-1 {
        skill := skill_inventories[it].skills[0];


        if get_component(q.world, q.entities[it],Local_Player){
            << get_component(q.world, q.entities[it],Current_Target) = .{get_mouse_worldspace()};
            broadcast_skill_targeting(networking_ids[it], get_mouse_worldspace());
        }

        << get_component(*g_world, skill, To_Cast) = .{player_commands[it].attack1};
    }
} @System(PreUpdate) @Write() @Read(Player_Commands,Skill_Inventory)

get_mouse_worldspace :: () -> Vector2{
    camera := get_component(*g_world, main_view_camera, Camera);
    cam_pos := get_component(*g_world, main_view_camera, Position);
    s_x, s_y := get_mouse_cursor_pos();
    v := viewspace_to_worldspace(camera.projection, cam_pos, .{cast(float)s_x, cast(float)s_y});
    return v;
}

get_player_by_networking_id :: (world: *World, networking_id: Networking_ID) -> bool,Entity {
    for q : make_iter(world, Player, Networking_ID)
        {
            networking_ids := query_get(q, Networking_ID);
            for 0..q.count-1 {
                if networking_ids[it].id == networking_id.id {
                    return true,q.entities[it];
                }
            }
        }
    return false,.{};
}

broadcast_skill_targeting :: (networking_id: Networking_ID, position: Vector2) {

    targeting_info_packet: Targeting_Info_Packet;
    targeting_info_packet.networking_id = networking_id.id;
    targeting_info_packet.position = position;

    networking_send_packet(*targeting_info_packet);
}

#load "skill_fragments/ignite.jai";
#load "skill_fragments/focus.jai";
#load "skill_fragments/haste.jai";
#load "skill_fragments/project.jai";
#load "skill_fragments/touch.jai";
#load "skill_fragments/self.jai";

