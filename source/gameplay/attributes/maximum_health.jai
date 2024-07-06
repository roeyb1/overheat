
Maximum_Health :: struct @Component {
    using #as attrib: Attribute;
}

Maximum_Health_Modifier :: struct @Component {
    using #as modifier: Attribute_Modifier;
}

remove_maximum_health_modifier :: (world: *World, entity: Entity) {
    parent := get_parent(world, entity);
    maximum_health := get_component(world, parent, Maximum_Health);
    
    should_add := false;
    if get_component(world, entity, Adder) {
        should_add = true;
    }

    if should_add {
        remove_adder(world, maximum_health, get_component(world, entity, Maximum_Health_Modifier));
    }
    else {
        remove_multiplier(world, maximum_health, get_component(world, entity, Maximum_Health_Modifier));
    } 

    if !get_component(world, entity, Stackable) {
        activate_largest_modifier(world, parent, entity, Maximum_Health_Modifier, maximum_health, should_add);
    }
} @Event(EcsOnRemove,Maximum_Health_Modifier)

apply_maximum_health_modifier :: (world: *World, entity: Entity) {
    first_instance := false;
    parent := get_parent(world, entity);
    maximum_health := get_component(world, parent, Maximum_Health);

    should_add := false;

    if get_component(world, entity, Adder) {
        should_add = true;
    }

    if !get_component(world, entity, Stackable) {

        //return true if it's the first instance of the buff
        if keep_largest_modifier(world, parent, entity, Maximum_Health_Modifier, maximum_health, should_add) {
            
            add_component(world,entity,Active);

            if should_add {
                apply_adder(world, maximum_health, get_component(world, entity, Maximum_Health_Modifier));
            }
            else {
                apply_multiplier(world, maximum_health, get_component(world, entity, Maximum_Health_Modifier));
            } 
        }
    }
    else {
        add_component(world,entity,Active);

        if should_add {
            apply_adder(world, maximum_health, get_component(world, entity, Maximum_Health_Modifier));
        }
        else {
            apply_multiplier(world, maximum_health, get_component(world, entity, Maximum_Health_Modifier));
        } 
    }
} @Event(EcsOnAdd,Maximum_Health_Modifier)
