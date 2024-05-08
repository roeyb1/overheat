
/**
 * Attribute enum that defines all the different types of attributes an entity can have.
 */
Attribute :: enum u32 {
    HEALTH;
    MAX_HEALTH;
    SPEED;
    NUM;
}

/**
 * AttributeType defines how the modifier is applied to the base attribute value.
 * ADDITIVE attributes will be added directly to the base value of a given attribute.
 * MULTIPLICATIVE attributes will be summed together and then multiply the base attribute.
 */
AttributeType :: enum {
    ADDITIVE;
    MULTIPLICATIVE;
}

/**
 * Attribute_Component struct stores all base attribute values and any modifiers that apply to them.
 */
Attribute_Component :: struct {
    base: [Attribute.NUM] float;
    add_mods: [Attribute.NUM][..] float;
    mul_mods: [Attribute.NUM][..] float;
}

/** Computes the current value of an attribute after all modifiers are applied. */
get_current_attribute_value :: (attrib: Attribute, attrib_comp: Attribute_Component) -> float {
    base: float = attrib_comp.base[attrib];

    for attrib_comp.add_mods[attrib] {
        base += it;
    }

    multiplier := 1.;
    for attrib_comp.mul_mods[attrib] {
        multiplier *= it;
    }

    return base * multiplier;
}

/** Adds a new attribute modifier for a specified attribute to an attribute component. */
add_attribute_modifier :: (attrib: Attribute, val: float, type: AttributeType, attrib_comp: Attribute_Component) {
    if type == {
        case .ADDITIVE;
            array_add(*attrib_comp.add_mods[attrib], val);
        case .MULTIPLICATIVE;
            array_add(*attrib_comp.mul_mods[attrib], val);
    }
}


/** Removes an attribute modifier for a from an attribute component that matches the exact passed values. */
// #todo: maybe we can remove modifiers a better way?
remove_attribute_modifier :: (attrib: Attribute, val: float, type: AttributeType, attrib_comp: Attribute_Component) {
    if type == {
        case .ADDITIVE;
            array_unordered_remove_by_value(*attrib_comp.add_mods[attrib], val);
        case .MULTIPLICATIVE;
            array_unordered_remove_by_value(*attrib_comp.mul_mods[attrib], val);
    }
}


test_attributes :: () -> bool {
    test: Attribute_Component;
    test.base[Attribute.MAX_HEALTH] = 100;

    add_attribute_modifier(.MAX_HEALTH, 50, .ADDITIVE, test);
    add_attribute_modifier(.MAX_HEALTH, 2, .MULTIPLICATIVE, test);

    actual := get_current_attribute_value(.MAX_HEALTH, test);

    expected :: 300;

    return actual == expected;
} @UnitTest