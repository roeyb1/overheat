Item_Slot :: struct{
    expected_item: Item_Type;
    equiped_item: Item;
}


Inventory :: struct {
    equipment: [Item_Type.NUM] Item_Slot;
    storage: [20] Item;
}

//TODO: everything else. Think about the populate inventory
populate_inventory :: (inventory : *Inventory){  
    inventory.equipment[Item_Type.HELMET] = .{.HELMET, .{.DEFAULT, "default"}};;
    inventory.equipment[Item_Type.NECKLACE] = .{.NECKLACE, .{.DEFAULT, "default"}};
}

//TODO: think aboout the case:
//           ->user replaces an item
//           ->Where does replaced item go ?
add_item :: (inventory : *Inventory, item : Item){
    inventory.equipment[item.type] = .{item.type, item};
}

remove_item :: (inventory : *Inventory, item : Item){
    inventory.equipment[item.type] = .{item.type, .{.DEFAULT, "default"}};
}

