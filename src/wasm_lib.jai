f32 :: float32;
f64 :: float64;

#import "Basic";

String :: #import "String";
Game   :: #import,file "game/game.jai";

// This entire DLL has temporary storage in a global variable, so one wasm instance can only service
// one game. This is fine.
wasm_temporary_storage_data: [TEMPORARY_STORAGE_SIZE] u8 #align 64;
wasm_temporary_storage: Temporary_Storage;

// Because in the browser the assets will be downloaded asynchronously, our platform.read_file is
// in a bit of a pinch, because it has to block until the operation is complete, but there is no way
// to do that besides busy looping? However, we can luckily pre-download the assets and poke them
// into wasm memory, so that read_file calls accessing assets can be redirected to use a cache on
// the browser side.
//
// TODO(jt): @Cleanup For all the filenames, we have to call two functions (one for pointer, one for
// count), because I have no idea how else to return an already allocated array back to javascript.

#program_export
diagrams_get_texture_filename_data :: (index: s64) -> *u8 #c_call {
    push_context {
        entry := *Game.texture_catalog[index];
        return Game.Asset_File_Name.as_string(entry.filename).data;
    }
}

#program_export
diagrams_get_texture_filename_count :: (index: s64) -> s64 #c_call {
    push_context {
        entry := *Game.texture_catalog[index];
        return Game.Asset_File_Name.as_string(entry.filename).count;
    }
}

#program_export
diagrams_get_texture_count :: () -> s64 #c_call {
    return Game.texture_catalog_count;
}

#program_export
diagrams_get_sfx_filename_data :: (index: s64) -> *u8 #c_call {
    push_context {
        entry := *Game.sfx_catalog[index];
        return Game.Asset_File_Name.as_string(entry.filename).data;
    }
}

#program_export
diagrams_get_sfx_filename_count :: (index: s64) -> s64 #c_call {
    push_context {
        entry := *Game.sfx_catalog[index];
        return Game.Asset_File_Name.as_string(entry.filename).count;
    }
}

#program_export
diagrams_get_sfx_count :: () -> s64 #c_call {
    return Game.sfx_catalog_count;
}

#program_export
diagrams_get_music_filename_data :: (index: s64) -> *u8 #c_call {
    push_context {
        entry := *Game.music_catalog[index];
        return Game.Asset_File_Name.as_string(entry.filename).data;
    }
}

#program_export
diagrams_get_music_filename_count :: (index: s64) -> s64 #c_call {
    push_context {
        entry := *Game.music_catalog[index];
        return Game.Asset_File_Name.as_string(entry.filename).count;
    }
}

#program_export
diagrams_get_music_count :: () -> s64 #c_call {
    return Game.music_catalog_count;
}

//
// Game
//

#program_export
diagrams_game_alloc :: () -> *void #c_call {
    push_context {
        return New(Game.Game);
    }
}

#program_export
diagrams_game_get_puzzle_count :: (game: *Game.Game) -> s64 #c_call {
    return game.overworld.level_entrances.count;
}

#program_export
diagrams_game_get_puzzle_filename_data :: (game: *Game.Game, index: s64) -> *u8 #c_call {
    return game.overworld.level_entrances[index].level.data;
}

#program_export
diagrams_game_get_puzzle_filename_count :: (game: *Game.Game, index: s64) -> s64 #c_call {
    return game.overworld.level_entrances[index].level.count;
}

#program_export
diagrams_game_init :: (game: *Game.Game, platform: *Game.Platform) #c_call {
    // Because this is essentially a DLL, it doesn't have an automatically initialized
    // temporary_storage. We initialize it here for the entire wasm instance. In theory, we could
    // move it out to its own function, so that there could be multiple games per instance, but for
    // now it is here.
    set_initial_data(*wasm_temporary_storage, wasm_temporary_storage_data.count, wasm_temporary_storage_data.data);

    push_context {
        context.temporary_storage = *wasm_temporary_storage;
        Game.game_init(game, platform);
    }
}

#program_export
diagrams_game_update_and_render :: (game: *Game.Game, platform: *Game.Platform, _input: *Game.Input, render_lists: *Game.Render_Lists) -> bool #c_call {
    input := _input.*;

    push_context {
        context.temporary_storage = *wasm_temporary_storage;

        // The actual free is a no-op, because the allocator is temp, but we need the array to think
        // that it has nothing allocated, because we are about to hose temporary storage.
        array_reset(*render_lists.rects);

        // We only ever reset temporary storage here, so whatever we allocate into
        // render_lists, javascript has access to until it calls us again.
        reset_temporary_storage();

        return Game.game_update_and_render(game, platform, input, render_lists);
    }
}

//
// Platform
//

