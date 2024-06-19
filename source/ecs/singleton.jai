#placeholder Singleton_Storage;

get_singleton :: (world: *World, $type: Type) -> *type {
    #insert -> string {
        assert(type_info(type).type == .STRUCT);
        builder: String_Builder;
        print_to_builder(*builder, "return *world.singletons._%;", type_info(type).name);
        return builder_to_string(*builder);
    }
}

generate_singletons :: () #compile_time {

    has_note :: (tis: *Type_Info_Struct, note: string) -> bool {
        for tis.notes  if it == note  return true;
        return false;
    }

    w := get_current_workspace();
    table := get_type_table(w);

    builder: String_Builder;

    print_to_builder(*builder, "Singleton_Storage :: struct {\n");
    for table {
        if it.type != .STRUCT continue;

        tis := cast(*Type_Info_Struct) it;
        if has_note(tis, "SingletonComponent") {
            print_to_builder(*builder, "\t_%1: %1;\n", tis.name);
        }
    }
    print_to_builder(*builder, "}\n");

    build_string := builder_to_string(*builder);
    add_build_string(build_string, w);
    
} @RunWhenReady

#import "Compiler";