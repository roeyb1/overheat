//touch is a vector by which fragments can be applied when a collision is generated
Damage :: struct @Component {}

add_damage :: (world: *World, skill: Entity){ 
    add_component(world, skill, Damage);
}