#program_export
diagrams_platform_alloc :: () -> *void #c_call {
    wasm_platform_get_file_size :: (path_count: s64, path_data: *u8) -> s64  #foreign;
    wasm_platform_read_file     :: (path_count: s64, path_data: *u8, result_count: s64, result_data: *u8) -> s64 #foreign;
    wasm_platform_write_file    :: (path_count: s64, path_data: *u8, data_count: s64, data_data: *u8) -> bool #foreign;
    wasm_platform_delete_file   :: (path_count: s64, path_data: *u8) -> bool #foreign;
    wasm_platform_read_asset    :: (path_count: s64, path_data: *u8, result_data_pointer: **u8) -> s64 #foreign;

    wasm_platform_load_audio              :: (audio_name_count: s64, audio_name_data: *u8, data_count: s64, data_data: *u8) -> bool #foreign;
    wasm_platform_play_audio_stream       :: (stream_id: s64, audio_name_count: s64, audio_name_data: *u8, volume: f32, repeating: bool) #foreign;
    wasm_platform_stop_audio_stream       :: (stream_id: s64) #foreign;
    wasm_platform_set_audio_stream_volume :: (stream_id: s64, volume: f32) #foreign;
    wasm_platform_is_audio_stream_playing :: (stream_id: s64) -> bool #foreign;

    read_file :: (path: string) -> success: bool, result: string {
        // IMPORTANT(jt): If we start passing the context allocator here, the asset branch of this
        // function is going to ignore that, which could be confusing for the caller. It really
        // doesn't matter for temp, but it would matter if the context allocator had some debugging
        // facilities.
        //
        // Asset files go through their own path, because javascript pre-populated them into the WASM
        // memory, so they are already allocated.
        if is_asset_path(path) {
            data: *u8;
            count := wasm_platform_read_asset(path.count, path.data, *data);
            if count <= 0 {
                return false, "";
            }

            return true, .{ count, data };
        } else {
            count := wasm_platform_get_file_size(path.count, path.data);
            if count <= 0 {
                return false, "";
            }

            data := alloc(count);
            if wasm_platform_read_file(path.count, path.data, count, data) <= 0 {
                free(data);
                return false, ""; // This should not happen!
            }

            return true, .{ count, data };
        }
    }

    write_file :: (path: string, data: string) -> bool {
        return wasm_platform_write_file(path.count, path.data, data.count, data.data);
    }

    delete_file :: (path: string) -> bool {
        return wasm_platform_delete_file(path.count, path.data);
    }

    file_exists :: (path: string) -> bool {
        assert(!is_asset_path(path));
        size := wasm_platform_get_file_size(path.count, path.data);

        return size > 0;
    }

    load_audio :: (audio_name: string, data: [] u8) -> success: bool {
        return wasm_platform_load_audio(audio_name.count, audio_name.data, data.count, data.data);
    }

    play_audio_stream :: (stream_id: s64, audio_name: string, volume: f32, repeating: bool) {
        wasm_platform_play_audio_stream(stream_id, audio_name.count, audio_name.data, volume, repeating);
    }

    stop_audio_stream :: (stream_id: s64) {
        wasm_platform_stop_audio_stream(stream_id);
    }

    set_audio_stream_volume :: (stream_id: s64, volume: f32) {
        wasm_platform_set_audio_stream_volume(stream_id, volume);
    }

    is_audio_stream_playing :: (stream_id: s64) -> bool {
        return wasm_platform_is_audio_stream_playing(stream_id);
    }

    push_context {
        platform := New(Game.Platform);

        platform.read_file   = read_file;
        platform.write_file  = write_file;
        platform.delete_file = delete_file;
        platform.file_exists = file_exists;

        platform.load_audio              = load_audio;
        platform.play_audio_stream       = play_audio_stream;
        platform.stop_audio_stream       = stop_audio_stream;
        platform.set_audio_stream_volume = set_audio_stream_volume;
        platform.is_audio_stream_playing = is_audio_stream_playing;

        return platform;
    }
}

//
// Input
//

MAX_INPUT_KEY_EVENTS :: 32;

#program_export
diagrams_input_alloc :: () -> *void #c_call {
    push_context {
        input := New(Game.Input);

        // Pre-allocate buffer for key events up to MAX_INPUT_KEY_EVENTS. This buffer will be
        // re-used every frame.
        input.key_events = NewArray(MAX_INPUT_KEY_EVENTS, Game.Key_Event);

        return input;
    }
}

// TODO(jt): @Correctness Unlike Apollo_Time, f64 may run out of precision, if the app runs for long
// enough. For f32, we only have a couple of seconds of precision... how much do we have for f64?
#program_export
diagrams_input_set_time :: (input: *Game.Input, time: f64) #c_call {
    push_context {
        new_time := to_apollo(time);

        // Initial input.time is zero, which is also true for window.performance.now() in browsers.
        input.dtime = new_time - input.time;
        input.time = new_time;
    }
}

