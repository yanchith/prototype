DEVELOPER :: #exists(__BUILD_OPTIONS_DEVELOPER_BUILD) && __BUILD_OPTIONS_DEVELOPER_BUILD;

// TODO(jt): Consider passing these as flags to the metaprogram too.
SOLVER_TESTS_VERBOSE :: false;
SOLVER_VERBOSE       :: false;
SOLVER_VERY_VERBOSE  :: false;

// Only ever enable this locally
ENABLE_LEVELS_FROM_DUNGEONS_AND_DIAGRAMS :: false;

MEMORY_DEBUGGER :: false;

TARGET_FRAME_RATE :: 30;
TARGET_FRAME_TIME :: 1.0 / TARGET_FRAME_RATE;

f32 :: float32;
f64 :: float64;

#import "Basic"()(MEMORY_DEBUGGER = MEMORY_DEBUGGER);
#import "Hash_Table";

String         :: #import "String";
Math           :: #import "Math";
Thread         :: #import "Thread";
File           :: #import "File";
File_Utilities :: #import "File_Utilities";
Window         :: #import "Window_Creation";
Input          :: #import "Input";
Simp           :: #import "Simp";
Sound          :: #import "Sound_Player";
Game           :: #import,file "game/game.jai"(
    DEVELOPER = DEVELOPER,
    SOLVER_TESTS_VERBOSE = SOLVER_TESTS_VERBOSE,
    SOLVER_VERBOSE       = SOLVER_VERBOSE,
    SOLVER_VERY_VERBOSE  = SOLVER_VERY_VERBOSE,
    ENABLE_LEVELS_FROM_DUNGEONS_AND_DIAGRAMS = ENABLE_LEVELS_FROM_DUNGEONS_AND_DIAGRAMS,
);

Vector2 :: Math.Vector2;
floor   :: Math.floor;

game_init              :: Game.game_init;
game_update_and_render :: Game.game_update_and_render;

textures: Table(string, Simp.Texture);
texture_missing: Simp.Texture;
texture_missing_initialized: bool;

audio_data: Table(string, Sound.Sound_Data);

