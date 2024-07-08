Node_State :: struct {
    // maps component type id to a byte buffer containing the serialized component data
    fields: Table(u64, ByteBuffer);
}

State_Snapshot :: struct {
    state: Table(Node_ID, Node_State, given_hash_function=node_id_hash, given_compare_function=compare_node_id);

    // a list of all newly created entities and their component types
    // any synchronized state for those components is included in the state table
    new_nodes: Table(Node_ID, [..] u64, given_hash_function=node_id_hash, given_compare_function=compare_node_id);

    removed_nodes: [..] Node_ID;

    time: float;
    tick: u32;
}

State_Snapshot_Packet_Data :: struct {
    // we can't serialize tables yet, so we just transfer a list of pairs when serializing the state on the network

    State_Pair :: struct {
        node_id: Node_ID;

        Node_Field :: struct {
            field_id: u64; // component_type_id.unique_id

            data: ByteBuffer;
        }

        fields: [..] Node_Field;
    }

    state_pairs: [..] State_Pair;

    New_Pair :: struct {
        node_id: Node_ID;
        component_types: [..] u64;
    }

    newly_added: [..] New_Pair;
    removed: [..] Node_ID;

    time: float;
    tick: u32;
}

State_Snapshot_Packet :: struct {
    PACKET_TYPE :: PacketType.SNAPSHOT;
    using data: State_Snapshot_Packet_Data;
}


// any nodes that were newly created in the last simulation iter
added_nodes: [..] Node_ID;
// any nodes that were destroyed in the last simulation iter
removed_nodes: [..] Node_ID;


free :: (snapshot: *State_Snapshot) {
    for snapshot.state {
        for * it.fields {
            free(it);
        }
        deinit(*it.fields);
    }
    for snapshot.new_nodes {
        array_reset(*it);
    }
    deinit(*snapshot.state);
    deinit(*snapshot.new_nodes);
    array_reset(*snapshot.removed_nodes);
}

to_packet :: (snapshot: State_Snapshot) -> State_Snapshot_Packet {
    result: State_Snapshot_Packet;
    result.newly_added.allocator = temp;
    result.removed.allocator = temp;
    result.state_pairs.allocator = temp;
    result.time = snapshot.time;
    result.tick = snapshot.tick;

    array_append(*result.removed, snapshot.removed_nodes);

    for snapshot.state {
        pair := array_add(*result.state_pairs);
        pair.node_id = it_index;

        for * it.fields {
            field := array_add(*pair.fields);
            field.field_id = it_index;
            field.data = copy(it);
        }
    }
    for snapshot.new_nodes {
        pair := array_add(*result.newly_added);
        pair.node_id = it_index;
        pair.component_types = it;
    }
    result.time = xx seconds_since_init();
    return result;
}

from_packet :: (packet: State_Snapshot_Packet) -> State_Snapshot {
    result: State_Snapshot;
    result.time = packet.time;
    result.tick = packet.tick;

    array_append(*result.removed_nodes, packet.removed);

    for packet.state_pairs {
        new_state := table_add(*result.state, it.node_id, .{});
        // deep copy the state and all the fields, they were allocated from temp buffers
        for it.fields {
            new_data := copy(*it.data);
            new_field_data := table_add(*new_state.fields, it.field_id, new_data);
        }
    }
    for packet.newly_added {
        new_entry := table_add(*result.new_nodes, it.node_id, it.component_types);
    }

    return result;
}