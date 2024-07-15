//every tick a skill is powering-up, power from the player's stored power will be drained and sent to the skill(s)
power_skill_per_tick :: (q: Query) {
    stored_powers := query_get(q, Stored_Power);

    for 0..q.count-1 {

        iter := make_children_iter(q.world, q.entities[it], Skill);
        children: [..] Entity;
        children.allocator = temp;
        for * iter : make_children_iter(q.world, q.entities[it]) {
            for iter.entities {
                if get_component(q.world, it, Skill) {
                    array_add(*children, it);
                }  
            }
        }   

        if children.count > 0 {
            distributed_power := stored_powers[it].value/children.count;
            stored_powers[it].value = 0;

            for children {
                power_change_queue := get_component(q.world, it, Power_Change_Queue);
                power_skill(power_change_queue, distributed_power);
            }
        }
    }
} @System(OnValidate) @Write(Stored_Power) @Read()

power_skill :: (change_queue: Power_Change_Queue, power: float) {
    array_add(*change_queue.changes, power);
}