main :: () {
    time_program_start := current_time_monotonic();

    new_context := context;
    logger_data := Diagrams_Context_Logger_Data.{ time_program_start };

    new_context.logger = diagrams_context_logger;
    new_context.logger_data = *logger_data;

    push_context new_context {
        #if OS == .MACOS {
            System :: #import "System";

            see_audio    := File_Utilities.is_directory("data/audio");
            see_puzzles  := File_Utilities.is_directory("data/puzzles");
            see_textures := File_Utilities.is_directory("data/textures");

            if !(see_audio && see_puzzles && see_textures) {
                exe_file := System.get_path_of_running_executable();
                exe_dir  := String.path_strip_filename(exe_file);
                log("We are on macOS and we don't see our data. Attempting to set working directory to the executable path: %", exe_dir);

                set_working_directory(exe_dir);
            }

            log("Working directory is %", get_working_directory());
        }

        time_last_frame_start := time_program_start;

        window_width:  s32 = 1600;
        window_height: s32 = 900;
        window := Window.create_window(window_width, window_height, "diagrams");

        Simp.set_render_target(window, .LEFT_HANDED);

        Sound.sound_player_init(.{});

        platform: Game.Platform;

        //
        // File API
        //

        // TODO(jt): Add explicit arena to read the file into (unless we always want it to be
        // temp?). Currently this just calls alloc (both on Windows and Unix), which in turn calls
        // context.allocator. Maybe we should embrace using context for this?
        platform.read_file = (path: string) -> success: bool, result: string {
            // get_absolute_path allocates in temp at the moment, but if that changes, we should force it to allocate in temp.
            absolute_path := File.get_absolute_path(path);
            // NOTE(jt): In recent release notes, Jon said success should be first, so I guess all JAI
            // modules will eventually migrate to that?
            data, success := File.read_entire_file(absolute_path);

            return success, data;
        };

        platform.write_file = (path: string, data: string) -> bool {
            return File.write_entire_file(path, data);
        };

        platform.delete_file = (path: string) -> bool {
            return File.file_delete(path);
        };

        #if DEVELOPER {
            platform.copy_file = (source_path: string, dest_path: string) -> success: bool {
                return File_Utilities.copy_file(source_path, dest_path);
            }
        }

        platform.file_exists = (path: string) -> bool {
            return File_Utilities.file_exists(path);
        };

        #if DEVELOPER {
            platform.file_is_directory = (path: string) -> bool {
                return File_Utilities.is_directory(path);
            };

            platform.make_directory_if_it_does_not_exist = (path: string, recursive: bool) -> success: bool {
                return File.make_directory_if_it_does_not_exist(path, recursive);
            }

            platform.delete_directory = (path: string) -> bool {
                return File.file_delete(path);
            };
        }

        //
        // Audio API
        //

        platform.load_audio = (audio_name: string, _data: [] u8) -> success: bool {
            if table_contains(*audio_data, audio_name) {
                log_error("Audio % is already loaded and will be overwritten", audio_name);
            }

            // Copy to our own memory so that the game doesn't have to keep it alive.
            //
            // TODO(jt): Sound system arena?
            data := array_copy(_data);

            sound_data := Sound.load_audio_data(audio_name, cast(string, data));
            if !sound_data.loaded {
                log_error("Failed to load audio data for %", audio_name);
                return false;
            }

            log("Loaded audio %", audio_name);

            table_set(*audio_data, audio_name, sound_data);

            return true;
        };
        platform.play_audio_stream = (stream_id: s64, audio_name: string, volume: f32, repeating: bool) {
            sound_data := table_find_pointer(*audio_data, audio_name);
            if sound_data {
                log("Playing audio stream % (%)", stream_id, audio_name);
                // TODO(jt): We can have sound categories so that we can control volume separately.
                stream := Sound.make_stream(sound_data);
                stream.manager_id = 0;
                stream.entity_id = stream_id;
                stream.user_volume_scale = volume;

                if repeating {
                    Sound.set_repeating(stream, repeating);
                }

                Sound.start_playing(stream);
            } else {
                log_error("Can't play audio stream (%). Data not loaded.", audio_name);
            }
        };
        platform.stop_audio_stream = (stream_id: s64) {
            // TODO(jt): @Speed @Memory Are we sure there isn't a way in Sound_Player to just reset
            // the cursor? Although, maybe releasing memory is good?
            log("Stopping (and releasing) audio stream %", stream_id);
            Sound.stop_stream_abruptly(stream_id);
        }
        platform.set_audio_stream_volume = (stream_id: s64, volume: f32) {
            stream := Sound.find(stream_id, 0);
            if stream {
                Thread.lock(*Sound.sound_mutex);
                defer Thread.unlock(*Sound.sound_mutex);
                stream.user_volume_scale = volume;
            }
        };
        platform.is_audio_stream_playing = (stream_id: s64) -> bool {
            stream := Sound.find(stream_id, 0);
            if stream {
                if stream.user_flags & .REPEATING {
                    // Stream will never self-destruct
                    return true;
                }

                if stream.internal_flags & .FADING_OUT {
                    // Stream is about to self-destruct (note that we will likely not receive this,
                    // unless we ran Sound.pre_entity_update for the this frame already).
                    return false;
                }

                if stream.play_cursor >= cast(f64, stream.repeat_end_position) {
                    // Stream is about to self-destruct, although Sound_Player doesn't know it
                    // yet. This is the same check that Sound_Player does internally to detect that
                    // track has ended before it sets .FADING_OUT.
                    return false;
                }

                return true;
            }

            return false;
        }

        input: Game.Input;
        input.window_size = .{ window_width, window_height };

        game: Game.Game;
        game_init(*game, platform);

        should_run := true;
        while should_run {
            reset_temporary_storage();

            time_frame_start := current_time_monotonic();
            time_since_program_start := time_frame_start - time_program_start;
            dtime := time_frame_start - time_last_frame_start;
            time_last_frame_start = time_frame_start;

            input.time  = time_since_program_start;
            input.dtime = dtime;

            input_key_events: [..] Game.Key_Event;
            input_key_events.allocator = temp;

            render_lists: Game.Render_Lists;
            render_lists.rects.allocator = temp;

            Input.update_window_events();
            for Input.get_window_resizes() {
                Simp.update_window(it.window);

                if it.window == window {
                    input.window_size = .{ it.width, it.height };
                }
            }

            for Input.events_this_frame {
                if it.type == {
                    case .QUIT; {
                        should_run = false;
                    }

                    case .KEYBOARD; {
                        #if OS == .WINDOWS {
                            if it.alt_pressed && it.key_code == .F4 {
                                should_run = false;
                            }
                        }

                        if it.key_code == {
                            case .BACKSPACE;           array_add(*input_key_events, .{ .BACKSPACE, it.key_pressed });
                            case .ESCAPE;              array_add(*input_key_events, .{ .ESCAPE, it.key_pressed });
                            case .SPACEBAR;            array_add(*input_key_events, .{ .SPACEBAR, it.key_pressed });
                            case #char "E";            array_add(*input_key_events, .{ .E, it.key_pressed });
                            case #char "M";            array_add(*input_key_events, .{ .M, it.key_pressed });
                            case #char "Q";            array_add(*input_key_events, .{ .Q, it.key_pressed });
                            case #char "R";            array_add(*input_key_events, .{ .R, it.key_pressed });
                            case #char "S";            array_add(*input_key_events, .{ .S, it.key_pressed });
                            case #char "X";            array_add(*input_key_events, .{ .X, it.key_pressed });
                            case #char "V";            array_add(*input_key_events, .{ .V, it.key_pressed });
                            case #char "Z";            array_add(*input_key_events, .{ .Z, it.key_pressed });
                            case .ALT;                 array_add(*input_key_events, .{ .ALT, it.key_pressed });
                            case .CTRL;                array_add(*input_key_events, .{ .CTRL, it.key_pressed });
                            case .SHIFT;               array_add(*input_key_events, .{ .SHIFT, it.key_pressed });
                            case .CMD;                 array_add(*input_key_events, .{ .CMD, it.key_pressed });
                            case .MOUSE_BUTTON_LEFT;   array_add(*input_key_events, .{ .MOUSE_BUTTON_LEFT, it.key_pressed });
                            case .MOUSE_BUTTON_RIGHT;  array_add(*input_key_events, .{ .MOUSE_BUTTON_RIGHT, it.key_pressed });
                            case .MOUSE_BUTTON_MIDDLE; array_add(*input_key_events, .{ .MOUSE_BUTTON_MIDDLE, it.key_pressed });
                        }
                    }
                }
            }

            mouse_x, mouse_y, success := Window.get_mouse_pointer_position();
            if success {
                input.mouse_position = .{ cast(f32, mouse_x), cast(f32, mouse_y) };
            }

            input.key_events = input_key_events;

            // TODO(jt): @Cleanup @Hack We run Sound.pre_entity_update twice! (It is being run the
            // second time in Sound.update). We do this, because we chain music tracks (intro
            // segments into looping segments), and if we update the audio system only after the
            // game has finished its update, we will introduce one frame of latency after the intro
            // track ends before we schedule the looping track (because the game decides to schedule
            // the new track based on members present on the Sound_Stream struct).
            //
            // I honestly don't exactly know why we can't just run Sound.post_entity_update after
            // the game has issued changes, but it just doesn't seem to work - no audio plays at
            // all. Additionally, if we do the entire Sound.update before the game update, we once
            // again introduce the frame hitch. Honestly, maybe we shouldn't be using Sound_Player?
            Sound.pre_entity_update();

            wants_quit := game_update_and_render(*game, platform, input, *render_lists);
            if wants_quit {
                should_run = false;
            }

            Sound.update(cast(f32, to_float64_seconds(dtime)));

            Simp.clear_render_target(0, 0, 0, 1);

            // TODO(jt): We are using Simp to get something to the screen quickly, but we'll definitely
            // need more control eventually. The options are all a little DIY: we'll either have to
            // generate bindings to a graphics API and use that, or we'll have to do software
            // rendering. Out of all the graphics APIs, I know WebGPU the best, and it also seems to
            // currently have the best crossplatform story (since OpenGL is dead), and it also isn't as
            // hard as Vulkan.
            for render_lists.rects {
                if it.texture_name {
                    texture := get_texture(it.texture_name);
                    w := cast(f32, texture.width);
                    h := cast(f32, texture.height);
                    rw := 1.0 / w;
                    rh := 1.0 / h;

                    Simp.set_shader_for_images(*texture);
                    Simp.immediate_quad(
                        Vector2.{ it.rect.x,             it.rect.y },
                        Vector2.{ it.rect.x,             it.rect.y + it.rect.h },
                        Vector2.{ it.rect.x + it.rect.w, it.rect.y + it.rect.h },
                        Vector2.{ it.rect.x + it.rect.w, it.rect.y },
                        it.color,
                        Vector2.{ rw * it.texture_rect.x,                       rh * it.texture_rect.y },
                        Vector2.{ rw * it.texture_rect.x,                       rh * (it.texture_rect.y + it.texture_rect.h) },
                        Vector2.{ rw * (it.texture_rect.x + it.texture_rect.w), rh * (it.texture_rect.y + it.texture_rect.h) },
                        Vector2.{ rw * (it.texture_rect.x + it.texture_rect.w), rh * it.texture_rect.y },
                    );
                } else {
                    Simp.set_shader_for_color();
                    Simp.immediate_quad(
                        Vector2.{ it.rect.x,             it.rect.y },
                        Vector2.{ it.rect.x,             it.rect.y + it.rect.h },
                        Vector2.{ it.rect.x + it.rect.w, it.rect.y + it.rect.h },
                        Vector2.{ it.rect.x + it.rect.w, it.rect.y },
                        it.color,
                    );
                }
            }

            Simp.swap_buffers(window);

            time_frame_end := current_time_monotonic();
            time_since_frame_start := to_float64_seconds(time_frame_end - time_frame_start);

            #if MEMORY_DEBUGGER {
                memory_visualizer_per_frame_update();
            }

            // TODO(jt): What is the best way of limiting fps? V-sync? I don't know man.
            if time_since_frame_start < TARGET_FRAME_TIME {
                remainder_time := (TARGET_FRAME_TIME - time_since_frame_start) * 1000.0;
                sleep_milliseconds(cast(s32, floor(remainder_time)));
            }
        }

        Sound.sound_player_shutdown();
    }
}

