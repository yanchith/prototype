// TOOD(jt): What color space is this? Does Simp do any transforms, or this is sRGB?
COLOR_UNSOLVED   :: Vector4.{ 0.45, 0.45, 0.45, 1.0 };
COLOR_SOLVED     :: Vector4.{ 0.90, 0.90, 0.90, 1.0 };
COLOR_UNSOLVABLE :: Vector4.{ 1.00, 0.45, 0.45, 1.0 };

Level :: struct {
    has_errors: bool;

    name: string;
    hint_flags: Hint_Flags;
    board: Board;
    editing_mode: Editing_Mode;

    clicked_on_read_only_tile: IVector2;
    clicked_on_read_only_time: Apollo_Time;

    flash_check_button_time: Apollo_Time;

    effects: Effects;
    effects_rng: Random_State; // Only for visuals!

    solved_currently: bool;

    // TODO(jt): #malloc @Memory Decide what arena this goes in. For now this is malloc.
    undo_buffer: [..] Undo_Event;
}

Editing_Mode :: enum u8 {
    NONE                  :: 0;
    PLACING_WALL_MARKERS  :: 1;
    PLACING_EMPTY_MARKERS :: 2;
    REMOVING_MARKERS      :: 3;
}

Undo_Event :: struct {
    // TODO(jt): @Memory Compress the position to something smaller, like 2xs8.
    position: IVector2;
    flags: Undo_Flags;
}

Undo_Flags :: enum_flags u8 {
    NONE    :: 0;
    THROUGH :: 0x01; // If set, don't stop after processing this event when undoing.

    PLACED_WALL   :: 0x10;
    PLACED_EMPTY  :: 0x20;
    REMOVED_WALL  :: 0x40;
    REMOVED_EMPTY :: 0x80;
}

// TODO(jt): #array_reset @Cleanup Harmonize reset conventions with JAI once it itself harmonizes.
level_reset :: (level: *Level) {
    level.has_errors = false;

    level.name = "";
    level.hint_flags = .NONE;
    board_reset(*level.board);
    level.editing_mode = Editing_Mode.NONE;

    level.clicked_on_read_only_tile = TILE_POSITION_INVALID;
    level.clicked_on_read_only_time = APOLLO_TIME_INVALID;

    level.flash_check_button_time = APOLLO_TIME_INVALID;

    effects_reset(*level.effects);

    level.solved_currently = false;

    array_reset_keeping_memory(*level.undo_buffer);
}

level_load :: (level: *Level, platform: Platform, level_name: string, hint_flags: Hint_Flags, solved_on_the_overworld: bool, board_state: [] Tile) {
    if level.effects_rng.low == 0 && level.effects_rng.high == 0 {
        random_seed(*level.effects_rng, 0xcafebabe);
    }

    level_reset(level);

    level_file_name := tprint("./data/puzzles/%.txt", level_name);

    level.name = level_name;
    level.hint_flags = hint_flags;

    success, board_data := platform.read_file(level_file_name,, temp);
    if !success {
        log_error("Could not load level %", level_name);
        return;
    }
    board_parse(*level.board, board_data, unsolve = false, unsolve_except_walls = false);

    #if DEVELOPER {
        check, flags := board_check(level.board);
        if check != .SOLVED {
            log_error("Level % is not solved (correctly?) in the asset file. Check flags: %", level_name, flags);
            level.has_errors = true;
        }
    }

    board_unsolve(*level.board);

    if board_state.count {
        if board_state.count == level.board.tiles.count {
            // TODO(jt): @Cleanup This is a last resort validation, so that we don't overwrite the
            // board with something completely bad. Maybe we should have just serialized the things
            // the player could have marked, and apply those marks here? Hmmm.
            valid := true;
            for 0..level.board.tiles.count - 1 {
                old := level.board.tiles[it];
                new := board_state[it];

                if old == new {
                    continue;
                }

                if tile_is_clue(old) {
                    valid = false;
                    break;
                }

                if old & .READ_ONLY {
                    valid = false;
                    break;
                }

                if new == old | .MARKED_EMPTY {
                    continue;
                }

                if old == new | .MARKED_EMPTY {
                    continue;
                }

                if new == old | .MARKED_WALL {
                    continue;
                }

                if old == new | .MARKED_WALL {
                    continue;
                }
            }

            if valid {
                array_view_copy(level.board.tiles, board_state);
            } else {
                level.has_errors = true;
                log_error("Level % could not apply saved saved board state, because it is invalid");
            }

            check, flags := board_check(level.board);

            // Only set solved_currently if both the serialized state is solved, and the overworld
            // has already stored that this level is solved. This is to prevent a situation where a
            // player solves the level, but then leaves, re-enters, and doesn't get to experience
            // the sparkles.

            if solved_on_the_overworld && check == .SOLVED {
                level.solved_currently = true;
            }
        } else {
            level.has_errors = true;
            log_error("Level % has incompatible board state saved on the overworld", level_name);
        }
    }
}

