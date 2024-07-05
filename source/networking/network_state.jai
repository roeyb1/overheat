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
