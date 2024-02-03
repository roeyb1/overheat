#scope_export

ByteBuffer :: struct {
    buff: [..] u8;
    cursor: s64;
}

byte_buffer_write :: (out_buffer: *ByteBuffer, data: *void, info: *Type_Info) {
    if info.type == {
        // handle primitive types the same way:
        case .BOOL; #through ;
        case .INTEGER; #through;
        case .FLOAT; #through;
        case .ENUM;
            write_value(out_buffer, data, info.runtime_size);
        case .STRING;
            // #todo: should be the same as arrays
        case .ARRAY;
            // #todo
        case .STRUCT;
            struct_info := cast(*Type_Info_Struct) info;
            write_struct_members(out_buffer, data, struct_info.members);
        case .POINTER;
            assert(false, "Pointer serialization is forbidden");
        case;
            assert(false, "Unsupported type");
    }
}

byte_buffer_read :: (buffer: *ByteBuffer, data_out: *void, info: *Type_Info) {
    if info.type == {
        // handle primitive types the same way:
        case .BOOL; #through ;
        case .INTEGER; #through;
        case .FLOAT; #through;
        case .ENUM;
            read_value(buffer, data_out, info.runtime_size);
        case .STRING;
            // #todo: should be the same as arrays
        case .ARRAY;
            // #todo
        case .STRUCT;
            struct_info := cast(*Type_Info_Struct) info;
            read_struct_members(buffer, data_out, struct_info.members);
        case .POINTER;
            assert(false, "Pointer serialization is forbidden");
        case;
            assert(false, "Unsupported type");
    }
}

free :: (byte_buff: *ByteBuffer) {
    free(byte_buff.buff.data);
    byte_buff.buff.data = null;
    byte_buff.buff.count = 0;
    byte_buff.cursor = 0;
}

test_binary_serialization :: () -> bool {
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
        assert(first_byte_actual == first_byte_expected);


        buffer.cursor = 0;

        read_actual: u32;
        read_value(*buffer, cast (*u8) *read_actual, size_of(u32));

        assert(read_actual == test_data);
    }

    BasicEnum :: enum u8 {
        Foo;
        Bar;
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

        assert(read_actual.x == test_data.x);
        assert(read_actual.y == test_data.y);
        assert(read_actual.z == test_data.z);
        assert(read_actual.type == test_data.type);
    }

    return true;
} @UnitTest

#scope_file

write_struct_members :: (out_buffer: *ByteBuffer, data: *void, members: [] Type_Info_Struct_Member) {
    for * member : members {
        if member.flags & .CONSTANT then continue;
        
        byte_buffer_write(out_buffer, data + member.offset_in_bytes, member.type);
    }
}

read_struct_members :: (buffer: *ByteBuffer, data_out: *void, members: [] Type_Info_Struct_Member) {
    for * member : members {
        if member.flags & .CONSTANT then continue;
        
        byte_buffer_read(buffer, data_out + member.offset_in_bytes, member.type);
    }
}

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
}
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
}

/** Quick and dirty test to see what byte order this machine is on.
    This is really stupid.. surely the language can tell me..
 */
big_endian :: () -> bool {
    x : s16 = 1;

    b : *u8 = cast(*u8) *x;

    if b[0] return false;
    return true;
}

#import "Basic";
#import "String";