level_update_and_render :: (level: *Level, platform: Platform, input: Input, input_state: Input_State, audio: *Audio, gui: *Gui, render_lists: *Render_Lists) -> Game_Transition {
    transition: Game_Transition;

    dtime := cast(f32, to_float64_seconds(input.dtime));

    // TODO(jt): @Cleanup @Speed Get viewport as a parameter.
    viewport := viewport_for_scene(SCREEN_SIZE_IN_TILES, TINY_DUNGEON_TILE_SIZE, input.window_size);
    viewport_transform_position :: (position: Vector2) -> Vector2 #expand {
        return viewport_transform_position(viewport, position);
    }
    viewport_transform_rect :: (r: Rect) -> Rect #expand {
        return viewport_transform_rect(viewport, r);
    }

    level_drawing_offset := (SCREEN_SIZE_IN_TILES - .{ level.board.xsize, level.board.ysize }) / 2;
    assert(level_drawing_offset.x >= 0 && level_drawing_offset.y >= 0);

    get_board_position_from_screen_position :: (position: Vector2) -> IVector2 #expand {
        TILE_SIZE :: #run ivector_to_vector(TINY_DUNGEON_TILE_SIZE);

        position_relative_to_board_origin := position - viewport.rect.p0 - viewport.scale * ivector_to_vector(level_drawing_offset) * TILE_SIZE;
        p := position_relative_to_board_origin / (viewport.scale * TILE_SIZE);
        x := cast(s32, floor(p.x));
        y := cast(s32, floor(p.y));

        return IVector2.{ x, y };
    }

    //
    // Update
    //
    mb_left_pressed   := input_state.keys[Key_Code.MOUSE_BUTTON_LEFT] & .PRESSED;
    mb_right_pressed  := input_state.keys[Key_Code.MOUSE_BUTTON_RIGHT] & .PRESSED;
    mb_left_released  := input_state.keys[Key_Code.MOUSE_BUTTON_LEFT] & .RELEASED;
    mb_right_released := input_state.keys[Key_Code.MOUSE_BUTTON_RIGHT] & .RELEASED;

    board_modified                       := false;
    board_modification_attempted         := false;
    board_position_under_cursor          := get_board_position_from_screen_position(input_state.mouse_position);
    board_position_under_previous_cursor := get_board_position_from_screen_position(input_state.mouse_position_previous);

    {
        entered_editing_mode := false;

        if mb_left_pressed || mb_right_pressed {
            if board_in_bounds(level.board, board_position_under_cursor) {
                board_modification_attempted = true;

                tile := board_get_pointer(*level.board, board_position_under_cursor);
                if !tile_is_clue(tile.*) && !(tile.* & .READ_ONLY) {
                    if tile_is_marked(tile.*) && (mb_left_pressed || mb_right_pressed) {
                        level.editing_mode = .REMOVING_MARKERS;
                        entered_editing_mode = true;
                    } else if mb_left_pressed {
                        level.editing_mode = .PLACING_WALL_MARKERS;
                        entered_editing_mode = true;
                    } else if mb_right_pressed {
                        level.editing_mode = .PLACING_EMPTY_MARKERS;
                        entered_editing_mode = true;
                    }
                } else {
                    level.clicked_on_read_only_tile = board_position_under_cursor;
                    level.clicked_on_read_only_time = input.time;
                    audio_play_sound(audio, SFX_PLACE_READ_ONLY_ATTEMPT);
                }
            }
        }

        // Get out of the editing mode early, if a button was released this frame, so that we aren't
        // latent in our reaction to the button releases. However, do stay in editing mode for at
        // least one frame.
        //
        // (There is code later below, that unconditionally exits the editing mode after the edits
        // are done, in case the button was both pressed and released in a single frame).
        if !entered_editing_mode {
            if mb_left_released || mb_right_released {
                level.editing_mode = .NONE;
            }
        }

        if level.editing_mode != .NONE {
            p0 := board_position_under_previous_cursor;
            p1 := board_position_under_cursor;
            if entered_editing_mode {
                // We just entered the editing mode, therefore we only process the one tile we
                // clicked on currently, in case the cursor was previously moving.
                p0 = board_position_under_cursor;
            }

            for bresenham_line(p0.x, p0.y, p1.x, p1.y) {
                if !board_in_bounds(level.board, it) {
                    continue;
                }

                board_modification_attempted = true;

                tile := board_get_pointer(*level.board, it);
                if tile_is_clue(tile.*)  continue;
                if tile.* & .READ_ONLY   continue;

                undo_flags: Undo_Flags;
                if level.editing_mode == {
                    case .PLACING_WALL_MARKERS; {
                        if tile.* == .NONE {
                            tile.* |= .MARKED_WALL;
                            undo_flags |= .PLACED_WALL;
                            board_modified = true;

                            audio_play_sound(audio, SFX_PLACE_OR_REMOVE_WALL);
                        }
                    }

                    case .PLACING_EMPTY_MARKERS; {
                        if tile.* == .NONE {
                            tile.* |= .MARKED_EMPTY;
                            undo_flags |= .PLACED_EMPTY;
                            board_modified = true;

                            audio_play_sound(audio, SFX_PLACE_OR_REMOVE_EMPTY);
                        }
                    }

                    case .REMOVING_MARKERS; {
                        if tile.* & .MARKED_WALL {
                            tile.* &= ~.MARKED_WALL;
                            undo_flags |= .REMOVED_WALL;
                            board_modified = true;

                            audio_play_sound(audio, SFX_PLACE_OR_REMOVE_WALL);
                        } else if tile.* & (.MARKED_EMPTY | .MARKED_TREASURE_ROOM) {
                            tile.* &= ~(.MARKED_EMPTY | .MARKED_TREASURE_ROOM);
                            undo_flags |= .REMOVED_EMPTY;
                            board_modified = true;

                            audio_play_sound(audio, SFX_PLACE_OR_REMOVE_EMPTY);
                        }
                    }
                }

                if undo_flags {
                    // We only add .THROUGH here, so that we are sure that this code only triggers
                    // if the tile was actually modified. When this happens, bresenham_line actually
                    // only returns one point, because we truncated it to start at the current
                    // cursor position.
                    if !entered_editing_mode {
                        undo_flags |= .THROUGH;
                    }

                    array_add(*level.undo_buffer, .{ it, undo_flags });
                }
            }
        }

        if mb_left_released || mb_right_released {
            level.editing_mode = .NONE;
        }
    }

    if level.clicked_on_read_only_time != APOLLO_TIME_INVALID {
        ms := to_milliseconds(input.time - level.clicked_on_read_only_time);
        if ms > 200 {
            level.clicked_on_read_only_tile = TILE_POSITION_INVALID;
            level.clicked_on_read_only_time = APOLLO_TIME_INVALID;
        }
    }

    #if DEVELOPER {
        if input_state.keys[Key_Code.E] & .PRESSED {
            board_erase_secret_clues(*level.board);
        }
    }

    {
        activated, events := button(gui, input_state, viewport_transform_position(.{ 10, 230 }), "Leave (Q)", scale = viewport.scale);
        activated |= cast(bool, input_state.keys[Key_Code.Q] & .PRESSED);
        if activated {
            transition.type  = .TO_OVERWORLD;
            transition.level = level.name;

            // TODO(jt): #malloc @Memory @Cleanup @Hack We currently allocate this with malloc and
            // leak it. We can't really use temporary storage, because it doesn't survive between
            // two frames. This should probably be in the arena for things that are for
            // transitioning between scenes.
            transition.board_state = array_copy(level.board.tiles);

            data := Game_Transition.To_Overworld_Data.{ false };
            transition.data.to_overworld = data;

            audio_play_sound(audio, SFX_LEAVE_LEVEL);
        }

        // TODO(jt): @Cleanup Consider making a button that takes the audio context and just fires the event itself.
        if events & .HOVERED {
            audio_play_sound(audio, SFX_UI_HOVER);
        }
    }

    if !level.solved_currently {
        color := Vector3.{ 1, 1, 1 };
        if level.flash_check_button_time != APOLLO_TIME_INVALID {
            ms := to_milliseconds(input.time - level.flash_check_button_time);
            if ms > 200 {
                level.flash_check_button_time = APOLLO_TIME_INVALID;
            } else {
                color = COLOR_UNSOLVABLE.xyz;
            }
        }

        activated, events := button(gui, input_state, viewport_transform_position(.{ 110, 230 }), "Check (Space)", scale = viewport.scale, color = color);
        activated |= cast(bool, input_state.keys[Key_Code.SPACEBAR] & .PRESSED);
        if activated {
            effects_reset(*level.effects);
            check, flags, hints := board_check(level.board, hint_flags = level.hint_flags,, temp);

            if check == .SOLVED {
                level.solved_currently = true;
                audio_play_sound(audio, SFX_SOLVE_LEVEL_INSIDE);

                FANFARE_FX_DURATION    :: 0.5;
                FANFARE_FX_ANIM_FRAMES :: Effect_Frame.[
                    .{ rect = SPARKLE_ANIM_RECT0, color = .{ 1, 1, 0.9, 1 } },
                    .{ rect = SPARKLE_ANIM_RECT1, color = .{ 1, 1, 0.9, 1 } },
                    .{ rect = SPARKLE_ANIM_RECT2, color = .{ 1, 1, 0.9, 1 } },
                    .{ rect = SPARKLE_ANIM_RECT3, color = .{ 1, 1, 0.9, 1 } },
                    .{ rect = SPARKLE_ANIM_RECT4, color = .{ 1, 1, 0.9, 1 } },
                    .{ rect = SPARKLE_ANIM_RECT5, color = .{ 1, 1, 0.9, 1 } },
                    .{ rect = SPARKLE_ANIM_RECT6, color = .{ 1, 1, 0.9, 1 } },
                ];

                PARTICLE_COUNT :: 5;
                for 0..PARTICLE_COUNT - 1 {
                    BORDER: f32 = 25.0;
                    x := BORDER + random_get_zero_to_one(*level.effects_rng) * (SCREEN_SIZE_IN_GAME_PIXELS.x - 2 * BORDER);
                    y := BORDER + random_get_zero_to_one(*level.effects_rng) * (SCREEN_SIZE_IN_GAME_PIXELS.y - 2 * BORDER);

                    DELAY_SPREAD :: 0.5;
                    delay := random_get_zero_to_one(*level.effects_rng) * DELAY_SPREAD;

                    effects_add(*level.effects, .{
                        rect         = .{ x, y, cast(f32, TINY_DUNGEON_TILE_SIZE.x), cast(f32, TINY_DUNGEON_TILE_SIZE.y) },
                        texture_name = TEX_ORYX_TINY_DUNGEON_FX,

                        frames   = FANFARE_FX_ANIM_FRAMES,
                        duration = FANFARE_FX_DURATION,
                        delay    = delay,
                    });
                }
            } else {
                level.solved_currently = false;
                level.flash_check_button_time = input.time;

                if hints.count {
                    onetime_hints_duration := generate_onetime_hint_effects(*level.effects, hints, level_drawing_offset);
                    generate_continuous_hint_effects(*level.effects, hints, level_drawing_offset, onetime_hints_duration);
                }

                audio_play_sound(audio, SFX_DENIED);
            }
        }

        // TODO(jt): @Cleanup Consider making a button that takes the audio context and just fires the event itself.
        if events & .HOVERED {
            audio_play_sound(audio, SFX_UI_HOVER);
        }
    } else {
        activated, events := button(gui, input_state, viewport_transform_position(.{ 110, 230 }), "Solve (Space)", scale = viewport.scale);
        activated |= cast(bool, input_state.keys[Key_Code.SPACEBAR] & .PRESSED);

        if activated {
            transition.type  = .TO_OVERWORLD;
            transition.level = level.name;

            // TODO(jt): #malloc @Memory @Cleanup @Hack We currently allocate this with malloc and
            // leak it. We can't really use temporary storage, because it doesn't survive between
            // two frames. This should probably be in the arena for things that are for
            // transitioning between scenes.
            transition.board_state = array_copy(level.board.tiles);

            data := Game_Transition.To_Overworld_Data.{ level.solved_currently };
            transition.data.to_overworld = data;

            audio_play_sound(audio, SFX_LEAVE_LEVEL);
        }

        // TODO(jt): @Cleanup Consider making a button that takes the audio context and just fires the event itself.
        if events & .HOVERED {
            audio_play_sound(audio, SFX_UI_HOVER);
        }
    }

    {
        activated, events := button(gui, input_state, viewport_transform_position(.{ 230, 230 }), "Undo (Z)", scale = viewport.scale);
        activated |= cast(bool, input_state.keys[Key_Code.Z] & .PRESSED);
        if activated {
            board_modification_attempted = true;

            if level.undo_buffer.count {
                board_modified = true;
                audio_play_sound(audio, SFX_UNDO);
            }

            keep_undoing := true;
            while keep_undoing && level.undo_buffer.count {
                undo := pop(*level.undo_buffer);

                if !(undo.flags & .THROUGH) {
                    keep_undoing = false;
                }

                tile := board_get_pointer(*level.board, undo.position.x, undo.position.y);

                if undo.flags & .PLACED_WALL {
                    tile.* &= ~.MARKED_WALL;
                }
                if undo.flags & .PLACED_EMPTY {
                    tile.* &= ~.MARKED_EMPTY;
                }
                if undo.flags & .REMOVED_WALL {
                    tile.* |= .MARKED_WALL;
                }
                if undo.flags & .REMOVED_EMPTY {
                    tile.* |= .MARKED_EMPTY;
                }
            }
        }

        // TODO(jt): @Cleanup Consider making a button that takes the audio context and just fires the event itself.
        if events & .HOVERED {
            audio_play_sound(audio, SFX_UI_HOVER);
        }
    }

    {
        activated, events := button(gui, input_state, viewport_transform_position(.{ 320, 230 }), "Reset (R)", scale = viewport.scale);
        activated |= cast(bool, input_state.keys[Key_Code.R] & .PRESSED);
        if activated {
            board_modification_attempted = true;
            board_modified = true;
            unsolve_board_generating_undo_events(*level.board, *level.undo_buffer);
            audio_play_sound(audio, SFX_RESET);
        }

        // TODO(jt): @Cleanup Consider making a button that takes the audio context and just fires the event itself.
        if events & .HOVERED {
            audio_play_sound(audio, SFX_UI_HOVER);
        }
    }

    if board_modification_attempted || board_modified {
        level.solved_currently = false;
        // We currently don't hold the old effect handles anywhere, so we just nuke eveything
        // here instead of doing precision cleanup.
        effects_reset(*level.effects);

        // We also used to update the continuous hint effects here, but now we just hide them, as
        // their visuals tend to be in the way.
    }

    if level.has_errors {
        draw_error_text(*gui.render_lists, viewport_transform_position(.{ 10, 20 }), "ERROR", scale = viewport.scale);
    }

    //
    // Render
    //

    // TODO(jt): This actually draws part of the level filename. We should store the actual display name in the puzzle file.
    level_name := level.name;
    {
        underscore_index := String.find_index_from_left(level_name, "_");
        if underscore_index != -1 {
            advance(*level_name, underscore_index + 1);
        }
    }

    draw_text(
        render_lists,
        viewport_transform_position(.{ 10, 6 }),
        level_name,
        scale = viewport.scale,
        font_kind = .LIGHT,
    );

    for y: 0..level.board.ysize - 1 {
        for x: 0..level.board.xsize - 1 {
            tile := board_get(level.board, x, y);
            tile_rect := viewport_transform_rect(make_tile_rect(
                level_drawing_offset.x + x,
                level_drawing_offset.y + y,
                TINY_DUNGEON_TILE_SIZE,
            ));

            hovered   := rect_contains(tile_rect, input.mouse_position);
            read_only := tile_is_clue(tile) || tile & .READ_ONLY;

            if read_only {
                if level.clicked_on_read_only_tile == .{ x, y } {
                    draw_rect(render_lists, tile_rect, GROUND_RO_HOVERED_RECT, TEX_MARKERS);
                } else {
                    draw_rect(render_lists, tile_rect, GROUND_RO_RECT, TEX_MARKERS);
                }
            } else {
                if hovered {
                    draw_rect(render_lists, tile_rect, GROUND_RW_HOVERED_RECT, TEX_MARKERS);
                } else {
                    draw_rect(render_lists, tile_rect, GROUND_RW_RECT, TEX_MARKERS);
                }
            }
        }
    }

    for 0..level.board.xsize - 1 {
        north_tile_rect := viewport_transform_rect(make_tile_rect(
            cast(s32, level_drawing_offset.x + it),
            level_drawing_offset.y - 1,
            TINY_DUNGEON_TILE_SIZE,
        ));

        south_tile_rect := viewport_transform_rect(make_tile_rect(
            cast(s32, level_drawing_offset.x + it),
            level_drawing_offset.y + level.board.ysize,
            TINY_DUNGEON_TILE_SIZE,
        ));

        north_shadow_tile_rect := viewport_transform_rect(make_tile_rect(
            cast(s32, level_drawing_offset.x + it),
            level_drawing_offset.y,
            TINY_DUNGEON_TILE_SIZE,
        ));

        draw_rect(render_lists, north_tile_rect, BORDER_NORTH_RECT, TEX_BORDERS);
        draw_rect(render_lists, south_tile_rect, BORDER_SOUTH_RECT, TEX_BORDERS);
        draw_rect(render_lists, north_shadow_tile_rect, BORDER_SHADOW_NORTH_RECT, TEX_BORDERS);
    }

    for 0..level.board.ysize - 1 {
        west_tile_rect := viewport_transform_rect(make_tile_rect(
            level_drawing_offset.x - 1,
            cast(s32, level_drawing_offset.y + it),
            TINY_DUNGEON_TILE_SIZE,
        ));

        east_tile_rect := viewport_transform_rect(make_tile_rect(
            level_drawing_offset.x + level.board.xsize,
            cast(s32, level_drawing_offset.y + it),
            TINY_DUNGEON_TILE_SIZE,
        ));

        west_shadow_tile_rect := viewport_transform_rect(make_tile_rect(
            level_drawing_offset.x,
            cast(s32, level_drawing_offset.y + it),
            TINY_DUNGEON_TILE_SIZE,
        ));

        draw_rect(render_lists, west_tile_rect, BORDER_WEST_RECT, TEX_BORDERS);
        draw_rect(render_lists, east_tile_rect, BORDER_EAST_RECT, TEX_BORDERS);
        draw_rect(render_lists, west_shadow_tile_rect, BORDER_SHADOW_WEST_RECT, TEX_BORDERS);
    }

    {
        ne_tile_rect := viewport_transform_rect(make_tile_rect(
            level_drawing_offset.x + level.board.xsize,
            level_drawing_offset.y - 1,
            TINY_DUNGEON_TILE_SIZE,
        ));

        nw_tile_rect := viewport_transform_rect(make_tile_rect(
            level_drawing_offset.x - 1,
            level_drawing_offset.y - 1,
            TINY_DUNGEON_TILE_SIZE,
        ));

        se_tile_rect := viewport_transform_rect(make_tile_rect(
            level_drawing_offset.x + level.board.xsize,
            level_drawing_offset.y + level.board.ysize,
            TINY_DUNGEON_TILE_SIZE,
        ));

        sw_tile_rect := viewport_transform_rect(make_tile_rect(
            level_drawing_offset.x - 1,
            level_drawing_offset.y + level.board.ysize,
            TINY_DUNGEON_TILE_SIZE,
        ));

        draw_rect(render_lists, ne_tile_rect, BORDER_NORTH_EAST_RECT, TEX_BORDERS);
        draw_rect(render_lists, nw_tile_rect, BORDER_NORTH_WEST_RECT, TEX_BORDERS);
        draw_rect(render_lists, se_tile_rect, BORDER_SOUTH_EAST_RECT, TEX_BORDERS);
        draw_rect(render_lists, sw_tile_rect, BORDER_SOUTH_WEST_RECT, TEX_BORDERS);
    }

    // TODO(jt): @Speed This is a little stupid that we iterate over the board a second time. Merge
    // this with the other board drawing loop, unless that's too complex?
    for y: 0..level.board.ysize - 1 {
        for x: 0..level.board.xsize - 1 {
            tile := board_get(level.board, x, y);
            tile_rect := viewport_transform_rect(make_tile_rect(
                level_drawing_offset.x + x,
                level_drawing_offset.y + y,
                TINY_DUNGEON_TILE_SIZE,
            ));

            // TODO(jt): Crests can be combined with monsters and treasure, but this renderer
            // doesn't know about it. Make it work with monsters/treasures holding crests.
            if tile & .CLUE_MONSTER {
                draw_rect(render_lists, tile_rect, CLUE_MONSTER_RECT, TEX_ORYX_TINY_DUNGEON_MONSTERS);
            } else if tile & .CLUE_TREASURE {
                draw_rect(render_lists, tile_rect, CLUE_TREASURE_RECT, TEX_ORYX_TINY_DUNGEON_WORLD);
            } else if tile &. CLUE_TRAP {
                draw_rect(render_lists, tile_rect, CLUE_TRAP_RECT, TEX_TRAP);
            } else if tile == .CLUE_CREST_SINGLE | .CLUE_CREST_ALT {
                draw_rect(render_lists, tile_rect, CLUE_CREST_SINGLE_ALT_RECT, TEX_CRESTS);
            } else if tile == .CLUE_CREST_DOUBLE | .CLUE_CREST_ALT {
                draw_rect(render_lists, tile_rect, CLUE_CREST_DOUBLE_ALT_RECT, TEX_CRESTS);
            } else if tile == .CLUE_CREST_TRIPLE | .CLUE_CREST_ALT {
                draw_rect(render_lists, tile_rect, CLUE_CREST_TRIPLE_ALT_RECT, TEX_CRESTS);
            } else if tile & .CLUE_CREST_SINGLE {
                draw_rect(render_lists, tile_rect, CLUE_CREST_SINGLE_RECT, TEX_CRESTS);
            } else if tile & .CLUE_CREST_DOUBLE {
                draw_rect(render_lists, tile_rect, CLUE_CREST_DOUBLE_RECT, TEX_CRESTS);
            } else if tile & .CLUE_CREST_TRIPLE {
                draw_rect(render_lists, tile_rect, CLUE_CREST_TRIPLE_RECT, TEX_CRESTS);
            } else if tile & .CLUE_MIRROR_NE {
                draw_rect(render_lists, tile_rect, CLUE_MIRROR_NE_RECT, TEX_MAGIC_MIRROR);
            } else if tile & .CLUE_MIRROR_NW {
                draw_rect(render_lists, tile_rect, CLUE_MIRROR_NW_RECT, TEX_MAGIC_MIRROR);
            } else if tile & .CLUE_MIRROR_SW {
                draw_rect(render_lists, tile_rect, CLUE_MIRROR_SW_RECT, TEX_MAGIC_MIRROR);
            } else if tile & .CLUE_MIRROR_SE {
                draw_rect(render_lists, tile_rect, CLUE_MIRROR_SE_RECT, TEX_MAGIC_MIRROR);
            } else if tile & .MARKED_WALL {
                draw_rect(render_lists, tile_rect, MARKED_WALL_RECT, TEX_MARKERS);
            } else if tile & (.MARKED_EMPTY | .MARKED_TREASURE_ROOM) {
                draw_rect(render_lists, tile_rect, MARKED_EMPTY_RECT, TEX_MARKERS);
            }
        }
    }

    {
        // TODO(jt): @Speed Do not compute per frame?
        check := board_check_connectivity(level.board);
        color := COLOR_SOLVED;
        if check == .OPEN        color = COLOR_UNSOLVED;
        if check == .UNSOLVABLE  color = COLOR_UNSOLVABLE;

        tile_rect := viewport_transform_rect(make_tile_rect(
            level_drawing_offset.x - 1,
            level_drawing_offset.y - 1,
            TINY_DUNGEON_TILE_SIZE,
        ));

        draw_rect(render_lists, tile_rect, CONNECTIVITY_SYMBOL_RECT, TEX_MARKERS, color);
    }

    for level.board.xconstraints {
        if it < 0 {
            continue;
        }

        // TODO(jt): @Speed Do not compute per frame?
        wall_count := board_count_walls_in_column(level.board, cast(s32, it_index));
        color := COLOR_UNSOLVED;
        if wall_count == it {
            color = COLOR_SOLVED;
        } else if wall_count > it {
            color = COLOR_UNSOLVABLE;
        }

        tile_rect := viewport_transform_rect(make_tile_rect(
            cast(s32, level_drawing_offset.x + it_index),
            level_drawing_offset.y - 1,
            TINY_DUNGEON_TILE_SIZE,
        ));

        // TODO(jt): @Bug? On my desktop Windows, in fullscreen, rendering these glyphs takes also
        // includes a row of pixels from the glyph stored below in the font atlas. However, when
        // viewing capture in renderdoc, this does not happen. Driver bug?

        if it < 10 {
            char_rect := get_centered_character_rect_for_tile(tile_rect, 0, 1, viewport.scale);
            tile_texture_rect: Rect;
            if it == {
                case 0; tile_texture_rect = CHARACTER0_TIGHT_RECT;
                case 1; tile_texture_rect = CHARACTER1_TIGHT_RECT;
                case 2; tile_texture_rect = CHARACTER2_TIGHT_RECT;
                case 3; tile_texture_rect = CHARACTER3_TIGHT_RECT;
                case 4; tile_texture_rect = CHARACTER4_TIGHT_RECT;
                case 5; tile_texture_rect = CHARACTER5_TIGHT_RECT;
                case 6; tile_texture_rect = CHARACTER6_TIGHT_RECT;
                case 7; tile_texture_rect = CHARACTER7_TIGHT_RECT;
                case 8; tile_texture_rect = CHARACTER8_TIGHT_RECT;
                case 9; tile_texture_rect = CHARACTER9_TIGHT_RECT;
            }

            draw_rect(render_lists, char_rect, tile_texture_rect, TEX_ORYX_TINY_DUNGEON_FONT, color);
        } else {
            assert(it < 100);
            first  := it / 10;
            second := it % 10;

            for s64.[first, second] {
                tile_texture_rect: Rect;
                if it == {
                    case 0; tile_texture_rect = CHARACTER0_TIGHT_RECT;
                    case 1; tile_texture_rect = CHARACTER1_TIGHT_RECT;
                    case 2; tile_texture_rect = CHARACTER2_TIGHT_RECT;
                    case 3; tile_texture_rect = CHARACTER3_TIGHT_RECT;
                    case 4; tile_texture_rect = CHARACTER4_TIGHT_RECT;
                    case 5; tile_texture_rect = CHARACTER5_TIGHT_RECT;
                    case 6; tile_texture_rect = CHARACTER6_TIGHT_RECT;
                    case 7; tile_texture_rect = CHARACTER7_TIGHT_RECT;
                    case 8; tile_texture_rect = CHARACTER8_TIGHT_RECT;
                    case 9; tile_texture_rect = CHARACTER9_TIGHT_RECT;
                }

                char_rect := get_centered_character_rect_for_tile(tile_rect, it_index, 2, viewport.scale);
                draw_rect(render_lists, char_rect, tile_texture_rect, TEX_ORYX_TINY_DUNGEON_FONT, color);
            }
        }
    }

    for level.board.yconstraints {
        if it < 0 {
            continue;
        }

        // TODO(jt): @Speed Do not compute per frame?
        wall_count := board_count_walls_in_row(level.board, cast(s32, it_index));
        color := COLOR_UNSOLVED;
        if wall_count == it {
            color = COLOR_SOLVED;
        } else if wall_count > it {
            color = COLOR_UNSOLVABLE;
        }

        tile_rect := viewport_transform_rect(make_tile_rect(
            level_drawing_offset.x - 1,
            level_drawing_offset.y + cast(s32, it_index),
            TINY_DUNGEON_TILE_SIZE,
        ));

        // TODO(jt): @Bug? On my desktop Windows, in fullscreen, rendering these glyphs takes also
        // includes a row of pixels from the glyph stored below in the font atlas. However, when
        // viewing capture in renderdoc, this does not happen. Driver bug?

        if it < 10 {
            char_rect := get_centered_character_rect_for_tile(tile_rect, 0, 1, viewport.scale);
            tile_texture_rect: Rect;
            if it == {
                case 0; tile_texture_rect = CHARACTER0_TIGHT_RECT;
                case 1; tile_texture_rect = CHARACTER1_TIGHT_RECT;
                case 2; tile_texture_rect = CHARACTER2_TIGHT_RECT;
                case 3; tile_texture_rect = CHARACTER3_TIGHT_RECT;
                case 4; tile_texture_rect = CHARACTER4_TIGHT_RECT;
                case 5; tile_texture_rect = CHARACTER5_TIGHT_RECT;
                case 6; tile_texture_rect = CHARACTER6_TIGHT_RECT;
                case 7; tile_texture_rect = CHARACTER7_TIGHT_RECT;
                case 8; tile_texture_rect = CHARACTER8_TIGHT_RECT;
                case 9; tile_texture_rect = CHARACTER9_TIGHT_RECT;
            }

            draw_rect(render_lists, char_rect, tile_texture_rect, TEX_ORYX_TINY_DUNGEON_FONT, color);
        } else {
            assert(it < 100);
            first  := it / 10;
            second := it % 10;

            for s64.[first, second] {
                tile_texture_rect: Rect;
                if it == {
                    case 0; tile_texture_rect = CHARACTER0_TIGHT_RECT;
                    case 1; tile_texture_rect = CHARACTER1_TIGHT_RECT;
                    case 2; tile_texture_rect = CHARACTER2_TIGHT_RECT;
                    case 3; tile_texture_rect = CHARACTER3_TIGHT_RECT;
                    case 4; tile_texture_rect = CHARACTER4_TIGHT_RECT;
                    case 5; tile_texture_rect = CHARACTER5_TIGHT_RECT;
                    case 6; tile_texture_rect = CHARACTER6_TIGHT_RECT;
                    case 7; tile_texture_rect = CHARACTER7_TIGHT_RECT;
                    case 8; tile_texture_rect = CHARACTER8_TIGHT_RECT;
                    case 9; tile_texture_rect = CHARACTER9_TIGHT_RECT;
                }

                char_rect := get_centered_character_rect_for_tile(tile_rect, it_index, 2, viewport.scale);
                draw_rect(render_lists, char_rect, tile_texture_rect, TEX_ORYX_TINY_DUNGEON_FONT, color);
            }
        }
    }

    effects_update_and_render(*level.effects, dtime, viewport, render_lists);

    return transition;
}

