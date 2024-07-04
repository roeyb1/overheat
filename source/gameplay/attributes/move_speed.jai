
Move_Speed :: struct @Component {
    using #as attrib: Attribute;
}

Move_Speed_Modifier :: struct @Component {
    using #as modifier: Attribute_Modifier;
}

remove_move_speed_modifier :: (world: *World, entity: Entity) {
    parent := get_parent(world, entity);
    move_speed := (get_component(world, parent, Move_Speed));
    
    should_add := false;
    if get_component(world, entity, Adder) {
        should_add = true;
    }

    if should_add {
        remove_adder(world, move_speed, get_component(world, entity, Move_Speed_Modifier));
    }
    else {
        remove_multiplier(world, move_speed, get_component(world, entity, Move_Speed_Modifier));
    } 

    if !get_component(world, entity, Stackable) {
        activate_largest_modifier(world, parent, entity, Move_Speed_Modifier, move_speed, should_add);
    }
} @Event(EcsOnRemove,Move_Speed_Modifier)

apply_move_speed_modifier :: (world: *World, entity: Entity) {
    first_instance := false;
    parent := get_parent(world, entity);
    move_speed := (get_component(world, parent, Move_Speed));

    should_add := false;

    if get_component(world, entity, Adder) {
        should_add = true;
    }

    if !get_component(world, entity, Stackable) {

        //return true if it's the first instance of the buff
        if keep_largest_modifier(world, parent, entity, Move_Speed_Modifier, move_speed, should_add) {
            
            add_component(world,entity,Active);

            if should_add {
                apply_adder(world, move_speed, get_component(world, entity, Move_Speed_Modifier));
            }
            else {
                apply_multiplier(world, move_speed, get_component(world, entity, Move_Speed_Modifier));
            } 
        }
    }
    else {
        add_component(world,entity,Active);

        if should_add {
            apply_adder(world, move_speed, get_component(world, entity, Move_Speed_Modifier));
        }
        else {
            apply_multiplier(world, move_speed, get_component(world, entity, Move_Speed_Modifier));
        } 
    }
} @Event(EcsOnAdd,Move_Speed_Modifier)