#program_export
diagrams_input_set_window_size :: (input: *Game.Input, width: s32, height: s32) #c_call {
    input.window_size.x = width;
    input.window_size.y = height;
}

#program_export
diagrams_input_set_mouse_position :: (input: *Game.Input, position_x: f32, position_y: f32) #c_call {
    input.mouse_position.x = position_x;
    input.mouse_position.y = position_y;
}

#program_export
diagrams_input_clear_key_events :: (input: *Game.Input) #c_call {
    input.key_events.count = 0;
}

#program_export
diagrams_input_push_key_event :: (input: *Game.Input, key_code: s32, key_pressed: s32) #c_call {
    if input.key_events.count < MAX_INPUT_KEY_EVENTS {
        index := input.key_events.count;

        input.key_events.count += 1;
        input.key_events[index] = .{ cast(Game.Key_Code, key_code), cast(u32, key_pressed) };
    }
}

//
// Render_Lists
//

#program_export
diagrams_render_lists_alloc :: () -> *void #c_call {
    push_context {
        render_lists := New(Game.Render_Lists);
        render_lists.rects.allocator = temp;

        return render_lists;
    }
}

#program_export
diagrams_render_lists_get_rect_count :: (render_lists: *Game.Render_Lists) -> s64 #c_call {
    return render_lists.rects.count;
}

#program_export
diagrams_render_lists_rects_get_rect_x :: (render_lists: *Game.Render_Lists, index: s64) -> f32 #c_call {
    return render_lists.rects[index].rect.x;
}

#program_export
diagrams_render_lists_rects_get_rect_y :: (render_lists: *Game.Render_Lists, index: s64) -> f32 #c_call {
    return render_lists.rects[index].rect.y;
}

#program_export
diagrams_render_lists_rects_get_rect_w :: (render_lists: *Game.Render_Lists, index: s64) -> f32 #c_call {
    return render_lists.rects[index].rect.w;
}

#program_export
diagrams_render_lists_rects_get_rect_h :: (render_lists: *Game.Render_Lists, index: s64) -> f32 #c_call {
    return render_lists.rects[index].rect.h;
}

#program_export
diagrams_render_lists_rects_get_texture_rect_x :: (render_lists: *Game.Render_Lists, index: s64) -> f32 #c_call {
    return render_lists.rects[index].texture_rect.x;
}

#program_export
diagrams_render_lists_rects_get_texture_rect_y :: (render_lists: *Game.Render_Lists, index: s64) -> f32 #c_call {
    return render_lists.rects[index].texture_rect.y;
}

#program_export
diagrams_render_lists_rects_get_texture_rect_w :: (render_lists: *Game.Render_Lists, index: s64) -> f32 #c_call {
    return render_lists.rects[index].texture_rect.w;
}

#program_export
diagrams_render_lists_rects_get_texture_rect_h :: (render_lists: *Game.Render_Lists, index: s64) -> f32 #c_call {
    return render_lists.rects[index].texture_rect.h;
}

#program_export
diagrams_render_lists_rects_get_texture_name_count :: (render_lists: *Game.Render_Lists, index: s64) -> s64 #c_call {
    return render_lists.rects[index].texture_name.count;
}

#program_export
diagrams_render_lists_rects_get_texture_name_data :: (render_lists: *Game.Render_Lists, index: s64) -> *u8 #c_call {
    return render_lists.rects[index].texture_name.data;
}

#program_export
diagrams_render_lists_rects_get_color_r :: (render_lists: *Game.Render_Lists, index: s64) -> f32 #c_call {
    return render_lists.rects[index].color.x;
}

#program_export
diagrams_render_lists_rects_get_color_g :: (render_lists: *Game.Render_Lists, index: s64) -> f32 #c_call {
    return render_lists.rects[index].color.y;
}

#program_export
diagrams_render_lists_rects_get_color_b :: (render_lists: *Game.Render_Lists, index: s64) -> f32 #c_call {
    return render_lists.rects[index].color.z;
}

#program_export
diagrams_render_lists_rects_get_color_a :: (render_lists: *Game.Render_Lists, index: s64) -> f32 #c_call {
    return render_lists.rects[index].color.w;
}

//
// Direct interface to the allocator.
//

#program_export
diagrams_alloc :: (size: s64) -> *void #c_call {
    push_context {
        return alloc(size);
    }
}

#program_export
diagrams_free :: (memory: *void) #c_call {
    push_context {
        free(memory);
    }
}

#scope_file

is_asset_path :: (path: string) -> bool {
    return String.starts_with(path, "./data") || String.starts_with(path, "data");
}