#scope_file

generate_onetime_hint_effects :: (effects: *Effects, hints: [] Board_Check_Hint, level_drawing_offset: IVector2) -> total_duration: f32 {
    FX_DURATION        :: 0.25;
    FX_DELAY_INCREMENT :: 0.3;

    FX_TEX_CLUE         :: TEX_FX;
    FX_ANIM_FRAMES_CLUE :: Effect_Frame.[
            .{ rect = FX_CLUE_ANIM_RECT0, color = .{ 1.0, 0.5, 0.5, 1.0 } },
            .{ rect = FX_CLUE_ANIM_RECT1, color = .{ 1.0, 0.5, 0.5, 1.0 } },
            .{ rect = FX_CLUE_ANIM_RECT2, color = .{ 1.0, 0.5, 0.5, 1.0 } },
    ];

    FX_TEX_DEAD_END         :: TEX_FX;
    FX_ANIM_FRAMES_DEAD_END :: Effect_Frame.[
            .{ rect = FX_DEAD_END_ANIM_RECT0, color = .{ 1.0, 0.5, 0.5, 1.0 } },
            .{ rect = FX_DEAD_END_ANIM_RECT1, color = .{ 1.0, 0.5, 0.5, 1.0 } },
            .{ rect = FX_DEAD_END_ANIM_RECT0, color = .{ 1.0, 0.5, 0.5, 1.0 } },
    ];

    FX_TEX_POOL         :: TEX_FX;
    FX_ANIM_FRAMES_POOL :: Effect_Frame.[
            .{ rect = FX_POOL_ANIM_RECT0, color = .{ 1.0, 0.5, 0.5, 1.0 } },
            .{ rect = FX_POOL_ANIM_RECT1, color = .{ 1.0, 0.5, 0.5, 1.0 } },
            .{ rect = FX_POOL_ANIM_RECT0, color = .{ 1.0, 0.5, 0.5, 1.0 } },
    ];

    FX_TEX_CONNECTIVITY         :: TEX_FX;
    FX_ANIM_FRAMES_CONNECTIVITY :: Effect_Frame.[
            .{ rect = FX_CONNECTIVITY_ANIM_RECT0, color = .{ 1.0, 1.0, 0.5, 1.0 } },
            .{ rect = FX_CONNECTIVITY_ANIM_RECT1, color = .{ 1.0, 1.0, 0.5, 1.0 } },
            .{ rect = FX_CONNECTIVITY_ANIM_RECT0, color = .{ 1.0, 1.0, 0.5, 1.0 } },
    ];


    has_clue     := false;
    has_dead_end := false;
    has_pool     := false;
    for hints {
        if it.type == {
            case .CLUE;     has_clue = true;
            case .DEAD_END; has_dead_end = true;
            case .POOL;     has_pool = true;
        }
    }

    delay_dead_ends    := 0.0;
    delay_pools        := 0.0;
    delay_connectivity := 0.0;

    if has_clue {
        delay_dead_ends    += FX_DELAY_INCREMENT;
        delay_pools        += FX_DELAY_INCREMENT;
        delay_connectivity += FX_DELAY_INCREMENT;
    }

    if has_dead_end {
        delay_pools        += FX_DELAY_INCREMENT;
        delay_connectivity += FX_DELAY_INCREMENT;
    }

    if has_pool {
        delay_connectivity += FX_DELAY_INCREMENT;
    }

    for hints {
        r := make_tile_rect(
            level_drawing_offset.x + it.position.x,
            level_drawing_offset.y + it.position.y,
            TINY_DUNGEON_TILE_SIZE,
        );

        frames: [] Effect_Frame;
        texture: string;
        delay: f32;

        if it.type == {
            case .CLUE; {
                texture = FX_TEX_CLUE;
                frames  = FX_ANIM_FRAMES_CLUE;
                delay   = 0.0;
            }
            case .DEAD_END; {
                texture = FX_TEX_DEAD_END;
                frames  = FX_ANIM_FRAMES_DEAD_END;
                delay   = delay_dead_ends;
            }
            case .POOL; {
                OFFSET :: #run 0.5 * ivector_to_vector(TINY_DUNGEON_TILE_SIZE);
                r += OFFSET;

                texture = FX_TEX_POOL;
                frames  = FX_ANIM_FRAMES_POOL;
                delay   = delay_pools;
            }
            case .CONNECTIVITY; {
                texture = FX_TEX_CONNECTIVITY;
                frames  = FX_ANIM_FRAMES_CONNECTIVITY;
                delay   = delay_connectivity;
            }
        }

        effects_add(effects, .{
            rect         = r,
            texture_name = texture,
            frames       = frames,
            duration     = FX_DURATION,

            delay = delay,
        });
    }

    return delay_connectivity + FX_DURATION;
}

