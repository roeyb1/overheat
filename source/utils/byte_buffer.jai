#scope_export

// #todo: ByteBufferView struct would be very useful
ByteBuffer :: struct {
    buff: [..] u8;
    cursor: s64;
    allocator: Allocator; @NoSerialize;

    // if only-note is set, it will only serialize members with the note
    only_note: string;
    // if skip note is set, it will skip serializing members that have that note (besides @NoSerialize which will always be skipped)
    skip_note: string;
}

copy :: (buffer: *ByteBuffer) -> ByteBuffer {
    result: ByteBuffer;

    array_copy(*result.buff, buffer.buff);
    result.only_note = buffer.only_note;
    result.skip_note = buffer.skip_note;

    return result;
}

byte_buffer_write :: (out_buffer: *ByteBuffer, data: *$Type, ignore_notes := false) {
    byte_buffer_write(out_buffer, data, type_info(Type), ignore_notes);
}

byte_buffer_write :: (out_buffer: *ByteBuffer, data: *void, info: *Type_Info, ignore_notes := false) {
    if info.type == {
        // handle primitive types the same way:
        case .BOOL; #through ;
        case .INTEGER; #through;
        case .FLOAT; #through;
        case .ENUM;
            write_value(out_buffer, data, info.runtime_size);
        case .STRING;
            str := cast(*string) data;
            byte_buffer_write(out_buffer, *str.count, ignore_notes);
            for 0..str.count-1 {
                byte_buffer_write(out_buffer, *str.data[it], ignore_notes);
            }
        case .ARRAY;
            array_info := cast(*Type_Info_Array) info;

            // resizable arrays/arrays views have the same layout in memory so we can cast the data pointer to an array to grab the count member:
            array_count: s64 = array_info.array_count;
            if array_count == -1 {
                array_count = (cast(*[] int) data).count;
            }
            assert(array_count != -1);

            byte_buffer_write(out_buffer, *array_count, type_info(s64), ignore_notes);

            array_data: *void = ifx array_info.array_type == .RESIZABLE {
                (cast(*[] int) data).data;
            } else {
                (cast(*[1] int) data).data;
            };

            for 0..array_count-1 {
                byte_buffer_write(out_buffer, array_data, array_info.element_type, ignore_notes);
                array_data += array_info.element_type.runtime_size;
            }
        case .STRUCT;
            struct_info := cast(*Type_Info_Struct) info;
            write_struct_members(out_buffer, data, struct_info.members, ignore_notes);
        case .POINTER;
            assert(false, "Pointer serialization is forbidden");
        case;
            assert(false, "Unsupported type");
    }
} @NoProfile

byte_buffer_read :: (buffer: *ByteBuffer, data: *$Type, ignore_notes := false) {
    byte_buffer_read(buffer, data, type_info(Type), ignore_notes);
}

byte_buffer_read :: (buffer: *ByteBuffer, data_out: *void, info: *Type_Info, ignore_notes := false) {
    if info.type == {
        // handle primitive types the same way:
        case .BOOL; #through ;
        case .INTEGER; #through;
        case .FLOAT; #through;
        case .ENUM;
            read_value(buffer, data_out, info.runtime_size);
        case .STRING;
            // #todo: should be the same as arrays
            str := cast(*string) data_out;
            sb: String_Builder;
            str_count: s64;
            byte_buffer_read(buffer, *str_count, ignore_notes);
            for 0..str_count-1 {
                byte: u8;
                byte_buffer_read(buffer, *byte, ignore_notes);
                append(*sb, byte);
            }
            << str = builder_to_string(*sb);
        case .ARRAY;
            array_info := cast(*Type_Info_Array) info;

            array_count: s64;
            byte_buffer_read(buffer, *array_count, type_info(s64), ignore_notes);
            
            // otherwise, use the data pointer already stored there
			array_data := data_out;

            // if the typeinfo count is -1, this is a fixed sized array and should already have memory allocated for it
			if array_info.array_count == -1 {
                // if the array is a dynamic array, we need to realloc a memory block for it:
                result := cast(*[..] u8) data_out;
                // Reallocing here could lead to a memory leak if we try to read into an array that already has some data allocated.
                assert(result.allocated == 0);
                {
                    if buffer.allocator.proc == null    buffer.allocator = context.allocator;
                    push_allocator(buffer.allocator);
                    result.data = realloc(null, array_count * array_info.element_type.runtime_size, 0);
                    memset(result.data, 0, array_count * array_info.element_type.runtime_size);
                }
                result.count = array_count;
                result.allocated = array_count;
				
                array_data = result.data;
            } else {
                // if the type is non-resizable, we can add validation to ensure the serialized count matches
                assert(array_info.array_count == array_count);
            }

            for 0..array_count-1 {
                byte_buffer_read(buffer, array_data, array_info.element_type, ignore_notes);
                array_data += array_info.element_type.runtime_size;
            }
        case .STRUCT;
            struct_info := cast(*Type_Info_Struct) info;
            read_struct_members(buffer, data_out, struct_info.members, ignore_notes);
        case .POINTER;
            assert(false, "Pointer serialization is forbidden");
        case;
            assert(false, "Unsupported type");
    }
} @NoProfile

