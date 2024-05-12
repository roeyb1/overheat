Inventory :: struct {
    equipment: [Item_Type.NUM] Item;
    storage: [20] Item;
}

//TODO: everything else. Think about the populate inventory
populate_inventory :: (inventory : *Inventory){  
    inventory.equipment[Item_Type.HELMET] = .{.HELMET, "default"};
    inventory.equipment[Item_Type.NECKLACE] = .{.NECKLACE, "default"};
}

//TODO: think aboout the case:
//           ->user replaces an item
//           ->Where does replaced item go ?
add_item :: (inventory : *Inventory, item : Item){
    inventory.equipment[item.type] = item;
}

remove_item :: (inventory : *Inventory, item : Item){
    inventory.equipment[item.type] = .{.INVALID, ""};
}

OpenInventory :: (key_state: Key_Current_State){
    log("ATTENTION: I have opened the inventory");
}