generate_continuous_hint_effects :: (effects: *Effects, hints: [] Board_Check_Hint, level_drawing_offset: IVector2, initial_delay := 0.0) {
    FX_DELAY_INCREMENT :: 0.00;

    FX_DURATION     :: 1.0;
    FX_REPEAT_DELAY :: 0.0;

    FX_TEX_DEAD_END         :: TEX_FX;
    FX_ANIM_FRAMES_DEAD_END :: Effect_Frame.[
            .{ rect = FX_DEAD_END_ANIM_RECT0, color = .{ 1.0, 0.5, 0.5, 0.2 } },
            .{ rect = FX_DEAD_END_ANIM_RECT1, color = .{ 1.0, 0.5, 0.5, 0.2 } },
    ];

    FX_TEX_POOL         :: TEX_FX;
    FX_ANIM_FRAMES_POOL :: Effect_Frame.[
            .{ rect = FX_POOL_ANIM_RECT0, color = .{ 1.0, 0.5, 0.5, 0.2 } },
            .{ rect = FX_POOL_ANIM_RECT1, color = .{ 1.0, 0.5, 0.5, 0.2 } },
    ];

    FX_TEX_CONNECTIVITY         :: TEX_FX;
    FX_ANIM_FRAMES_CONNECTIVITY :: Effect_Frame.[
            .{ rect = FX_CONNECTIVITY_ANIM_RECT0, color = .{ 1.0, 1.0, 0.5, 0.2 } },
            .{ rect = FX_CONNECTIVITY_ANIM_RECT1, color = .{ 1.0, 1.0, 0.5, 0.2 } },
    ];

    delay := initial_delay;

    for hints {
        r := make_tile_rect(
            level_drawing_offset.x + it.position.x,
            level_drawing_offset.y + it.position.y,
            TINY_DUNGEON_TILE_SIZE,
        );

        if it.type == {
            case .DEAD_END; {
                effects_add(effects, .{
                    rect         = r,
                    texture_name = FX_TEX_DEAD_END,
                    frames       = FX_ANIM_FRAMES_DEAD_END,
                    duration     = FX_DURATION,

                    delay        = delay,
                    repeat       = true,
                    repeat_delay = FX_REPEAT_DELAY,
                });
            }
            case .POOL; {
                OFFSET :: #run 0.5 * ivector_to_vector(TINY_DUNGEON_TILE_SIZE);
                r += OFFSET;

                effects_add(effects, .{
                    rect         = r,
                    texture_name = FX_TEX_POOL,
                    frames       = FX_ANIM_FRAMES_POOL,
                    duration     = FX_DURATION,

                    delay        = delay,
                    repeat       = true,
                    repeat_delay = FX_REPEAT_DELAY,
                });
            }
            case .CONNECTIVITY; {
                effects_add(effects, .{
                    rect         = r,
                    texture_name = FX_TEX_CONNECTIVITY,
                    frames       = FX_ANIM_FRAMES_CONNECTIVITY,
                    duration     = FX_DURATION,

                    delay        = delay,
                    repeat       = true,
                    repeat_delay = FX_REPEAT_DELAY,
                });
            }
        }

        delay += FX_DELAY_INCREMENT;
    }
}