free :: (byte_buff: *ByteBuffer) {
    array_reset(*byte_buff.buff);
    byte_buff.cursor = 0;
}

copy_to_buffer :: (buffer: *ByteBuffer, data: [] u8) {
    buffer.buff.allocator = buffer.allocator;
    array_copy(*buffer.buff, data);
    buffer.cursor = data.count;
}

test_binary_serialization :: (ctx: *TestContext) {
    // Test big-endianness of the append/read-value functions
    {
        buffer: ByteBuffer;
        defer free(*buffer);

        test_data: u32 = 0xAA_BB_CC_DD;
        write_value(*buffer, cast(*u8) *test_data, size_of(u32));

        first_byte_actual := buffer.buff[0];
        first_byte_expected := 0;

        if big_endian() {
            first_byte_expected = (cast(*u8)*test_data)[0];
            assert(first_byte_expected == 0xAA);
        }
        else {
            first_byte_expected = (cast(*u8)*test_data)[3];
            assert(first_byte_expected == 0xAA);
        }
        test_expect_equals(first_byte_expected, first_byte_actual);


        buffer.cursor = 0;

        read_actual: u32;
        read_value(*buffer, cast (*u8) *read_actual, size_of(u32));

        test_expect_equals(test_data, read_actual);
    }

    BasicStruct :: struct {
        type: BasicEnum;
        x: u32;
        y: u16;
        z: u64;
    }

    // Test simple struct serialization
    {
        test_data := BasicStruct.{.Bar, 10, 20, 30};
        assert(size_of(BasicStruct) == 24);
        assert(size_of(BasicEnum) == size_of(u8));

        buffer: ByteBuffer;
        defer free(*buffer);

        byte_buffer_write(*buffer, *test_data, type_info(BasicStruct));

        expected_data :[15] u8 = .[1, 0, 0, 0, 10, 0, 20, 0, 0, 0, 0, 0, 0, 0, 30];

        for 0..buffer.buff.count-1 {
            assert(buffer.buff[it] == expected_data[it]);
        }

        buffer.cursor = 0;
        read_actual: BasicStruct;
        byte_buffer_read(*buffer, *read_actual, type_info(BasicStruct));

        test_expect_equals(test_data.x, read_actual.x);
        test_expect_equals(test_data.y, read_actual.y);
        test_expect_equals(test_data.z, read_actual.z);
        test_expect_equals(test_data.type, read_actual.type);
    }

    // Test array serialization 
    {
        test_data: [..] u32;

        array_add(*test_data, 2);
        array_add(*test_data, 3);
        array_add(*test_data, 4);
        array_add(*test_data, 5);

        buffer: ByteBuffer;
        defer free(*buffer);

        byte_buffer_write(*buffer, *test_data, type_info(type_of(test_data)));

        buffer.cursor = 0;

        actual_data: [..] u32;
        byte_buffer_read(*buffer, *actual_data, type_info(type_of(actual_data)));

        test_expect_equals(test_data.count, actual_data.count);
        test_expect_equals(actual_data.count, actual_data.allocated);
        for 0..test_data.count-1 {
            test_expect_equals(test_data[it], actual_data[it]);
        }
    }

    ComplexStruct :: struct {
        x: u32;
        arr: [4] float32;
        data: BasicStruct;
    }
    // Test complex nested types
    {
        test_data: ComplexStruct;
        test_data.x = 24;
        test_data.arr = .[2, 4, 6, 8];
        test_data.data = .{.Foo, 9 ,8 ,7};

        buffer: ByteBuffer;
        defer free(*buffer);

        byte_buffer_write(*buffer, *test_data, type_info(type_of(test_data)));

        buffer.cursor = 0;

        actual_data: ComplexStruct;
        byte_buffer_read(*buffer, *actual_data, type_info(type_of(actual_data)));

        test_expect_equals(test_data.arr.count, actual_data.arr.count);
        for 0..test_data.arr.count-1 {
            test_expect_equals(test_data.arr[it], actual_data.arr[it]);
        }
    }

    NestedByteBuffer :: struct {
        a: u8;
        buff: ByteBuffer;
    }
    // byte buffer inside struct:
    {
        test_nested_data: ComplexStruct;
        test_nested_data.x = 24;
        test_nested_data.arr = .[2, 4, 6, 8];
        test_nested_data.data = .{.Foo, 9 ,8 ,7};
        
        test_data: NestedByteBuffer;
        test_data.a = 101;

        byte_buffer_write(*test_data.buff, *test_nested_data, type_info(type_of(test_nested_data)));


        buffer: ByteBuffer;
        defer free(*buffer);

        byte_buffer_write(*buffer, *test_data, type_info(type_of(test_data)));

        actual_data: NestedByteBuffer;

        buffer.cursor = 0;
        byte_buffer_read(*buffer, *actual_data, type_info(type_of(actual_data)));

        actual_nested_data: ComplexStruct;

        actual_data.buff.cursor = 0;
        byte_buffer_read(*actual_data.buff, *actual_nested_data, type_info(type_of(actual_nested_data)));

        test_expect_equals(test_data.a, actual_data.a);
        
        assert(actual_nested_data.arr.count == test_nested_data.arr.count);
        for 0..test_nested_data.arr.count-1 {
            test_expect_equals(test_nested_data.arr[it], actual_nested_data.arr[it]);
        }

        test_expect_equals(test_nested_data.data.x, actual_nested_data.data.x);
    }

    SkipStruct :: struct {
        type: BasicEnum;
        x: u32; @Skip
        y: u16;
        z: u64;
    }

    // Test simple struct serialization with skippped member
    {
        test_data := SkipStruct.{.Bar, 10, 20, 30};
        assert(size_of(SkipStruct) == 24);
        assert(size_of(BasicEnum) == size_of(u8));

        buffer: ByteBuffer;
        buffer.skip_note = "Skip";
        defer free(*buffer);

        byte_buffer_write(*buffer, *test_data, type_info(SkipStruct));

        expected_data := u8.[1, 0, 20, 0, 0, 0, 0, 0, 0, 0, 30];

        for 0..buffer.buff.count-1 {
            test_expect_equals(expected_data[it], buffer.buff[it]);
        }

        buffer.cursor = 0;
        read_actual: SkipStruct;
        byte_buffer_read(*buffer, *read_actual, type_info(SkipStruct));

        test_expect_equals(0, read_actual.x);
        test_expect_equals(test_data.y, read_actual.y);
        test_expect_equals(test_data.z, read_actual.z);
        test_expect_equals(test_data.type, read_actual.type);
    }


    OnlyStruct :: struct {
        type: BasicEnum; @Only
        x: u32;
        y: u16; @Only
        z: u64;
    }
    // Test simple struct serialization with only members
    {
        test_data := OnlyStruct.{.Bar, 10, 20, 30};
        assert(size_of(OnlyStruct) == 24);
        assert(size_of(BasicEnum) == size_of(u8));

        buffer: ByteBuffer;
        buffer.only_note = "Only";
        defer free(*buffer);

        byte_buffer_write(*buffer, *test_data, type_info(OnlyStruct));

        expected_data := u8.[1, 0, 20];

        for 0..buffer.buff.count-1 {
            assert(buffer.buff[it] == expected_data[it]);
        }

        buffer.cursor = 0;
        read_actual: OnlyStruct;
        byte_buffer_read(*buffer, *read_actual, type_info(OnlyStruct));

        test_expect_equals(0, read_actual.x);
        test_expect_equals(test_data.y, read_actual.y);
        test_expect_equals(0, read_actual.z);
        test_expect_equals(test_data.type, read_actual.type);
    }

    StructWithBool :: struct {
        vec: Vector2;
        val: bool;
    }

    {
        test_data := StructWithBool.{.{1, 2}, true};

        buffer: ByteBuffer;
        defer free(*buffer);

        byte_buffer_write(*buffer, *test_data, type_info(StructWithBool));

        test_expect_equals(9, buffer.buff.count);

        buffer.cursor = 0;
        read_actual: StructWithBool;
        byte_buffer_read(*buffer, *read_actual, type_info(StructWithBool));

        test_expect_equals(test_data.vec, read_actual.vec);
        test_expect_equals(test_data.val, read_actual.val);
    }
} @UnitTest

