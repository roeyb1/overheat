
AABB_Tree :: struct {
    nodes: [..] Tree_Node;
    root_index: s64 = -1;
}

Tree_Node :: struct {
    bounds: AABB;

    left: s64 = -1;
    right: s64 = -1;
    parent: s64 = -1;

    is_leaf: bool = false;
    
    // payload if this is a leaf node
    entity: Entity = INVALID_ENTITY;
}

insert :: (tree: *AABB_Tree, bounds: AABB, entity: Entity) {
    node_index := make_leaf(tree, bounds, entity);

    insert_leaf(tree, node_index);
}

tree_reset :: (tree: *AABB_Tree) {
    tree.nodes.count = 0;
    tree.root_index = -1;
}

find_overlaps :: (tree: *AABB_Tree, bounds: AABB, self: Entity = INVALID_ENTITY) -> [] Entity {
    result: [..] Entity;
    result.allocator = temp;

    stack: [..] s64;
    stack.allocator = temp;

    array_add(*stack, tree.root_index);

    while stack.count != 0 {
        node := pop(*stack);

        if node == -1 then continue;

        if intersects(tree.nodes[node].bounds, bounds) {
            if tree.nodes[node].is_leaf && tree.nodes[node].entity != self {
                array_add(*result, tree.nodes[node].entity);
            } else {
                array_add(*stack, tree.nodes[node].left);
                array_add(*stack, tree.nodes[node].right);
            }
        }
    }
    return result;
}

#scope_file

make_leaf :: (tree: *AABB_Tree, bounds: AABB, entity: Entity) -> s64 {
    root: *Tree_Node = array_add(*tree.nodes);
    root.bounds = bounds;
    root.entity = entity;
    root.is_leaf = true;
    return tree.nodes.count-1;
}

insert_leaf :: (tree: *AABB_Tree, new_node_index: s64) {
    if tree.root_index == -1 {
        tree.root_index = new_node_index;
        return;
    }

    node_index := tree.root_index;
    // descend the tree until we find a non-leaf node to add the new node onto
    while (!tree.nodes[node_index].is_leaf) {
        left := tree.nodes[node_index].left;
        right := tree.nodes[node_index].right;
        assert(left != -1 && right != -1);

        combined_aabb := tree.nodes[node_index].bounds + tree.nodes[new_node_index].bounds;
        combined_area := area(combined_aabb);

        // estimated cost of reparenting the current node:
        new_parent_cost := combined_area;
        // estimated cost of pushing the node down the tree:
        min_push_down_cost := combined_area - area(tree.nodes[node_index].bounds);

        cost_left := 0.;
        cost_right := 0.;
        if tree.nodes[left].is_leaf {
            cost_left := area(tree.nodes[new_node_index].bounds + tree.nodes[left].bounds) + min_push_down_cost;
        } else {
            // left is not a leaf
            new_left_aabb := tree.nodes[new_node_index].bounds + tree.nodes[left].bounds;
            cost_left := area(new_left_aabb) - area(tree.nodes[left].bounds) + min_push_down_cost;
        }

        if tree.nodes[right].is_leaf {
            cost_right := area(tree.nodes[new_node_index].bounds + tree.nodes[right].bounds) + min_push_down_cost;
        } else {
            // right is not a leaf
            new_right_aabb := tree.nodes[new_node_index].bounds + tree.nodes[right].bounds;
            cost_right := area(new_right_aabb) - area(tree.nodes[right].bounds) + min_push_down_cost;
        }

        // the cost of reparenting this node is less than the cost of reparenting either children, place the node here
        if new_parent_cost < min(cost_left, cost_right) {
            break;
        }

        if cost_left < cost_right {
            node_index = left;
        } else {
            node_index = right;
        }
    }

    sibling_index := node_index;
    old_parent_index := tree.nodes[sibling_index].parent;

    new_parent_index := make_node(tree);
    tree.nodes[new_parent_index].bounds = tree.nodes[new_node_index].bounds + tree.nodes[sibling_index].bounds;
    tree.nodes[new_parent_index].left = sibling_index;
    tree.nodes[new_parent_index].right = new_node_index;
    tree.nodes[new_parent_index].parent = old_parent_index;
    tree.nodes[new_parent_index].is_leaf = false;

    tree.nodes[sibling_index].parent = new_parent_index;
    tree.nodes[new_node_index].parent = new_parent_index;

    if old_parent_index == -1 {
        // the sibling was the root, so update the root to point to the new parent
        tree.root_index = new_parent_index;
    } else {
        if tree.nodes[old_parent_index].left == sibling_index {
            tree.nodes[old_parent_index].left = new_parent_index;
            tree.nodes[old_parent_index].is_leaf = false;
        } else {
            tree.nodes[old_parent_index].right = new_parent_index;
        }
    }

    fixup_upwards(tree, tree.nodes[new_node_index].parent);
}

fixup_upwards :: (tree: *AABB_Tree, node: s64) {
    node_index := node;
    while node_index != -1 {
        assert(tree.nodes[node_index].left != -1 && tree.nodes[node_index].right != -1);

        left := tree.nodes[node_index].left;
        right := tree.nodes[node_index].right;
        tree.nodes[node_index].bounds = tree.nodes[left].bounds + tree.nodes[right].bounds;
        
        node_index = tree.nodes[node_index].parent;
    }
}

make_node :: (tree: *AABB_Tree) -> s64 {
    root: *Tree_Node = array_add(*tree.nodes);
    return tree.nodes.count-1;
} @NoProfile