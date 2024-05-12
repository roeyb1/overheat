Item_Type :: enum u32 {
    DEFAULT;
    HELMET;
    NECKLACE;

    // NUM should be the last element of this enum => .count()
    NUM;
} 


Item :: struct{
    type: Item_Type;
    name: string;
}