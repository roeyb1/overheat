// @note: node ids are not per-world, therefore we don't need to keep a table per-world.
// two different node ids may point to the same entity id from different worlds
entity_node_id_table: Table(Node_ID, Entity, given_hash_function=node_id_hash, given_compare_function=compare_node_id);

Node_ID :: struct {
    id: u64;
}

Node_State :: struct {
    
}

Network_State :: struct {
    state: Table(Node_ID, Node_State, given_hash_function=node_id_hash, given_compare_function=compare_node_id);
}

node_id_hash :: inline (id: Node_ID) -> u32 {
    return get_hash(id.id);
}

compare_node_id :: inline (a: Node_ID, b: Node_ID) -> bool {
    return a == b;
}

operator== :: inline (a: Node_ID, b: Node_ID) -> bool {
    return a.id == b.id;
}

on_entity_begin_networking :: (world: *World, entity: Entity) {
    networking_id := get_component(world, entity, Networking_ID);
    table_add(*entity_node_id_table, networking_id.id, entity);

    if is_server() {
        // @todo: emit a full sync for this node
    }
} @Event(EcsOnAdd,Networking_ID)