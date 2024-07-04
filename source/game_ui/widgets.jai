ValueBarFlags :: enum_flags {
    None     :: 0;
    DisplayValue :: 1 << 0;
}

ProgressBarV :: (label: string, value: float, size: ImGui.ImVec2, min_v: float = 0., max_v: float = 1., flags: ValueBarFlags = .None) {
    style := ImGui.GetStyle();
    draw_list := ImGui.GetWindowDrawList();
    cursor_pos := ImGui.GetCursorScreenPos();
    fraction := (value - min_v) / max_v;
    frame_height := ImGui.GetFrameHeight();
    label_size : ImGui.ImVec2 = ifx label.count > 0 then ImGui.ImVec2.{ImGui.CalcTextSize(label).x, frame_height} else ImGui.ImVec2.{0, 0};
    rect_size := size;

    rect_start := cursor_pos + ImGui.ImVec2.{max(0., (label_size.x - rect_size.x) / 2.), 0.};

    draw_list.AddRectFilled(draw_list, rect_start, rect_start + rect_size, ImGui.GetColorU32(.FrameBg), style.FrameRounding);
    draw_list.AddRectFilled(draw_list,
        rect_start + .{0, (1 - fraction) * rect_size.y },
        rect_start + rect_size * .{ 1, 1},
        ImGui.GetColorU32(.PlotHistogram),
        style.FrameRounding, 
        ifx fraction > 0.95 then .RoundCornersTop | .RoundCornersBottom else .RoundCornersBottom
    );

    display_v := test_flag_bit(flags, .DisplayValue);

    if label.count > 0 {
        draw_list.AddText(draw_list,
            rect_start + .{(rect_size.x - label_size.x) / 2., style.FramePadding.y + (rect_size.y)  / 2. - label_size.y / 1.25},
            ImGui.GetColorU32(.Text),
            label
        );
    }
    if test_flag_bit(flags, .DisplayValue) {
        value_label := tprint("%/%", cast(u32)value, cast(u32)max_v);
        value_label_size := ImGui.CalcTextSize(value_label);

        draw_list.AddText(draw_list,
            rect_start + .{(rect_size.x - value_label_size.x) / 2., style.FramePadding.y + (rect_size.y)  / 2. - value_label_size.y * 0.25 },
            ImGui.GetColorU32(.Text),
            value_label
        );

    }

    ImGui.SetCursorScreenPos(cursor_pos + rect_size);
}