Stats :: enum u32 {
    HEALTH;
    MAX_HEALTH;
    SPEED;
    NUM;
}


Stats_Component :: struct {
    data: [Stats.NUM] float;
}