// TODO(jt): More often than not, texture_filename is going to be a compile-time constant (and thus in
// static memory), but maybe we should enforce this somehow? Maybe we should generate texture IDs at
// build time and use integers as texture IDs at runtime, with the mapping back to filenames being
// baked in by the metaprogram? This would break, if we ever want to do hot-reloading, though, so if
// we do want to do it, we'll need runtime discovery and file watching.
//
// TODO(jt): Preload some or all textures ahead of time?
get_texture :: (texture_filename: string) -> Simp.Texture {
    found, texture := table_find(*textures, texture_filename);
    if found {
        return texture;
    }

    texture.options.min_filter = .NEAREST;
    texture.options.mag_filter = .NEAREST;

    if Simp.texture_load_from_file(*texture, tprint("data/textures/%", texture_filename)) {
        table_add(*textures, texture_filename, texture);
        return texture;
    }

    if !texture_missing_initialized {
        bitmap: Simp.Bitmap;
        Simp.bitmap_alloc(*bitmap, 1, 1, .RGBA8);

        bitmap.data[0] = 255;
        bitmap.data[1] = 0;
        bitmap.data[2] = 255;
        bitmap.data[3] = 255;

        // TODO(jt): We can't really tell the texture we want nearest sampling unless we send upstream that to Simp.
        success := Simp.texture_load_from_bitmap(*texture_missing, *bitmap);
        texture_missing_initialized = success;
    }

    return texture_missing;
}

