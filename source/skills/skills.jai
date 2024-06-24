Skill :: struct @Component {}

//incorrect use a player id or something
Skill_Inventory :: struct @Component {
    skills : [..] Entity; 
}

To_Cast :: struct @Component {
    value: bool;
}


Skill_Definition :: struct @Component {}

Focus :: struct @Component {
    value: s64;
}

Ignite :: struct @Component {
    radius: Animation_Definition;
    damage: s64;
}

Project :: struct @Component {}

Skill_Fragment :: struct @Component {
    type: Skill_Fragment_Types;
    value: u64;
}

Skill_Fragment_Types :: enum u8 #specified {
    NONE        :: 0;
    PROJECT     :: 1;
    FOCUS       :: 2;
    IGNITE      :: 3;
    Duration    :: 4;
    NBR         :: 5;  
}

//need a better way this will blow cock when the enum has 100 entries
SKILL_FRAGMENT_NAMES ::
    string .[
    "",    
    "Project",
    "Focus",
    "Ignite",
    "Duration",
    ];

Fragments :: struct @Component {
    value: [..] Skill_Fragment;
}

initialize_skills :: (world: *World, entity: Entity, number_of_skills: s64) {
    inventory := get_component(*g_world, entity, Skill_Inventory);
    for 0 .. number_of_skills-1 {
        skill := spawn_entity(world, Skill_Definition, Local_Player, Name, Fragments, To_Cast);
        << get_component(world, skill, Name) = .{sprint("skill no.%", it)};
        array_add(*inventory.skills, skill);
    }
}

get_mouse_worldspace :: () -> Vector2{
    camera := get_component(*g_world, main_view_camera, Camera);
    cam_pos := get_component(*g_world, main_view_camera, Position);
    s_x, s_y := get_mouse_cursor_pos();
    v := viewspace_to_worldspace(camera.projection, cam_pos, .{cast(float)s_x, cast(float)s_y});
    return v;
}

skills_to_fire :: (q: Query) {
    casted_skills := query_get(q, To_Cast);
    names:= query_get(q, Name);
    for 0..q.count-1 {
        if(casted_skills[it].value){
            print("you casted % \n",names[it].name);
            fire_skill(q.entities[it]);
            casted_skills[it].value = false;
        }
    }
} @System(PostUpdate) @Write() @Read(Skill_Definition,To_Cast,Name)

//local player probably should only be put on the local player
fire_skill :: (skill: Entity) {
    entity := spawn_entity(*g_world, Skill);
    add_component(*g_world, entity, Local_Player);
    print("big boss % is here \n",get_component(*g_world, skill, Fragments).value);
    for get_component(*g_world, skill, Fragments).value {
        add_component_by_fragment(entity,it);
    } 
}

//skill shouldnt be an entity
//should use functions to add each probably if too many look like project
add_component_by_fragment :: (skill: Entity, fragment: Skill_Fragment) {
    if fragment.type == {
        case .PROJECT;
            add_component(*g_world, skill, Project);

            sprite := load_spritesheet("assets/players/player_character1.png",48, 0, 0,23,4);
            PLAYER_SIZE :: Vector2.{2.3, 2.3};
            add_component(*g_world, skill, Sprite, .{sprite, PLAYER_SIZE, 0, 4, 0});

            spawn_location := << get_component(*g_world, g_local_player, Position);
            add_component(*g_world, skill, Position, .{spawn_location});

            direction := unit_vector(get_mouse_worldspace()-spawn_location);
            add_component(*g_world, skill, Velocity, .{direction});

        case .FOCUS;
            add_component(*g_world, skill, Focus);
        case .IGNITE;
            add_component(*g_world, skill, Ignite);
            print("HEYA IM IGNITE\n");
        case .Duration;
            add_component(*g_world, skill, Duration);
            print("HEYA IM REPEL\n");
    }
}

focus_project :: (q: Query) {
    velocities := query_get(q, Velocity);
    positions := query_get(q, Position);
    for 0..q.count-1 {
        velocities[it].value = velocities[it].value + unit_vector(get_mouse_worldspace()-positions[it].value)*0.07;
    }
} @System(PreUpdate) @Write(Velocity) @Read(Focus,Local_Player,Project,Position)

ignite :: (q: Query) {
    //temp array of positions
    positions_to_spawn : [..] Position;
    positions_to_spawn.allocator = temp;


    positions := query_get(q, Position);
    for 0..q.count-1 {
        array_add(*positions_to_spawn,positions[it]);
    }

    for positions_to_spawn {
            entity := spawn_entity(*g_world, Sprite, Position);
            sprite := load_spritesheet("assets/orc_mage_walk_2.png",30, 0, 0,5,1);
            PLAYER_SIZE :: Vector2.{0.5, 0.5};
            add_component(*g_world, entity, Sprite, .{sprite, PLAYER_SIZE, 0, 4, 0});

            << get_component(*g_world, entity, Position) = .{it.value};

            add_component(*g_world, entity, Duration, .{5.0});
    }

} @System(OnUpdate) @Write() @Read(Ignite,Position)


use_skill0 :: (q: Query) {
    player_commands := query_get(q, Player_Commands);
    skill_inventories := query_get(q, Skill_Inventory);
    for 0..q.count-1 {
        skill := skill_inventories[it].skills[0];
        << get_component(*g_world, skill, To_Cast) = .{player_commands[it].attack1};
    }
} @System(PreUpdate) @Write() @Read(Player_Commands,Skill_Inventory)




