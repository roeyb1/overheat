
test_timebased_state :: struct @Component {
}


test_attack :: (q: Query) {
    #if SERVER {
        player_commands := query_get(q, Player_Commands);
        positions := query_get(q, Position);

        for 0..q.count-1 {
            attacking := player_commands[it].main_attack;
            if attacking {
                //log("peepeepoopoo");
                spawn_child_entity(q.world, entities[it], )
                spawn_enemy(q.world, positions[it].value, get_unique_node_id(), .BAT);
            }
        }
    }
} @System(PreUpdate) @Write() @Read(Player_Commands,Position) 
