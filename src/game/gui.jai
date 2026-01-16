// TODO(jt): @Cleanup Throughout the codebase, we have checks for whether a button is hovered, so
// that we can play a sound... For the love of me, why doesn't the GUI accumulate these events, so
// that we can let the audio system know in a centralized manner at the end of the update function?

Gui :: struct {
    frame: u64;
    render_lists: Render_Lists;

    button_states: [..] Button_State;
    slider_states: [..] Slider_State;
}

gui_init :: (gui: *Gui, render_lists_capacity := 64, buttons_capacity := 64, sliders_capacity := 64) {
    // TODO(jt): #malloc @Memory Decide what arena these goes in. Currently that is context allocator, which is malloc.
    array_reserve(*gui.render_lists.rects, render_lists_capacity);
    array_reserve(*gui.button_states, buttons_capacity);
    array_reserve(*gui.slider_states, sliders_capacity);
}

gui_start_frame :: (gui: *Gui) {
    array_reset_keeping_memory(*gui.render_lists.rects);

    for gui.button_states {
        // This subtraction can wrap, but the eviction of old controls will still work.
        if gui.frame - it.frame > 1 {
            remove;
            continue;
        }
    }

    gui.frame += 1;
}


Button_Events :: enum_flags u32 {
    NONE :: 0;

    HOVERED :: 0x01;
    PRESSED :: 0x02;
}

Button_State :: struct {
    // TODO(jt): @Memory Can we have a more compact representation of the ID? Maybe some bitpacking,
    // maybe a 128bit or 64bit hash (with compile time collision checking)?
    id:    Id;
    frame: u64;
    flags: Flags;

    Flags :: enum_flags u32 {
        NONE    :: 0;

        HOVERED :: 0x01;
        DOWN    :: 0x02;
    }
}

button :: (gui: *Gui, input_state: Input_State, position: Vector2, label: string, scale := 1.0, color := Vector3.{ 1, 1, 1 }, font_kind := Font_Kind.LIGHT, font_kind_hovered := Font_Kind.SHADOW, id_location := #caller_location, id_index := 0) -> bool, Button_Events {
    events: Button_Events;

    font_size := scale * ivector_to_vector(TINY_DUNGEON_FONT_TILE_SIZE);
    luma      := 0.75;

    rect: Rect;
    rect.x = position.x;
    rect.y = position.y;
    rect.w = font_size.x * label.count;
    rect.h = font_size.y;

    triggered := false;

    // TODO(jt): @Speed Have a faster way of finding state for the control. We could do a hash table
    // maybe. It would work, but it sounds like we are giving up? In wfgui, the IDs only had to be
    // unique across siblings, which limited this speed problem. Hmmm.
    found := false;
    index := -1;
    {
        id := Id.{ id_location, id_index };
        for gui.button_states {
            if it.id == id {
                found = true;
                index = it_index;
                break;
            }
        }
    }

    if !found {
        index = gui.button_states.count;

        s: Button_State;
        s.id.location = id_location;
        s.id.index    = id_index;
        array_add(*gui.button_states, s);
    }

    state := *gui.button_states[index];
    state.frame = gui.frame;

    if rect_contains(rect, input_state.mouse_position) {
        luma = 0.9;
        font_kind = font_kind_hovered;

        was_hovered := state.flags & .HOVERED;
        was_down    := state.flags & .DOWN;

        if !was_hovered {
            state.flags |= .HOVERED;
            events      |= .HOVERED;
        }

        if input_state.keys[Key_Code.MOUSE_BUTTON_LEFT] & .PRESSED {
            if !was_down {
                state.flags |= .DOWN;
                events      |= .PRESSED;
            }
        }

        if state.flags & .DOWN {
            luma = 1.0;
        }

        triggered = state.flags & .DOWN && input_state.keys[Key_Code.MOUSE_BUTTON_LEFT] & .RELEASED;
    } else {
        state.flags &= ~.HOVERED;
    }

    if input_state.keys[Key_Code.MOUSE_BUTTON_LEFT] & .RELEASED {
        state.flags &= ~.DOWN;
    }

    draw_text(*gui.render_lists, position, label, scale, font_kind, .{ luma * color.x, luma * color.y, luma * color.z, 1.0 });

    return triggered, events;
}

