Projectile :: struct @Component {
    direction: Vector2;
}

#if SERVER {
Projectile_Bundle :: struct @Bundle {
    sprite: Sprite; 
    size: Size; 
    position: Position;
    move_speed: Move_Speed;
    projectile: Projectile;
    invoker: Collision_Invoker;
}

add_projectile :: (world: *World, skill: Entity){
    parent := get_component(world, skill, Skill).parent;
    node_id := get_component(world, skill, Networking_ID).id;
    if is_valid(world,parent){

        spritesheet := "assets/skills/blue_orb.png";
        PROJECTILE_BASE_SIZE :: 0.1;
        PROJECTILE_BASE_SPEED :: 10.0;

        add_components_from_bundle(world, skill, Projectile_Bundle.{
            sprite = .{spritesheet, null, .{0,0}, 0, 4, 0},
            size = .{multiplier = PROJECTILE_BASE_SIZE},
            move_speed = .{PROJECTILE_BASE_SPEED},
            invoker = .{node_id.id, true},
        }); 
    }
}

projectile_movement :: (q: Query) {
    projectiles := query_get(q, Projectile);
    movement_speeds := query_get(q, Move_Speed);
    velocities := query_get(q, Velocity);
    for 0..q.count-1 {
        velocities[it].value = projectiles[it].direction * movement_speeds[it].speed;
    }
} @System(OnUpdate) @Write(Velocity) @Read(Projectile,Move_Speed,Active)

//@TODO if possible we should add some kind of socket on the casting entity so the skill can follow his hands or something
update_projectile_position_while_charging :: (q: Query) {
    positions := query_get(q, Position);
    skills := query_get(q, Skill);
    for 0..q.count-1 {
        parent := skills[it].parent;
        if is_valid(q.world,parent){
            parent_position := get_component(q.world, parent, Position).value;
            positions[it].value = parent_position;
        }
    }
} @System(OnUpdate) @Write(Position) @Read(Projectile,Powering_Up,Skill)

finalise_projectile_casting :: (world: *World, entity: Entity) {
        PROJECTILE_COLLIDER_SIZE :: Vector2.{1., 1.};

        if get_component(world, entity, Projectile){
            parent := get_component(world, entity, Skill).parent;
            if is_valid(world,parent) { 
                spawn_location := get_component(world, parent, Position).value;
                log("%",spawn_location);
                add_component(world, entity, Position, .{spawn_location});


                targeting := get_component(world, parent, Player_Commands).cursor_position;
                direction := unit_vector(targeting-spawn_location);

            
                add_component(world, entity, Projectile, .{direction});
                add_component(world, entity, Velocity);

                add_component(world, entity, Collider_AABB, .{ aabb = make_aabb(.{ 0, 0 }, PROJECTILE_COLLIDER_SIZE)});
            }
        }
} @Event(EcsOnAdd,Active)

projectile_collide :: (world: *World, entity: Entity) {
        overlap := get_component(world, entity, Overlap_Pair);
        if get_component(world, entity, Overlap_Pair){
            skill,target,found := get_skill_from_overlap_pair(world, overlap.a, overlap.b);
            if found {
                
                
                
            }
        }
} @Event(EcsOnAdd,Overlap_Pair)
}

