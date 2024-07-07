Skill :: struct @Component {}

Target_Entity :: struct @Component {
    value: Entity;
}

Current_Target :: struct @Component {
    value: Vector2;
}

Charged_Spell :: struct @Component {}

Powering_Up :: struct @Component {}

Power :: struct @Component {
    incoming: float;
    total: float;
}

Dividends :: struct @Component {
    value: [..] Skill_Fragment_Types;
}

//TODO add some targetting or smt such
Skill_Instance_Bundle :: struct @Bundle {
    power: Power;
    dividends: Dividends;
    powering_up: Powering_Up;
}

fire_skill :: (world: *World, skill: Entity, casting_entity: Networking_ID) {
    cooldown := get_component(world, skill, Cooldown);
    if cooldown.current_value <= 0 {
        cooldown.current_value = cooldown.base_value;  


        valid,player := get_player_by_networking_id(world,casting_entity);

        if valid {

            skill_instance := spawn_child_entity(world, player);
            add_components_from_bundle(world, skill_instance, Skill_Instance_Bundle.{});

            for get_component(world, skill, Fragments).value {
                add_component_by_fragment(world ,skill_instance, player, it);
            } 
            get_component(world, skill_instance, Power).incoming = get_component(world, skill, Test).value; 
        }
    }
}

test :: (q: Query) {

    for 0..q.count-1 {
        remove_component(q.world,q.entities[it],Powering_Up);
        add_component(q.world,q.entities[it],Charged_Spell);
    }
} @System(PostUpdate) @Write(Powering_Up) @Read()

testing :: (q: Query) {

    for 0..q.count-1 {
        destroy_entity(q.world, q.entities[it]);
    }
} @System(PostUpdate) @Write(Charged_Spell) @Read()


add_component_by_fragment :: (world: *World, skill: Entity,  casting_entity: Entity, fragment: Skill_Fragment) {
    if fragment.type == {
        case .Projectile;
     
            //add_project(world,skill,3,casting_entity);

        case .Ignite;
            //@TODO make it so u dont have to get component every time
            //add_ignite(world,skill,3,get_component(world, skill, Target_Entity).value);
        case .Haste;

            add_haste(world,skill);
        
        case .Self;

            add_self(world,skill,casting_entity);

    }
}

get_mouse_worldspace :: () -> Vector2 {
    viewport := get_singleton(*g_world, Game_Viewport);
    camera := get_component(*g_world, viewport.main_camera, Camera);
    cam_pos := get_component(*g_world, viewport.main_camera, Position);
    s_x, s_y := get_mouse_cursor_pos();
    v := viewspace_to_worldspace(camera.projection, cam_pos, .{cast(float)s_x, cast(float)s_y});
    return v;
}

get_player_by_networking_id :: (world: *World, networking_id: Networking_ID) -> bool,Entity {
    for q : make_iter(world, Player, Networking_ID) {
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
#load "skill_fragments/haste.jai";
#load "skill_fragments/projectile.jai";
#load "skill_fragments/self.jai";
#load "skill_definition.jai";

