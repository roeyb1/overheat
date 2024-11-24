Fragment_Storage :: struct @Component {
    self: [..] Fragment;
    payload: [..] Fragment;
    initialised := false;
}

//TODO: auto generate this
Fragment :: enum u8 {
    Touch;
    Projectile;
}

is_component_blocking :: (frag: Fragment) -> bool {
    if frag == {
        case .Touch;        return true;
        case .Projectile;   return true;
        case;               return false;
    }
}

#if SERVER {
    //when a new spell instance is created it will take the fragments his creator was meant to pass and seperate them based on what it's using and passing itself
    make_child_fragments :: (source: [] Fragment) -> Fragment_Storage {
        result: Fragment_Storage;

        new_self_view, new_payload_view := split_fragment_list(source);
        array_copy(*result.self, new_self_view);
        array_copy(*result.payload, new_payload_view);

        return result;
    }

    //once the fragents are ready the spell isntance will apply the components from the fragments
    //TODO would need a not here
    initialize_Fragments :: (q: Query) {
        fragment_storage := query_get(q, Fragment_Storage);

        for index: 0..q.count-1 {
            //a not would allow to remove this check
            if ecs_has(q.world, q.entities[index], Spell) {
                fragment_storage[index].initialised = true;
            }

            if !fragment_storage[index].initialised {
                self := fragment_storage[index].self;
                for self {
                    if it == {
                        case .Touch;
                            add_touch_from_cast(q.world, q.entities[index]);

                        case .Projectile;
                            add_projectile_fragment(q.world, q.entities[index]);
                    }
                }
                fragment_storage[index].initialised = true;
            }
        }
    } @System(OnValidate) @Write() @Read(Fragment_Storage)
}

#scope_file

split_fragment_list :: (fragments: [] Fragment) -> (self: [] Fragment, payload: [] Fragment) {
    blocked := false;

    self_end := fragments.count - 1;

    for fragments {
        if is_component_blocking(it) {
            self_end = it_index;
            break;
        }
    }
    self := array_view(fragments, 0, self_end + 1);
    payload := array_view(fragments, self_end + 1, max(0, fragments.count - (self_end + 1)));

    return self, payload;
}

self_fragments :: (fragments: [] Fragment) -> [] Fragment {
    return split_fragment_list(fragments);
}

payload_fragments :: (fragments: [] Fragment) -> [] Fragment {
    self, payload := split_fragment_list(fragments);
    return payload;
}

#load "projectile.jai";
#load "touch.jai";