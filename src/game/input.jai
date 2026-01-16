Input :: struct {
    time:  Apollo_Time;
    dtime: Apollo_Time;

    window_size: IVector2;
    // TODO(jt): @Correctness Instead of polling for mouse_position once per frame, accumulate a
    // buffer of positions it went to during that frame. This likely won't be at full precision,
    // because I believe VM_MOUSEMOVE does some resampling of the raw input? Both would be okay for
    // this game.
    //
    // UPDATE: We now do bresenham lines inside the game hide this issue, but this could still
    // increase the path quality.
    mouse_position: Vector2;

    key_events: [] Key_Event;
}

Key_Event :: struct {
    key_code: Key_Code;
    key_pressed: u32;
}

KEY_CODE_COUNT :: #run enum_highest_value(Key_Code) + 1;
Key_Code :: enum u32 {
    UNINITIALIZED :: 0;

    // TODO(jt): @Cleanup Is there any way to standardize this across all platforms so that we can
    // just cast an integer to this enum? If not all, then maybe at least some (Windows and Linux)?

    BACKSPACE :: 1;
    ESCAPE    :: 2;
    SPACEBAR  :: 3;

    E :: 4;
    M :: 5;
    Q :: 6;
    R :: 7;
    S :: 8;
    X :: 9;
    V :: 10;
    Z :: 11;

    ALT   :: 12;
    CTRL  :: 13;
    SHIFT :: 14;
    CMD   :: 15;

    MOUSE_BUTTON_LEFT   :: 16;
    MOUSE_BUTTON_RIGHT  :: 17;
    MOUSE_BUTTON_MIDDLE :: 18;
}

Input_State :: struct {
    // TODO(jt): mouse_position copied over from Input for now. When we transition to
    // having a buffer of mouse move events, mouse_position here will be just the final mouse
    // position.
    mouse_position:          Vector2;
    mouse_position_previous: Vector2;

    keys: [KEY_CODE_COUNT] Key_State;
}

Key_State :: enum_flags u8 {
    NONE     :: 0;
    DOWN     :: 0x01;
    PRESSED  :: 0x02;
    RELEASED :: 0x04;
}

input_state_update :: (input_state: *Input_State, input: Input) {
    input_state.mouse_position_previous = input_state.mouse_position;
    input_state.mouse_position          = input.mouse_position;

    for * input_state.keys {
        it.* &= ~(.PRESSED | .RELEASED);
    }

    for input.key_events {
        if it.key_pressed {
            // Ignore another key press event, if the key is already down. If we do want this later,
            // we can always make another flag (PRESSED_BY_OS_AUTOREPAT),
            if !(input_state.keys[it.key_code] & .DOWN) {
                input_state.keys[it.key_code] |= .DOWN | .PRESSED;
            }
        } else {
            // Do not clear PRESSED. So that we can detect single-frame press and release.
            input_state.keys[it.key_code] &= ~.DOWN;
            input_state.keys[it.key_code] |= .RELEASED;
        }
    }
}
