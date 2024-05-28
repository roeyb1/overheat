Inventory :: struct {
    equipment: [Item_Type.NUM] Item;
    storage: [20] Item;
}

// Default/Starter items initialization
populate_inventory :: (inventory : *Inventory){  
    inventory.equipment[Item_Type.HELMET] = .{.HELMET, "default"};
    inventory.equipment[Item_Type.NECKLACE] = .{.NECKLACE, "default"};
}

// Checks if the storage has place to move the equiped item before replacing it
add_item_equipment :: (inventory : *Inventory, item : Item){
    if(add_item_storage(inventory, inventory.equipment[item.type])) 
        inventory.equipment[item.type] = item;
}

// Checks if for a free space in the inventory before adding the item
// TODO: Fix this method once we have inventory UI
//      - index wont be needed
add_item_storage :: (inventory : *Inventory, item : Item) -> bool{
    is_item_added : bool = false;
    index: int = -1; 

    for 0..inventory.storage.count - 1 {
        if(inventory.storage[it].type == Item_Type.INVALID){
            inventory.storage[it] = item;
            is_item_added = true;
            index = it;
            break;
        }    
    }

    if(is_item_added)
        log("ADDED: Item has been added at % of the storage", index);
    else
        log_error("ERROR: No more space in the invenotry.");
    
    return is_item_added;
}

remove_item_equipment :: (inventory : *Inventory, item_type : Item_Type){
    inventory.equipment[item_type] = .{.INVALID, ""};
}

remove_item_storage :: (inventory : *Inventory, index: int){
    inventory.storage[index] = .{.INVALID, ""};
    log("REMOVED: Item % from storage", index);
}

// Used later when we have a proper invenotry UI -> assigned "I" as open inventory 
OpenInventory :: (key_state: Key_Current_State){
    log("ATTENTION: I have opened the inventory");
}

count : int = 0;
show_inventory_system :: (world: *World) {
    if ImGui.Begin("Inventory") {
        if ImGui.Button("Add Item Equipment") {
        for Query(Local_Player, *Inventory).{world = world} { 
                add_item_equipment(it.inventory, .{.HELMET, sprint("+50 power GIGA BOSS %", count)});
                count = count + 1;
                log("ADDED: new helmet @equipemnt");
            }
        }

        ImGui.SameLine();

        if(ImGui.Button("Add Item Storage")){
            for Query(Local_Player, *Inventory).{world = world} { 
                add_item_storage(it.inventory, .{.HELMET, sprint("+50 power GIGA BOSS %", count)});
                count = count + 1;
                log("ADDED: new helmet @storage");
            }
        }

        ImGui.SameLine();

        if(ImGui.Button("Remove Helmet")){
            for Query(Local_Player, *Inventory).{world = world}
                remove_item_equipment(it.inventory, .HELMET);

            log("REMOVED: helmet @equipment");
        }

        ImGui.SameLine();   

        if(ImGui.Button("Remove Necklace")){
            for Query(Local_Player, *Inventory).{world = world}
                remove_item_equipment(it.inventory, .NECKLACE);

            log("REMOVED: necklace @equipment");
        }
        
        if ImGui.BeginTable("Inventory Table", 2) {
            ImGui.TableSetupColumn("Item Type");
            ImGui.TableSetupColumn("Item Name");
            ImGui.TableHeadersRow();

            for Query(Local_Player, *Inventory).{world = world} { 
                item_index : int = 0; 
                for *item : it.inventory.equipment {
                    ImGui.TableNextRow();

                    ImGui.TableSetColumnIndex(0);
                    ImGui.Text("%", item.type);
                    ImGui.TableSetColumnIndex(1);
                    ImGui.Text("%", item.name);

                }
            }
            ImGui.EndTable();
        }
    
        ImGui.Text("------------Storage------------");
        if ImGui.BeginTable("Storage Table", 3) {
            ImGui.TableSetupColumn("Item Type");
            ImGui.TableSetupColumn("Item Name");
            ImGui.TableSetupColumn(" ");
            ImGui.TableHeadersRow();

            for query, entity : Query(Local_Player, *Inventory).{world = world}  { 
                for 0..query.inventory.storage.count - 1 {
                    ImGui.TableNextRow();

                    ImGui.TableSetColumnIndex(0);
                    ImGui.Text("%", query.inventory.storage[it].type);
                    ImGui.TableSetColumnIndex(1);
                    ImGui.Text("%", query.inventory.storage[it].name);
                    ImGui.TableSetColumnIndex(2);
                    
                    if ImGui.Button(temp_c_string(tprint("Remove##%", it))) {
                        remove_item_storage(query.inventory, it);
                    }
                }
            }
            ImGui.EndTable();
        }

    }
    ImGui.End();

} @System