#scope_file

BasicEnum :: enum u8 {
    Foo;
    Bar;
}

write_struct_members :: (out_buffer: *ByteBuffer, data: *void, members: [] Type_Info_Struct_Member, ignore_notes := false) {
    // we need to store the last offset because #place will place members at weird locations and we want to ignore members
    last_offset := 0;
    for * member : members {
        if member.offset_in_bytes < last_offset then continue;
        last_offset = member.offset_in_bytes;

        if member.flags & .CONSTANT then continue;
        if !ignore_notes {
            if out_buffer.only_note.count > 0 && !has_note(member, out_buffer.only_note) then continue;
            if out_buffer.skip_note.count > 0 && has_note(member, out_buffer.skip_note) then continue;
        }

        for note : member.notes {
            if note == "NoSerialize" then continue member;
        }
        
        byte_buffer_write(out_buffer, data + member.offset_in_bytes, member.type, ignore_notes = true);
    }
} @NoProfile

read_struct_members :: (buffer: *ByteBuffer, data_out: *void, members: [] Type_Info_Struct_Member, ignore_notes := false) {
    last_offset := 0;
    for * member : members {
        if member.offset_in_bytes < last_offset then continue;
        last_offset = member.offset_in_bytes;

        if member.flags & .CONSTANT then continue;
        if !ignore_notes {
            if buffer.only_note.count > 0 && !has_note(member, buffer.only_note) then continue;
            if buffer.skip_note.count > 0 && has_note(member, buffer.skip_note) then continue;
        }

        for note : member.notes {
            if note == "NoSerialize" then continue member;
        }
        
        byte_buffer_read(buffer, data_out + member.offset_in_bytes, member.type, ignore_notes = true);
    }
} @NoProfile

/** Appends data with a big endian byte ordering */
write_value :: (using out_buffer: *ByteBuffer, data: *u8, size: s64) {
    if big_endian() {
        for 0..size-1 {
            array_add(*buff, data[it]);
        }
    }
    else {
        for < size-1..0 {
            array_add(*buff, data[it]);
        }
    }

    out_buffer.cursor += size;
} @NoProfile
read_value :: (using buffer: *ByteBuffer, out_data: *u8, size: s64) {
    if big_endian() {
        for 0..size-1 {
            out_data[it] = buff[buffer.cursor + it];
        }
    }
    else {
        for 0..size-1 {
            out_data[(size - 1) - it] = buff[buffer.cursor + it];
        }
    }
    cursor += size;
} @NoProfile

/** Quick and dirty test to see what byte order this machine is on.
    This is really stupid.. surely the language can tell me..
 */
big_endian :: () -> bool {
    x : s16 = 1;

    b : *u8 = cast(*u8) *x;

    if b[0] return false;
    return true;
}

#import "String";