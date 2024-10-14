Projectile_Fragment :: struct @Component {    
}

Projectile :: struct @Component {
    direction: Vector2;
}

Projectile_Bundle :: struct @Bundle {
    sprite: Sprite; 
    size: Size; 
    move_speed: Move_Speed;
    velocity: Velocity;
    invoker: Collision_Invoker;
    projectile: Projectile;
}
#if SERVER{
    add_projectile :: (world: *World, entity: Entity) {
        cast_by := ecs_get_target(world, entity, CastBy);
        
        if entity_is_valid(world,cast_by){
            spritesheet := "assets/skills/blue_orb.png";
            
             PROJECTILE_BASE_SIZE :: 1;
             PROJECTILE_BASE_SPEED :: 10.0;

            ecs_add_bundle(world, entity, Projectile_Bundle.{
                sprite = .{spritesheet, null, .{0,0}, 0, 4, 0},
                size = .{PROJECTILE_BASE_SIZE,0},
                move_speed = .{PROJECTILE_BASE_SPEED},
            }); 
            
            // //set the default target of the projectile, this can be overwritten by other systems
            position := ecs_get(world, entity, Position).value;
            ecs_add(world, entity, Target_Location.{random_target_direction(position)});
        }
    }

    //when the projectile fragment is added a projectile entity is created in a seperate spell instance
    add_projectile_fragment :: (world: *World, entity: Entity) {
        projectile_fragments := cast(*Projectile_Fragment)ecs_add(world, entity, Projectile_Fragment);
        new_projectile := entity_spawn(world);
        //make sure the next created entity is a projectile proper
        array_add(*ecs_get(world, entity, Fragment_Storage).fragments_to_pass, .Projectile);
        spawn_triggered_spell_instance(world, entity, new_projectile);

        if(ecs_get(world, entity, Active)) {
            ecs_add(world, new_projectile, Active);
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
        for 0..q.count-1 {
            parent := ecs_get_target(q.world, q.entities[it], CastBy);
            if entity_is_valid(q.world,parent){
                parent_position := ecs_get(q.world, parent, Position).value;
                positions[it].value = parent_position;
            }
        }
    } @System(OnUpdate) @Write(Position) @Read(Projectile,Spell_Instance,Position,Powering_Up)

    //if events could implicit check for additional components that would be pog
    //also if validating components exist it would be nice, i feel like a query here would be annoying due to the trigger nature of this event
    finalise_projectile_casting :: (world: *World, entity: Entity) {
        if ecs_get(world, entity, Projectile){

            position := ecs_get(world, entity, Position).value;
            projectile := ecs_get(world, entity, Projectile);
            targeting := ecs_get(world, entity, Target_Location).value;
            //likely not super safe
            
            projectile.direction = unit_vector(targeting-position);
        }
    } @Event(EcsOnAdd,Active)

    random_target_direction :: (position: Vector2) -> Vector2{
        random_degree := random_get_within_range(0, 360);
        return position + rotate(.{0,1},random_degree);
    }
}