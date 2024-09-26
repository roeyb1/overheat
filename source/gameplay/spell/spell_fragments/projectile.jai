Projectile :: struct @Component {
    direction: Vector2;
}

Projectile_Bundle :: struct @Bundle {
    sprite: Sprite; 
    size: Size; 
    position: Position;
    move_speed: Move_Speed;
    invoker: Collision_Invoker;
}

add_projectile :: (world: *World, entity: Entity) {
    parent := ecs_get_target(world, entity, CastBy);
    if entity_is_valid(world,parent){
        spritesheet := "assets/skills/blue_orb.png";
        PROJECTILE_BASE_SIZE :: 10;
        PROJECTILE_BASE_SPEED :: 10.0;

        ecs_add_bundle(world, entity, Projectile_Bundle.{
            sprite = .{spritesheet, null, .{0,0}, 0, 4, 0},
            size = .{multiplier = PROJECTILE_BASE_SIZE},
            move_speed = .{PROJECTILE_BASE_SPEED},
            invoker = .{ id = cast(u64) entity.raw },
        }); 
    }
} @Event(EcsOnAdd,Projectile)

projectile_movement :: (q: Query) {
    projectiles := query_get(q, Projectile);
    movement_speeds := query_get(q, Move_Speed);
    velocities := query_get(q, Velocity);
    for 0..q.count-1 {
        velocities[it].value = projectiles[it].direction * movement_speeds[it].speed;
    }
} @System(OnUpdate) @Write(Velocity) @Read(Projectile,Move_Speed)

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