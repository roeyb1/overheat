Attribute :: struct {
    multipliers: [..] float;
    adders: [..] float;

    base_value: float; 
    value: float;
}

Move_Speed :: struct @Component {
    using #as attrib: Attribute;
}

Attribute_Modifier :: struct {
    multipliers: float;
    adders: float;

    duration: float;
    expires: bool;
}

Move_Speed_Modifier :: struct @Component {
    using #as modifier: Attribute_Modifier;
}

compute_attribute :: (attrib: *Attribute) {
    adder := attrib.base_value;
    multiplier := 1.;
    for attrib.adders {
        adder += it;
    }
    for attrib.multipliers {
        multiplier = multiplier * it;
    }
    attrib.value = adder * multiplier;
}

apply_buff :: (world: *World, attrib: *Attribute, modifier: Attribute_Modifier) {
    array_add(*attrib.adders, modifier.adders);
    array_add(*attrib.multipliers, modifier.multipliers);
    compute_attribute(attrib);
}

remove_buff :: (world: *World, attrib: *Attribute, modifier: Attribute_Modifier) {
    array_unordered_remove_by_value(*attrib.adders, modifier.adders);
    array_unordered_remove_by_value(*attrib.multipliers, modifier.multipliers);
    compute_attribute(attrib);
}
/*
apply_move_speed_modifier :: (q: Query) {
    modifiers := query_get(q, Move_Speed_Modifier);
    
    for 0..q.count -1 {
        parent := get_parent(q.world, q.entities[it]);
        move_speed := get_component(q.world, parent, Move_Speed);

        apply_buff(q.world, move_speed, modifiers[it]);
        //log("hello i am % and my speed is %", get_component(q.world, parent, Name).name,get_component(q.world, parent, Move_Speed).value);
    }
    

} @System(PreUpdate) @Write() @Read(Move_Speed_Modifier) @OptionalWrite(Move_Speed)*/

apply_move_speed_modifier :: (world: *World, entity: Entity) {
    print("hello i am % \n",get_component(world, entity, Move_Speed_Modifier).multipliers);
    parent := get_parent(world, entity);
    move_speed := (get_component(world, parent, Move_Speed));
    apply_buff(world, move_speed, get_component(world, entity, Move_Speed_Modifier));
} @Event(EcsOnAdd,Move_Speed_Modifier)

reset_move_speed :: (q: Query) {
    speeds := query_get(q, Move_Speed);
    for 0..q.count-1 {
        speeds[it].multipliers.count = 0;
        speeds[it].adders.count = 0;
        compute_attribute(*speeds[it]);
    }
} @System(PostUpdate) @Write(Move_Speed) @Read() 


