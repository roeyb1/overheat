Projectile :: struct @Component {
    direction: Vector2;
}

Projectile_Bundle :: struct @Bundle {
    sprite: Sprite; 
    size: Size; 
    position: Position;
    move_speed: Move_Speed;
    velocity: Velocity;
    invoker: Collision_Invoker;
}

add_projectile :: (world: *World, entity: Entity) {
    parent := ecs_get_target(world, entity, CastBy);
    
    if entity_is_valid(world,parent){
        spritesheet := "assets/skills/blue_orb.png";
        PROJECTILE_BASE_SIZE :: 1;
        PROJECTILE_BASE_SPEED :: 10.0;

        ecs_add_bundle(world, entity, Projectile_Bundle.{
            sprite = .{spritesheet, null, .{0,0}, 0, 4, 0},
            size = .{PROJECTILE_BASE_SIZE,0},
            position = ecs_get(world, parent, Position),
            move_speed = .{PROJECTILE_BASE_SPEED},
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
} @System(OnUpdate) @Write(Velocity) @Read(Projectile,Move_Speed,Active)

//@TODO if possible we should add some kind of socket on the casting entity so the skill can follow his hands or something
update_projectile_position_while_charging :: (q: Query) {
    positions := query_get(q, Position);
    for 0..q.count-1 {
        parent := ecs_get_target(q.world, q.entities[it], CastBy);
        if entity_is_valid(q.world,parent){
            parent_position := ecs_get(q.world, parent, Position).value;
            positions[it].value = parent_position;
        }
    }
} @System(OnUpdate) @Write(Position) @Read(Projectile,Spell_Instance,Position,Powering_Up)

//if events could implicit check for additional components that would be pog
finalise_projectile_casting :: (world: *World, entity: Entity) {

        if ecs_get(world, entity, Projectile){
            parent := ecs_get_target(world, entity, CastBy);
            position := ecs_get(world, entity, Position);
            projectile := ecs_get(world, entity, Projectile);
            if entity_is_valid(world,parent) { 

                targeting := ecs_get(world, parent, Player_Commands).cursor_position;
                projectile.direction = unit_vector(targeting-position);

               
            }
        }
} @Event(EcsOnAdd,Active)

