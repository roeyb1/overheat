
DEFAULT_PLAYER_STATS :: Stats_Component .{

    stats[StatTypeIndex.MAXIMUM_HEALTH].base = 100,
    stats[StatTypeIndex.CURRENT_HEALTH].base = 100,

    stats[StatTypeIndex.MAXIMUM_ENERGY].base = 100,
    stats[StatTypeIndex.CURRENT_ENERGY].base = 100,

    stats[StatTypeIndex.MOVEMENT_SPEED].base = 4,

    stats[StatTypeIndex.ARMOUR].base = 11,
    
};

DEFAULT_GOBLIN_STATS :: Stats_Component .{

    stats[StatTypeIndex.MAXIMUM_HEALTH].base = 40,
    stats[StatTypeIndex.CURRENT_HEALTH].base = 100,

    stats[StatTypeIndex.MAXIMUM_ENERGY].base = 100,
    stats[StatTypeIndex.CURRENT_ENERGY].base = 100,

    stats[StatTypeIndex.MOVEMENT_SPEED].base = 3,

    stats[StatTypeIndex.AGGRO_RANGE].base = 40,
};