image_button :: (gui: *Gui, input_state: Input_State, position: Vector2, texture_name: string, texture_rect: Rect, scale := 1.0, id_location := #caller_location, id_index := 0) -> bool, Button_Events {
    events: Button_Events;

    texture_rect_size := rect_size(texture_rect);

    luma := 1.0;

    rect: Rect;
    rect.x = position.x;
    rect.y = position.y;
    rect.w = scale * texture_rect_size.x;
    rect.h = scale * texture_rect_size.y;

    triggered := false;

    // Image button reuses the button states array.
    //
    // TODO(jt): @Speed Have a faster way of finding state for the control. We could do a hash table
    // maybe. It would work, but it sounds like we are giving up? In wfgui, the IDs only had to be
    // unique across siblings, which limited this speed problem. Hmmm.
    found := false;
    index := -1;
    {
        id := Id.{ id_location, id_index };
        for gui.button_states {
            if it.id == id {
                found = true;
                index = it_index;
                break;
            }
        }
    }

    if !found {
        index = gui.button_states.count;

        s: Button_State;
        s.id.location = id_location;
        s.id.index    = id_index;
        array_add(*gui.button_states, s);
    }

    state := *gui.button_states[index];
    state.frame = gui.frame;

    if rect_contains(rect, input_state.mouse_position) {
        luma = 1.1;

        was_hovered := state.flags & .HOVERED;
        was_down    := state.flags & .DOWN;

        if !was_hovered {
            state.flags |= .HOVERED;
            events      |= .HOVERED;
        }

        if input_state.keys[Key_Code.MOUSE_BUTTON_LEFT] & .PRESSED {
            if !was_down {
                state.flags |= .DOWN;
                events      |= .PRESSED;
            }
        }

        if state.flags & .HOVERED {
            luma = 1.2;
        }

        triggered = state.flags & .DOWN && input_state.keys[Key_Code.MOUSE_BUTTON_LEFT] & .RELEASED;
    } else {
        state.flags &= ~.HOVERED;
    }

    if input_state.keys[Key_Code.MOUSE_BUTTON_LEFT] & .RELEASED {
        state.flags &= ~.DOWN;
    }

    draw_rect(*gui.render_lists, rect, texture_rect, texture_name, .{ luma, luma, luma, 1 });

    return triggered, events;
}

Slider_Events :: enum_flags u32 {
    NONE :: 0;

    HOVERED  :: 0x01;
    PRESSED  :: 0x02;
    RELEASED :: 0x04;
}

Slider_State :: struct {
    // TODO(jt): @Memory Can we have a more compact representation of the ID? Maybe some bitpacking,
    // maybe a 128bit or 64bit hash (with compile time collision checking)?
    id:    Id;
    frame: u64;
    flags: Flags;

    Flags :: enum_flags u32 {
        NONE    :: 0;

        SLIDER_HOVERED :: 0x01;
        HANDLE_HOVERED :: 0x02;
        DOWN           :: 0x04;
    }
}

