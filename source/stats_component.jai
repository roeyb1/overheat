Stats_Component :: struct {
    is_alive: bool;
    
    //strikes me as retarded
    StatTypeIndex :: StatType;

    stats: [StatTypeIndex.COUNT] Stat;
}

Stat :: struct {
    base: float = 0;
    flat_added: float = 0;
    increase: float = 1;
    more: float = 1;
    total: float = 0;
}

StatType :: enum u8{
    MAXIMUM_HEALTH;
    CURRENT_HEALTH;
    MAXIMUM_ENERGY;
    CURRENT_ENERGY;
    MOVEMENT_SPEED;
    ARMOUR;
    AGGRO_RANGE;
    COUNT;
}

stat_update_total :: (using stat: *Stat) -> float{
    total = (base + flat_added) * increase * more;
    return total;
}

//sets passed player stats component to be equal to given template
init_stats :: (using stats_component: *Stats_Component, stats_component_base: Stats_Component){
    for *stat,i: stats_component.stats {
        <<stat = stats_component_base.stats[i];
        stat_update_total(stat);
    }
}

test_stats_component :: () -> bool {
    //test applying status component
    {
        
        player_test: Stats_Component;
        goblin_test: Stats_Component;
        init_stats(*player_test,DEFAULT_PLAYER_STATS);
        assert(player_test.stats[StatType.MOVEMENT_SPEED].base == DEFAULT_PLAYER_STATS.stats[StatType.MOVEMENT_SPEED].base);

        init_stats(*goblin_test,DEFAULT_GOBLIN_STATS);
        assert(goblin_test.stats[StatType.AGGRO_RANGE].base == DEFAULT_GOBLIN_STATS.stats[StatType.AGGRO_RANGE].base);
    }
    return true;
}@UnitTest