unsolve_board_generating_undo_events :: (board: *Board, undo_buffer: *[..] Undo_Event) -> bool {
    modified := false;

    for y: 0..board.ysize - 1 {
        for x: 0..board.xsize - 1 {
            tile := board_get_pointer(board, x, y);
            if tile.* & .READ_ONLY {
                continue;
            }

            if tile.* & .MARKED_WALL {
                flags := ifx modified then Undo_Flags.THROUGH else .NONE;
                tile.* &= ~.MARKED_WALL;

                array_add(undo_buffer, .{ position = .{ x, y }, flags = flags | .REMOVED_WALL });
                modified = true;
            }

            if tile.* & (.MARKED_EMPTY | .MARKED_TREASURE_ROOM) {
                flags := ifx modified then Undo_Flags.THROUGH else .NONE;
                tile.* &= ~.MARKED_EMPTY;
                tile.* &= ~.MARKED_TREASURE_ROOM;

                array_add(undo_buffer, .{ position = .{ x, y }, flags = flags | .REMOVED_EMPTY });
                modified = true;
            }
        }
    }

    return modified;
}

get_centered_character_rect_for_tile :: (tile_rect: Rect, character_index: s64, character_count: s64, scale: f32) -> Rect {
    character_size := ivector_to_vector(TINY_DUNGEON_FONT_REGULAR_CHARACTER_SIZE) * scale;
    word_size      := Vector2.{ character_size.x * character_count + character_count - 1, character_size.y };

    // The regular character in the font is is 5x5 pixels, and we scale it up by scale.
    // We are fitting that inside a tile rect already scaled by scale.
    tile_min := rect_min(tile_rect);
    tile_max := rect_max(tile_rect);

    tile_size := tile_max - tile_min;

    assert(tile_size.x > word_size.x && tile_size.y > word_size.y);

    offset := 0.5 * (tile_size - word_size);
    offset.x = floor(offset.x);
    offset.y = floor(offset.y);

    word_rect := Rect.{ tile_min.x + offset.x, tile_min.y + offset.y, tile_size.x - 2 * offset.x, tile_size.y - 2 * offset.y };

    char_rect := Rect.{ word_rect.x, word_rect.y, scale * TINY_DUNGEON_FONT_REGULAR_CHARACTER_SIZE.x, scale * TINY_DUNGEON_FONT_REGULAR_CHARACTER_SIZE.y };
    char_rect += cast(f32, character_index) * scale * Vector2.{ cast(f32, TINY_DUNGEON_FONT_TILE_SIZE.x), 0 };

    return char_rect;
}

