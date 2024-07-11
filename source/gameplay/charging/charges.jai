Charge :: struct {
    energy_cost: float;
    duration: float;
    anim_list_index: Anim_List_Indecies;
} 

sword :: Charge .{
    energy_cost = 30,
    duration = 0.5,
    anim_list_index = .BOW_WIND_UP
};

bow :: Charge .{
    energy_cost = 30,
    duration = 0.5,
    anim_list_index = .BOW_ATTACK
};