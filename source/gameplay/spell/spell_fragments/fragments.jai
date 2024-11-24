Fragment_Storage :: struct @Component {
    self: [..] Fragment;
    payload: [..] Fragment;
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
    initialize_fragments :: (world: *World, entity: Entity) {
        fragment_storage := ecs_get(world, entity, Fragment_Storage);

        for fragment_storage.self {
            if it == {
                case .Touch;
                    add_touch_from_cast(world, entity);

                case .Projectile;
                    add_projectile_fragment(world, entity);
            }
        }
    } @Event(EcsOnAdd,Fragment_Storage)
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