//
// Logging
//

// A customized version of runtime_support_default_logger. This is just an experiment and maybe
// it is totally not worth it, I am just used to having somewhat structured-looking logs. It
// also looks like it is doing an awful amount of work for just logging, but maybe that's fine?
Diagrams_Context_Logger_Data :: struct {
    time_start: Apollo_Time;
}

diagrams_context_logger :: (message: string, data: *void, info: Log_Info) {
    left_pad :: (s: string, length: s64) -> string {
        builder: String_Builder;
        builder.allocator = temp;

        for s.count..length - 1 {
            append(*builder, #char " ");
        }

        append(*builder, s);

        return builder_to_string(*builder,, temp);
    }

    right_pad :: (s: string, length: s64) -> string {
        builder: String_Builder;
        builder.allocator = temp;

        append(*builder, s);

        for s.count..length - 1 {
            append(*builder, #char " ");
        }

        return builder_to_string(*builder,, temp);
    }

    if !message then return;

    logger_data := cast(*Diagrams_Context_Logger_Data, data);

    // Add time since launch. Pad to up to 4 leading digits and 6 decimal digits.
    time_start           := logger_data.time_start;
    time_now             := current_time_monotonic();
    time_since_start     := time_now - time_start;
    time_since_start_str := tprint("% ", formatFloat(to_float64_seconds(time_since_start), trailing_width = 6, zero_removal = .NO));
    time_prefix          := left_pad(time_since_start_str, 12);

    // Add log level.
    log_level_prefix := " INFO ";
    if info.common_flags & .WARNING  log_level_prefix = " WARN ";
    if info.common_flags & .ERROR    log_level_prefix = "ERROR ";

    // Add source file.
    source_prefix: string;
    {
        LENGTH :: 30;
        MODULES :: "modules/";

        path := info.location.fully_pathed_filename;
        index := String.find_index_from_left(path, MODULES);
        if index != -1 {
            source_prefix = advance(path, index + MODULES.count);
        } else {
            _, _, _, basename_with_extension := String.path_decomp(path);
            source_prefix = basename_with_extension;
        }

        source_prefix = right_pad(source_prefix, LENGTH + 1);
    }

    to_standard_error := (info.common_flags & .ERROR) != 0;

    // TODO(jt): If we ever stop using most of JAI's modules, we can remove this "\n" detection and
    // just always push the additional newline.
    if message[message.count-1] != #char "\n" {
        write_strings(time_prefix, log_level_prefix, source_prefix, message, "\n", to_standard_error = to_standard_error);
    } else {
        write_strings(time_prefix, log_level_prefix, source_prefix, message, to_standard_error = to_standard_error);
    }
}
