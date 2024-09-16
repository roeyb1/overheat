Charging :: struct @Tag {
}

Gathered_Energy :: struct @Component {
    value: float;
}

Charging_Bundle :: struct @Bundle {
    anim_list_index: Anim_List_Index; //animation that will run during the charge 
    duration: Duration; //duration component, will make the charge kill itself after a duration
    energy_cost: Energy_Cost; // needs to be put after the duration componenent @TODO we need a way of executing events in a specific order other then in the bundle this is error prone and cringe to debug
    gathered_energy: Gathered_Energy; //this is simply a tracker of how much ABSOLUTE energy was drained, it does not run any math on buffs or whatnot
    charging: Charging; //tag must be put at end so the event fires when there is data
    target: Target;
}

#load "charges.jai";
#load "energy_cost.jai";








