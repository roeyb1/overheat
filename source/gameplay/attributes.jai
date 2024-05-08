
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
    add_mods: [Attribute.NUM] Bucket_Array(float, 32);
    mul_mods: [Attribute.NUM] Bucket_Array(float, 32);

    is_cached: [Attribute.NUM] bool; // #todo change to bit array to save memory
    cached: [Attribute.NUM] float;
}

Attribute_Modifier :: struct {
    type: AttributeType;
    attrib: Attribute;
    locator: Bucket_Locator;
}

/** Computes the current value of an attribute after all modifiers are applied. */
get_current_attribute_value :: (attrib: Attribute, attrib_comp: *Attribute_Component) -> float {
    if !attrib_comp.is_cached[attrib] {
        base: float = attrib_comp.base[attrib];

        for attrib_comp.add_mods[attrib] {
            base += it;
        }

        multiplier := 1.;
        for attrib_comp.mul_mods[attrib] {
            multiplier *= it;
        }

        attrib_comp.cached[attrib] = base * multiplier;
        attrib_comp.is_cached[attrib] = false;
    }

    return attrib_comp.cached[attrib];
}

/** Adds a new attribute modifier for a specified attribute to an attribute component. */
add_attribute_modifier :: (attrib: Attribute, val: float, type: AttributeType, attrib_comp: *Attribute_Component) -> Attribute_Modifier {
    locator: Bucket_Locator;
    if type == {
        case .ADDITIVE;
            locator = bucket_array_add(*attrib_comp.add_mods[attrib], val);
        case .MULTIPLICATIVE;
            locator = bucket_array_add(*attrib_comp.mul_mods[attrib], val);
        case;
            assert(false);
    };
    attrib_comp.is_cached[attrib] = false;

    return .{ type, attrib, locator };
}


/** Removes an attribute modifier for a from an attribute component that matches the exact passed values. */
remove_attribute_modifier :: (attrib_comp: *Attribute_Component, modifier: Attribute_Modifier) {
    if modifier.type == {
        case .ADDITIVE;
            bucket_array_remove(*attrib_comp.add_mods[modifier.attrib], modifier.locator);
        case .MULTIPLICATIVE;
            bucket_array_remove(*attrib_comp.mul_mods[modifier.attrib], modifier.locator);
    }
}


test_attributes :: () -> bool {
    test: Attribute_Component;
    test.base[Attribute.MAX_HEALTH] = 100;

    add_attribute_modifier(.MAX_HEALTH, 50, .ADDITIVE, *test);
    add_attribute_modifier(.MAX_HEALTH, 2, .MULTIPLICATIVE, *test);

    actual := get_current_attribute_value(.MAX_HEALTH, *test);

    expected :: 300;

    return actual == expected;
} @UnitTest