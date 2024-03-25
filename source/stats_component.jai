Stats_Component :: struct {
    is_alive: bool;

    maximum_health: float;
    current_health: float;
    maximum_energy: float;
    current_energy: float;

    movement_speed: float;
}

//sets passed player stats component to be equal to given template
init_player_stats :: (using player_stats: *Player_Stats_Component, stats_component_base: Player_Stats_Component){
    player_stats.maximum_health = stats_component_base.maximum_health;
    player_stats.current_health = player_stats.maximum_health;
    player_stats.maximum_energy = stats_component_base.maximum_energy;
    player_stats.current_energy = player_stats.maximum_energy;

    player_stats.movement_speed = stats_component_base.movement_speed;

    player_stats.armour = stats_component_base.armour;
}

init_monster_stats :: (monster_stats: *Monster_Stats_Component, stats_component_base: Monster_Stats_Component){
    monster_stats.maximum_health = stats_component_base.maximum_health;
    monster_stats.current_health = monster_stats.maximum_health;
    monster_stats.maximum_energy = stats_component_base.maximum_energy;
    monster_stats.current_energy = monster_stats.maximum_energy;

    monster_stats.movement_speed = stats_component_base.movement_speed;

    monster_stats.aggro_range = stats_component_base.aggro_range;
}

Player_Stats_Component :: struct {
    using #as stats_component : Stats_Component;
    
    armour: float;
}

Monster_Stats_Component :: struct {
    using #as stats_component : Stats_Component;
  
    aggro_range: float;
}

test_stats_component :: () -> bool {
    //test applying status component
    {
        
        player_test: Player_Stats_Component;
        goblin_test: Monster_Stats_Component;
        init_player_stats(*player_test,DEFAULT_PLAYER_STATS);
        assert(player_test.movement_speed == DEFAULT_PLAYER_STATS.movement_speed);

        init_monster_stats(*goblin_test,DEFAULT_GOBLIN_STATS);
        assert(goblin_test.aggro_range == DEFAULT_GOBLIN_STATS.aggro_range);
    }
    return true;
}@UnitTest