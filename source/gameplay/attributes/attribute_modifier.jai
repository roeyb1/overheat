Attribute_Modifier :: struct {
    multipliers: float;
    adders: float;

    duration: float;
    expires: bool;
}

EffectIdentifier :: enum {
    HASTE;
}

Effect_Identifier :: struct @Component {
    value: EffectIdentifier;
}

Active :: struct @Component {}

Stackable :: struct @Component {}

Adder :: struct @Component {}

Multiplier :: struct @Component {}

apply_adder :: (world: *World, attrib: *Attribute, modifier: Attribute_Modifier) {
    array_add(*attrib.adders, modifier.adders);
    compute_attribute(attrib);
}

apply_multiplier :: (world: *World, attrib: *Attribute, modifier: Attribute_Modifier) {
    array_add(*attrib.multipliers, modifier.multipliers);
    compute_attribute(attrib);
}

remove_adder :: (world: *World, attrib: *Attribute, modifier: Attribute_Modifier) {
    array_unordered_remove_by_value(*attrib.adders, modifier.adders);
    compute_attribute(attrib);
}

remove_multiplier :: (world: *World, attrib: *Attribute, modifier: Attribute_Modifier) {
    array_unordered_remove_by_value(*attrib.multipliers, modifier.multipliers);
    compute_attribute(attrib);
}

activate_largest_modifier :: (world: *World, parent: Entity, entity: Entity, $modifier: Type, stat: *Attribute, adder: bool) -> bool {

    target_identifier := get_component(world, entity, Effect_Identifier);
    target_modifier := get_component(world, entity, modifier);

    one := #run component_type_id(modifier);
    two := #run component_type_id(Effect_Identifier);

    component_ids: [2] Component_Type_ID = .[one,two];

    children: [..] Entity;
    children.allocator = temp;
    for * iter : make_children_iter(world, parent) {
        for iter.entities {
            if has_components(world, it, component_ids){
                if ((get_component(world, it, Effect_Identifier).value == target_identifier.value)){
                    array_add(*children, it);
                }
            }
        }
    }

    if children.count == 1 {
        if children[0] == entity {
            return true;
        }
    }

    

    highest := children[0];

    if adder {
        for children {
            if (get_component(world, it, modifier).adders > get_component(world, highest, modifier).adders) {
                highest = it;
            }
        }
        add_component(world,highest,Active);
        apply_adder(world, stat, get_component(world, highest, modifier));
    }
    else {
         for children {
            if (get_component(world, it, modifier).multipliers > get_component(world, highest, modifier).multipliers) {
                highest = it;
            }
        }
        add_component(world,highest,Active);
        apply_multiplier(world, stat, get_component(world, highest, modifier));
    }

    return false;
}

keep_largest_modifier :: (world: *World, parent: Entity, entity: Entity, $modifier: Type, stat: *Attribute, adder: bool) -> bool {

    target_identifier := get_component(world, entity, Effect_Identifier);
    target_modifier := get_component(world, entity, modifier);

    one := #run component_type_id(modifier);
    two := #run component_type_id(Effect_Identifier);
    three := #run component_type_id(Active);

    component_ids: [3] Component_Type_ID = .[one,two,three];

    children: [..] Entity;
    children.allocator = temp;
    for * iter : make_children_iter(world, parent) {
        for iter.entities {
            if has_components(world, it, component_ids){
                if ((get_component(world, it, Effect_Identifier).value == target_identifier.value)){
                    array_add(*children, it);
                }
            }
        }
    }

    if children.count == 0 {
        return true;
    }
    if adder {
        for children {
            if (get_component(world, it, modifier).adders < target_modifier.adders) {
                remove_component(world,it,Active);
                add_component(world,entity,Active);
                remove_adder(world, stat, get_component(world, it, modifier));
                apply_adder(world, stat, target_modifier);
            }
        }
    }
    else {
         for children {
            if (get_component(world, it, modifier).multipliers < target_modifier.multipliers) {
                remove_component(world,it,Active);
                add_component(world,entity,Active);
                remove_multiplier(world, stat, get_component(world, it, modifier));
                apply_multiplier(world, stat, target_modifier);
            }
        }
    }

    return false;
}