bresenham_line :: (_x0: s32, _y0: s32, _x1: s32, _y1: s32) -> [..] IVector2 /* Temporary_Storage */ {
    points: [..] IVector2;
    points.allocator = temp;

    length_x := abs(_x0 - _x1);
    length_y := abs(_y0 - _y1);

    if length_x < length_y {
        array_reserve(*points, length_x);

        if _y0 > _y1 {
            _x0, _x1 = _x1, _x0;
            _y0, _y1 = _y1, _y0;
        }

        x0 := cast(f32, _x0);
        x1 := cast(f32, _x1);
        y0 := cast(f32, _y0);
        y1 := cast(f32, _y1);

        for _y: _y0.._y1 {
            y := cast(f32, _y);

            t := ifx _y1 - _y0 == 0 then 0.0 else (y - y0) / (y1 - y0);
            x := x0 + t * (x1 - x0);

            array_add(*points, IVector2.{ cast(s32, round(x)), _y });
        }
    } else {
        array_reserve(*points, length_y);

        if _x0 > _x1 {
            _x0, _x1 = _x1, _x0;
            _y0, _y1 = _y1, _y0;
        }

        x0 := cast(f32, _x0);
        x1 := cast(f32, _x1);
        y0 := cast(f32, _y0);
        y1 := cast(f32, _y1);

        for _x: _x0.._x1 {
            x := cast(f32, _x);

            t := ifx _x1 - _x0 == 0 then 0.0 else (x - x0) / (x1 - x0);
            y := y0 + t * (y1 - y0);

            array_add(*points, IVector2.{ _x, cast(s32, round(y)) });
        }
    }

    return points;
}
