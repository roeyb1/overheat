Item_Type :: enum u32 {
    HELMET;
    NECKLACE;

    // NUM should be the last element of this enum => .count()
    NUM;
    INVALID;
} 


Item :: struct{
    type: Item_Type = .INVALID;
    name: string;
}