// TODO(jt): We'd like to use a function that returns FormatFloat as formatter below, but that uses
// Any, which loses the data pointer once it returns, so we have a create a whole new string that we
// copy around.
slider :: (gui: *Gui, input_state: Input_State, position: Vector2, label: string, value: *f32, formatter := (x: f32) -> string { return tprint("%", x); }, scale := 1.0, font_kind := Font_Kind.LIGHT, font_kind_hovered := Font_Kind.SHADOW, id_location := #caller_location, id_index := 0) -> bool, Slider_Events {
    TILE_SIZE :: TINY_DUNGEON_FONT_TILE_SIZE;

    SLIDER_TILE_WIDTH               :: 9.0;
    SLIDER_TILE_WIDTH_INNER         :: SLIDER_TILE_WIDTH - 1.0;

    slider_pixel_width_inner := SLIDER_TILE_WIDTH_INNER * scale * TILE_SIZE.x;

    half_tile_pixel_width := 0.5 * scale * TILE_SIZE.x;

    events: Slider_Events;

    slider_rect: Rect;
    slider_rect.x = position.x;
    slider_rect.y = position.y;
    slider_rect.w = scale * TILE_SIZE.x * SLIDER_TILE_WIDTH;
    slider_rect.h = scale * TILE_SIZE.y;

    make_handle_rect :: inline (position: Vector2, scale: f32, value: f32) -> Rect {
        slider_pixel_width_inner := SLIDER_TILE_WIDTH_INNER * scale * TILE_SIZE.x;

        r: Rect;
        r.x = position.x + value * slider_pixel_width_inner;
        r.y = position.y;
        r.w = scale * TILE_SIZE.x;
        r.h = scale * TILE_SIZE.y;

        return r;
    }

    handle_rect := make_handle_rect(position, scale, value.*);

    changed := false;

    // TODO(jt): @Cleanup This is a copypaste of the button thing. Unify.
    //
    // TODO(jt): @Speed Have a faster way of finding state for the control. We could do a hash table
    // maybe. It would work, but it sounds like we are giving up? In wfgui, the IDs only had to be
    // unique across siblings, which limited this speed problem. Hmmm.
    found := false;
    index := -1;
    {
        id := Id.{ id_location, id_index };
        for gui.slider_states {
            if it.id == id {
                found = true;
                index = it_index;
                break;
            }
        }
    }

    if !found {
        index = gui.slider_states.count;

        s: Slider_State;
        s.id.location = id_location;
        s.id.index    = id_index;
        array_add(*gui.slider_states, s);
    }

    state := *gui.slider_states[index];
    state.frame = gui.frame;

    luma := 0.75;

    if rect_contains(handle_rect, input_state.mouse_position) {
        luma = 0.9;
        font_kind = font_kind_hovered;

        was_hovered := state.flags & .HANDLE_HOVERED;
        was_down    := state.flags & .DOWN;

        if !was_hovered {
            state.flags |= .HANDLE_HOVERED;
            events |= .HOVERED;
        }

        if input_state.keys[Key_Code.MOUSE_BUTTON_LEFT] & .PRESSED {
            if !was_down {
                state.flags |= .DOWN;
                events |= .PRESSED;
            }
        }
    } else if rect_contains(slider_rect, input_state.mouse_position) {
        luma = 0.9;
        font_kind = font_kind_hovered;

        was_hovered := state.flags & .SLIDER_HOVERED;
        was_down    := state.flags & .DOWN;

        if !was_hovered {
            state.flags |= .SLIDER_HOVERED;
            events |= .HOVERED;
        }

        if input_state.keys[Key_Code.MOUSE_BUTTON_LEFT] & .PRESSED {
            if !was_down {
                state.flags |= .DOWN;
                events |= .PRESSED;
            }
        }

        if state.flags & .DOWN {
            luma = 1.0;
        }
    } else {
        state.flags &= ~.HANDLE_HOVERED;
        state.flags &= ~.SLIDER_HOVERED;
    }

    if input_state.keys[Key_Code.MOUSE_BUTTON_LEFT] & .RELEASED {
        was_down := state.flags & .DOWN;

        if was_down {
            state.flags &= ~.DOWN;
            events |= .RELEASED;
        }
    }

    if state.flags & .DOWN {
        distance  := input_state.mouse_position.x - (slider_rect.x + half_tile_pixel_width);
        new_value := clamp(distance / slider_pixel_width_inner, 0.0, 1.0);

        changed = new_value != value.*;
        value.* = new_value;
    }

    handle_rect = make_handle_rect(position, scale, value.*);

    draw_rect(*gui.render_lists, slider_rect, .{ 0.5, 0.5, 0.5, 1 });
    draw_rect(*gui.render_lists, handle_rect, .{ 1.0, 1.0, 1.0, 1 });

    draw_text(
        *gui.render_lists,
        Vector2.{ slider_rect.x + slider_rect.w + 2 * scale * TILE_SIZE.x, slider_rect.y },
        tprint("% %", label, formatter(value.*)),
        scale,
        font_kind,
        .{ luma , luma, luma, 1.0 }
    );

    return changed, events;
}

Id :: struct {
    location: Source_Code_Location;
    index:    s64;
}

operator == :: (a: Id, b: Id) -> bool {
    // TODO(jt): @Cleanup Source_Code_Location could have a operator==, but it doesn't, so we spell it out here.
    if a.location.fully_pathed_filename != b.location.fully_pathed_filename  return false;
    if a.location.line_number != b.location.line_number                      return false;
    if a.location.character_number != b.location.character_number            return false;
    if a.index != b.index                                                    return false;

    return true;
}
