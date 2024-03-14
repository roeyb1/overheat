#scope_export

offset_of :: ($T: Type, $member: string) -> int {
    for type_info(T).members {
        if it.name == member return it.offset_in_bytes;
    }

    assert(false, "Type '%' does not have member '%'", T, member);
    return -1;
}
