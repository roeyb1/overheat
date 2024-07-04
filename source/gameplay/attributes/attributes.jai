Attribute :: struct {
    multipliers: [..] float;
    adders: [..] float;

    base_value: float; 
    value: float;
}

Dynamic_Attribute :: struct {
    maximum_value: float;
    current_value: float;
    change_queue: [..] float;
}

//attributes dont work untill this is called, should be fixed or have a function that does it for an attribute automaticly once its added
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

#load "attribute_modifier.jai";
#load "move_speed.jai";
#load "maximum_health.jai";
