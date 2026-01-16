/*

IMPORTANT(jt): @Design Distilled feedback from Matthew.

The game needs to know what it is. Is it an idling picross/sudoku, or is it a nonverbal teaching
game?

Alternative 1:

- Make this a game about nonverbal teaching.
- Deconstruct existing D&D mechanics even more: dead ends get their symbol, and so do pools.
- D&D from the original game emerges in only one of the areas, otherwise, the numbers go away?

Alternative 2:

- Enhance Dungeons and Diagrams with Dragonsweeper-like secret clues, e.g. a boss monster is always
  in a room of a certain shape, and double donw on procedural generation.

Alternative 3:

- Start this game as Dungeons and Diagrams, but then something happens, and the rules get glitchy.

> If you are very intent on expanding on dungeons and diagrams directly. Then it probably makes
  sense to explore options which allow you to present that part of the game somewhat differently to
  the other parts. One could imagine a presentation where you are playing dungeons and diagrams and
  the computer becomes glitched and now there is some additional copy of the game with extra rules
  that you have to discover or something. Just an example of a presentational solution to the
  problem.

---------------------------------------------------------------

This game used to be strongly influenced by dragonsweeper in the beginning, but that sort of went
away. For most new puzzle ideas, instead of letting the player observe their behavior by noticing
them in any level, the player now learns them in a nonverbal teaching sequence.

However, the Dragonsweeper influence may yet come back with second layer clues. These would be clues
that are present everywhere, even in old levels, but do give addidional hints.

To get to some new areas, the player must solve knowledge gate puzzles - usually difficult levels
with clues that have not been explicitly explained, but can be learned in a tutorial sequence
somewhere.

TODO(jt): @Design Nonverbally explained clues (Layer 1)

- [X] Traps mean a straight corridor without curves.
- [X] Mirrors seeing the same thing on both ends. (Note that mirrors are currently shelved)
- [X] Something that shapes the graph branching. Currently, there can be many paths from one tile to
      another, but maybe there's taiji-like diamond tiles that must be connected by a single path?
      This became crests.
- [ ] Corner version of traps.
- [ ] Crests connecting to the same crest? e.g. a level with just one double crest means that double crest has two paths between itself, essentially forcing a 4-crossroad in its place. A level with one single crest means the entire level is one loop.
- [ ] Reified Connectivity clues. Connectivity symbol disappears from top left corner, and instead appears on the board, possibly multiple times.
- [ ] Masking and dungeon shapes. Masks are either implicit walls, or implicit empty spaces?

TODO(jt): @Design Secret clues (Layer 2)

- [ ] Monsters/treasures with crests. Same as monsters/treasures, but crest rules apply.
- [ ] Monsters/treasures with with reified connectivity clues. Same as monsters/treasures, but connectivity rules apply.
- [ ] Dragons behave like regular monsters, but they are only present on maps with treasure, and
      must have a direct line of sight to the treasure. Given off by a subtle glimmer in the eyes if
      it has line of sight.

TODO(jt): @Design Meta puzzles (Layer 3)

- [ ] Hex grid version of the same game on the overworld!!!

TODO(jt): @Design Infinite, procedurally generated dungeon. Both one for the OG game, and one for the current game.

Puzzle deductions/ideas:

- Corridor near wall has to be at least 3-long, otherwise it is a dead end.
- 2-wide dead end is still a dead end. 2-wide corridor needs to have an exit on the other end.
- 2 monsters need to share exit if the next row is 7 (+ less pronounced variations).
- 2 monsters next to an edge one tile away from each other with a 1-constraint on that row forces the tile between the monsters to be a wall.
- Single treasure room exit + numeric constraints. TODO(jt): @Design Audit.
- Treasure room is pushed away from monsters and requires a separating wall.
- Treasure room is pushed away from 6/7/8-constraints.
- Having to space a N walls in N*2+1 tiles next to a corridor has only one valid spacing.
- Monster not on edge + 1-constraint forces two walls.
- Monster on edge + 6-costraint on that edge forces the tiles not adjacent to the monster to be walls.
- Treasure room next to monster with 1-constraint forces the monster's exit. TODO(jt): @Design Audit.

- Trap + edge/wall is an obvious forced move.
- Trap + 6-constraint is a forced move
- Trap + 1-constraint is a forced move
- Trap + treasure + ~3-constraint is a forced move (less clear version of the above)

Additional idea dump:

- Aboutness grouping: overworld introducing several fantasy locations, each being "about something"
  (usually a clue type, but hopefully not just that).

- Clues:
  - monsters
  - treasures
  - traps (straight corridor)
  - corner traps
  - mirrors
  - taiji diamonds -> these became crests
  - numbered crests -> like single crests, but the path has to have a certain length
  - statues: their neighboring 8 tiles mst be all the same across the dungeon. Statues can also
    be rotated, in which case the neighboring tiles must also be.
  - hidden count constraints in row/column (optionally unless the clue hiding them is satisfied)
  - akari lanterns... somehow
  - portals (although they can't influence how the original game is played!)
  - potions
  - legendary weapon
  - dragons: like monsters, but must see treasure (this is a flavor clue)
  - keys
  - doors
  - levers

------------------------------------------------------------------------------------------

TODO(jt): @Design Mirrors are currently shelved. They need work, or they need to be cut. These are
the disruptive things I don't like about them:

- Once one of their sides is marked empty, they create cheap pool deduction applications.
- They look like they shouldn't be passable, but they are? Similar with traps. Maybe both just need better art?
- When pointing to same type of clue on both ends, they create expectations of connecting to the
  things they point to, but those expectations don't have to come true. Conversely, if they point to
  different things, the solver knows they must not connect. This I find less offensive, but maybe
  this information is also too easily given?

Potential fixes:

Make distance count. In case of mirror chains, it is the distance between the mirror and the
terminator object.

------------------------------------------------------------------------------------------

TODO(jt): @Playtest Checklist:

First playtest:

- [X] Animated tutorial
- [X] System for one-off animated effects on the overworld (and use it to highlight things)
- [X] A single save game slot (and documentation in README how to delete it)
- [X] Save current overworld area in the save slot
- [X] Sound and music placed for all events and areas
- [X] Lost tutorial pages for secret clues (traps)
- [X] Better trap art
- [X] Transcribe all original puzzles
- [X] 16ish puzzles on vanilla mechanics
- [X] 16ish teaching puzzles with traps
- [X] 16ish testing/gating puzzles for traps
- [X] Endgame puzzles
- [X] An ending? Maybe just a knowledgegated entity containing a note
- [X] Windows and macOS build
- [X] README with controls and playtest instructions
- [X] Finalize credits

Second playtest:

- [X] Naive asset build (copy files in manifests to runtime_data when triggered by a developer command)
- [X] Options menu to delete save slot and set music/sfx volume.
- [X] Revise music to be more ambient. (use mystery music by leohpaz)
- [X] (Optional) Save level state to save file.
- [X] (Optional) Prepend teaching sequence for the base game.
- [X] (Optional) Make all clues tell, whether they are satisfied, not just numbers. Use this in teaching sequences for that particular mechanic.
- [X] (Optional) Fix mouse polling rate (get more mouse events), or do line drawing algorithm.
- [X] Replace trap observation puzzles with teaching sequence. (done to a certain degree, but maybe needs polish)
- [X] Teaching sequence for crests. (done to a certain degree, but maybe needs polish)
- [X] Revise forest area to make it more clear that the spike levels are knowledge gates, so that playtesters don't try and grind through.
- [X] More vanilla levels for the forest area.
- [X] 2-4ish crest puzzles that gate entrance to the endgame
- [X] 2-4ish combinatorial (traps + crests) puzzles that gate entrance to the endgame
- [X] 4ish crest endgame puzzles.
- [X] 4ish combinatorial (traps + crests) endgame puzzles.
- [ ] (Optional) 4ish regular crest puzzles
- [ ] (Optional) 4ish regular trap puzzles, because some of them got downgraded to vanilla.
- [ ] Other TODOs marked with @Playtest.
- [X] Send build to Draknek.
- [X] Send build to Zach Barth.
- [X] Send build to TechnicBeam
- [X] Send build to Matthew VanDevander (only do this once we have finished the knowledge gate and endgame puzzles)

- 2.1 (things learned from the Rupert playtest):

- [X] Make sure the art for the masked-out walls and empty spaces communicates more clearly.
- [X] Make the map edge a masked-out wall art-wise, so that it is the same concept.
- [X] These puzzles were difficulty spikes, and we probably need to prepare the player better:
      * the single monster + loop
      * the puzzle where the player is expected to know the treasure room shape and apply it

Later playtests:

- [ ] For puzzles with numbers, limit the size variations and communicate size in a clear way. We currently have:
      * numbered 6x6, 8x8, 9x9 and 10x10 (consider redesigning existing 9x9 to 10x10)
      * unnumbered 3x2, 3x3, 4x4, 5x3, 5x4, 6x3, 7x3, 6x6, 7x7
- [ ] Better controls (maybe just steal from Taiji)
- [ ] Would be great if we could look at previous puzzles more easily. Maybe just steal from Taiji and interact with puzzles on the overworld.
- [ ] Optional stuff from last milestone!
- [ ] Decide what to do with original levels. Move some or even all of them to bonus areas, which means we have to have our own easy levels to get started with the game.
- [ ] Playable in the browser (WASM + WebGPU)
- [ ] Graphics overhaul
- [ ] Procedurally generated levels
- [ ] Third mechanic

------------------------------------------------------------------------------------------

TODO(jt): @Stream Convert overworld art to one of the overworld packs I bought..
TODO(jt): @Stream Convert level art to one of the asset packs I bought..

TODO(jt): @Stream Animations for various tiles/entities.

TODO(jt): @Stream Level generator. Generates levels based on constraints (level size, clue types),
then rates it by solving it with the solver. Making difficulty an initial constraint is likely going
to be hard, but we can generate and solve until we find something in the correct difficulty
range. If this generate/solve process is too slow, we either do it offline (and pre-generate a
sufficient amount of levels), or we do it asynchronously in the game.

TODO(jt): @Stream Menu: sound options, credits.

TODO(jt): @Stream WASM build, so that this can be played online.

TODO(jt): @Design Consider having a dungeon version of the overworld theme for the current overworld
area - the same music, but with some different tracks.

TODO(jt): Prune unused assets from repository.

*/

#module_parameters(
    DEVELOPER := false,
    SOLVER_TESTS_VERBOSE := false,
    SOLVER_VERBOSE       := false,
    SOLVER_VERY_VERBOSE  := false,
    ENABLE_LEVELS_FROM_DUNGEONS_AND_DIAGRAMS := false
);

f32 :: float32;
f64 :: float64;

#import "Basic";
#import "Hash_Table";

String :: #import "String";
Hash   :: #import "Hash";
Math   :: #import "Math";
Random :: #import "Random";

Vector2      :: Math.Vector2;
Vector3      :: Math.Vector3;
Vector4      :: Math.Vector4;
operator+    :: Math.operator+;
operator-    :: Math.operator-;
operator*    :: Math.operator*;
operator/    :: Math.operator/;
min          :: Math.min;
max          :: Math.max;
abs          :: Math.abs;
floor        :: Math.floor;
ceil         :: Math.ceil;
Clamp        :: Math.Clamp;
fmod_cycling :: Math.fmod_cycling;

Random_State           :: Random.Random_State;
random_seed            :: Random.random_seed;
random_get             :: Random.random_get;
random_get_zero_to_one :: Random.random_get_zero_to_one;

#load "math.jai";
#load "array.jai";
#load "string.jai";
#load "board.jai";
#load "solver.jai";
#load "solver_tests.jai";
#load "platform.jai";
#load "render.jai";
#load "audio.jai";
#load "effects.jai";
#load "input.jai";
#load "gui.jai";
#load "overworld.jai";
#load "level.jai";

Scene :: enum u32 {
    OVERWORLD;
    LEVEL;
}

Game :: struct {
    initted: bool;

    input_state: Input_State;

    transition: Game_Transition;
    scene: Scene;
    overworld: Overworld;
    level: Level;

    settings: Game_Settings;

    pause_menu_active: bool;
    pause_menu_delete_save_confirm: bool;
    pause_menu_quit_game_confirm: bool;

    gui: Gui;

    audio: Audio(32);
}

// Warning! This struct is serialized to disk. If you modify this struct, make sure to modify the
// serialization code too.
Game_Settings :: struct {
    // TODO(jt): @Correctness Add magic number to detect endianness?
    VERSION :: 1;

    version: s64 = VERSION;

    music_volume: f32 = 1.0;
    sfx_volume:   f32 = 1.0;
}

Game_Transition :: struct {
    Type :: enum {
        UNINITIALIZED :: 0;
        TO_LEVEL      :: 1;
        TO_OVERWORLD  :: 2;
    }

    Data :: union {
        to_level:     To_Level_Data;
        to_overworld: To_Overworld_Data;
    }

    To_Level_Data :: struct {
        hint_flags: Hint_Flags;
        solved_on_the_overworld: bool;
    }

    To_Overworld_Data :: struct {
        solved: bool;
    }

    type: Type;
    data: Data;

    level: string;        // The level we are going from or to.
    board_state: [] Tile; // The board state of the level we are going from or to. WARNING: When going from level to overworld, this is in temporary storage!
}

game_init :: (game: *Game, platform: Platform) {
    game.scene = .OVERWORLD;

    gui_init(*game.gui);

    if texture_catalog_count {
        log("Texture catalog:",);
        for 0..texture_catalog_count - 1 {
            log("[%]: %", it, Asset_File_Name.as_string(texture_catalog[it].filename));
        }
    } else {
        log("Texture catalog: empty");
    }

    if sfx_catalog_count {
        log("SFX catalog:",);
        for 0..sfx_catalog_count - 1 {
            log("[%]: %", it, Asset_File_Name.as_string(sfx_catalog[it].filename));
        }
    } else {
        log("SFX catalog: empty");
    }

    if music_catalog_count {
        log("Music catalog:",);
        for 0..music_catalog_count - 1 {
            log("[%]: %", it, Asset_File_Name.as_string(music_catalog[it].filename));
        }
    } else {
        log("Music catalog: empty");
    }

    load_audio :: (platform: Platform, name: string) {
        // TODO(jt): @Correctness Sound_Player already deduplicates audio data, but other backends
        // might not!

        // TODO(jt): The cast([] u8) below is a little unfortunate. Maybe Platform.read_file should
        // return [] u8 instead?
        path := tprint("./data/audio/%", name);

        success, audio_data := platform.read_file(path);
        if success {
            platform.load_audio(name, cast([] u8, audio_data));
        } else {
            log_error("Failed to read audio file %", path);
        }
    }

    for 0..sfx_catalog_count - 1 {
        entry := *sfx_catalog[it];
        filename := Asset_File_Name.as_string(entry.filename);
        load_audio(platform, filename);
    }

    for 0..music_catalog_count - 1 {
        entry := *music_catalog[it];
        filename := Asset_File_Name.as_string(entry.filename);
        load_audio(platform, filename);
    }

    if platform.file_exists("./game_settings.bin") {
        success, data := platform.read_file("./game_settings.bin",, temp);
        if success {
            deserialize_game_settings(cast([] u8, data), *game.settings);
        } else {
            log_error("Settings file read failed");
        }
    }

    overworld_populate(*game.overworld);

    if platform.file_exists("./save_slot.txt") {
        log("Reading save file...");

        success, data := platform.read_file("./save_slot.txt",, temp);
        if success {
            if overworld_deserialize_state(*game.overworld, data) {
                log("Save file loaded successfully");
            } else {
                log_error("Save file deserialization failed");
            }
        } else {
            log_error("Save file read failed");
        }
    }

    game.initted = true;
}

// NOTE(jt): game_update and game_render used to be separate for historical reasons, but now they
// aren joined in game_update_and_render. The main reason is that now they can share some work they
// both had to do. Here's the reasons I think it should be alright:
//
// - A nongame app might want to update many times, but render just once, or render if its window
//   was invalidated but it didn't receive other meaningful events. However, if a game gets new
//   events, it will almost certainly want to draw something and output sounds.
//
// - If the game ever needs to do rendering or audio on a separate thread, it can do that with the
//   platform layer.
//
// - If the game wants to fix physics timestep, it can run its simulation code many times with the
//   appropriate delta time.
//
// The reasons why it may not be alright and we'll have to revert:
//
// - I don't know enough about all platforms and whether there isn't a one that requires separate
//   entrypoints for these for update/render/audio. I know this should be fine on Win32 and Web (and
//   likely all desktops). If anything, I have my worries about Android.
//
// - Some other serious reason I missed?
game_update_and_render :: (game: *Game, platform: Platform, input: Input, render_lists: *Render_Lists) -> wants_quit: bool {
    if !game.initted {
        game_init(game, platform);
    }

    wants_quit := false;

    input_state_update(*game.input_state, input);

    gui_start_frame(*game.gui);

    viewport := viewport_for_scene(SCREEN_SIZE_IN_TILES, TINY_DUNGEON_TILE_SIZE, input.window_size);
    draw_rect(render_lists, viewport.rect, color=Vector4.{ 0.09, 0.09, 0.09, 1.0 });

    if game.input_state.keys[Key_Code.ESCAPE] & .PRESSED {
        game.pause_menu_active = !game.pause_menu_active;
        audio_play_sound(*game.audio, SFX_UI_ACTIVATE);
    }

    if !game.pause_menu_active {
        {
            activated, events := image_button(*game.gui, game.input_state, viewport_transform_position(viewport, .{ 368, 0 }), TEX_ORYX_TINY_DUNGEON_INTERFACE, UI_SETTINGS_RECT, scale = viewport.scale);
            if activated {
                game.pause_menu_active = true;
                audio_play_sound(*game.audio, SFX_UI_ACTIVATE);
            }

            if events & .HOVERED {
                audio_play_sound(*game.audio, SFX_UI_HOVER);
            }
        }
    }

    if game.pause_menu_active {
        percent_formatter :: inline (x: f32) -> string {
            value := cast(s32, floor(x * 100.0));
            return tprint("%\%", formatInt(value, minimum_digits = 3, padding = " "));
        };

        do_save_settings := false;

        X_POSITION       :: 100.0;
        Y_CURSOR_ADVANCE :: 25.0;
        y_cursor := 50.0;

        {
            activated, events := button(*game.gui, game.input_state, viewport_transform_position(viewport, .{ X_POSITION, y_cursor }), "Resume game", scale = viewport.scale);
            if activated {
                game.pause_menu_active = false;
                audio_play_sound(*game.audio, SFX_UI_ACTIVATE);
            }

            if events & .HOVERED {
                audio_play_sound(*game.audio, SFX_UI_HOVER);
            }

            y_cursor += Y_CURSOR_ADVANCE;
        }

        {
            _, events := slider(
                *game.gui,
                game.input_state,
                viewport_transform_position(viewport, .{ X_POSITION, y_cursor }),
                "music volume",
                *game.settings.music_volume,
                formatter = percent_formatter,
                scale = viewport.scale,
            );

            if events & .HOVERED {
                audio_play_sound(*game.audio, SFX_UI_HOVER);
            }

            if events & .RELEASED {
                audio_play_sound(*game.audio, SFX_UI_ACTIVATE);
            }

            do_save_settings |= cast(bool, events & .RELEASED);

            y_cursor += Y_CURSOR_ADVANCE;
        }

        {
            _, events := slider(
                *game.gui,
                game.input_state,
                viewport_transform_position(viewport, .{ X_POSITION, y_cursor }),
                "  sfx volume",
                *game.settings.sfx_volume,
                formatter = percent_formatter,
                scale = viewport.scale,
            );

            if events & .HOVERED {
                audio_play_sound(*game.audio, SFX_UI_HOVER);
            }

            if events & .RELEASED {
                audio_play_sound(*game.audio, SFX_UI_ACTIVATE);
            }

            do_save_settings |= cast(bool, events & .RELEASED);

            y_cursor += Y_CURSOR_ADVANCE;
        }

        do_delete_and_restart := false;
        {
            confirm := game.pause_menu_delete_save_confirm;
            activated, events := button(*game.gui, game.input_state, viewport_transform_position(viewport, .{ X_POSITION, y_cursor }), ifx confirm then "(Click again to confirm)" else "Delete save and restart game", scale = viewport.scale);
            if activated {
                if confirm {
                    do_delete_and_restart = true;
                    game.pause_menu_delete_save_confirm = false;
                } else {
                    game.pause_menu_delete_save_confirm = true;

                    // We only play SFX_UI_ACTIVATE here, because a separate sound effect is
                    // triggered once we do delete and restart.
                    audio_play_sound(*game.audio, SFX_UI_ACTIVATE);
                }

            }

            if events & .HOVERED {
                audio_play_sound(*game.audio, SFX_UI_HOVER);
            }

            y_cursor += Y_CURSOR_ADVANCE;
        }


        do_asset_build := false;
        #if DEVELOPER {
            {
                activated, events := button(*game.gui, game.input_state, viewport_transform_position(viewport, .{ X_POSITION, y_cursor }), "Do asset build", scale = viewport.scale, color = .{ 1.0, 0.5, 0.5 });
                if activated {
                    do_asset_build = true;
                    audio_play_sound(*game.audio, SFX_UI_ACTIVATE);
                }

                if events & .HOVERED {
                    audio_play_sound(*game.audio, SFX_UI_HOVER);
                }

                y_cursor += Y_CURSOR_ADVANCE;
            }
        }

        do_run_solver_tests := false;
        #if DEVELOPER {
            {
                activated, events := button(*game.gui, game.input_state, viewport_transform_position(viewport, .{ X_POSITION, y_cursor }), "Run solver tests", scale = viewport.scale, color = .{ 1.0, 0.5, 0.5 });
                if activated {
                    do_run_solver_tests = true;
                    audio_play_sound(*game.audio, SFX_UI_ACTIVATE);
                }

                if events & .HOVERED {
                    audio_play_sound(*game.audio, SFX_UI_HOVER);
                }
            }

            y_cursor += Y_CURSOR_ADVANCE;
        }

        {
            activated, events := button(*game.gui, game.input_state, viewport_transform_position(viewport, .{ X_POSITION, y_cursor }), ifx game.pause_menu_quit_game_confirm then "(Click again to confirm)" else "Quit game", scale = viewport.scale);
            if activated {
                if game.pause_menu_quit_game_confirm {
                    wants_quit = true;
                } else {
                    game.pause_menu_quit_game_confirm = true;
                    audio_play_sound(*game.audio, SFX_UI_ACTIVATE);
                }

                if events & .HOVERED {
                    audio_play_sound(*game.audio, SFX_UI_HOVER);
                }
            }

            y_cursor += Y_CURSOR_ADVANCE;
        }

        if do_save_settings {
            binary_data: [..] u8;
            binary_data.allocator = temp;

            serialize_game_settings(*binary_data, game.settings);
            if platform.write_file("./game_settings.bin", cast(string, binary_data)) {
                log("Settings save successful");
            } else {
                log_error("Settings save failed!");
            }
        }

        if do_delete_and_restart {
            success := platform.delete_file("./save_slot.txt");
            if success {
                log("Save file deleted");
            } else {
                // TODO(jt): @Correctness This can happen if it didn't exist yet.
                log_error("failed to delete save file");
            }

            overworld_reset(*game.overworld);
            overworld_populate(*game.overworld);

            audio_play_sound(*game.audio, SFX_RESET);

            // If we are not in the overworld, make sure we go there.
            clear_transition(*game.transition);
            game.scene = .OVERWORLD;

            game.pause_menu_active = false;
        }

        #if DEVELOPER {
            //
            // TODO(jt): @Cleanup This code completely circumvents the platform layer, and doesn't
            // even set context allocator to temp, but is only present in developer builds. Make it
            // go through the platform layer eventually!
            //
            if do_asset_build {
                copy_asset :: (platform: Platform, source_path: string, dest_path: string) {
                    log("Copying % -> %", source_path, dest_path);

                    dest_directory := String.path_strip_filename(dest_path);
                    platform.make_directory_if_it_does_not_exist(dest_directory, recursive = true);

                    success := platform.copy_file(source_path, dest_path);
                    if !success {
                        log_error("Failed to copy file % -> %", source_path, dest_path);
                    }
                }

                log("Starting asset build...");

                proceed := true;
                if platform.file_exists("./asset_build") {
                    if platform.file_is_directory("./asset_build") {
                        log("Removing old asset_build directory...");
                        success := platform.delete_directory("./asset_build");
                        if !success {
                            log_error("Failed to delete old asset_build directory, aborting");
                            proceed = false;
                        }
                    } else {
                        log_error("asset_build is not a directory, aborting");
                        proceed = false;
                    }
                }

                if proceed {
                    log("Copying assets...");

                    for 0..texture_catalog_count - 1 {
                        entry := *texture_catalog[it];
                        filename := Asset_File_Name.as_string(entry.filename);

                        source_path := tprint("./data/textures/%", filename);
                        dest_path   := tprint("./asset_build/textures/%", filename);

                        copy_asset(platform, source_path, dest_path);
                    }

                    for 0..sfx_catalog_count - 1 {
                        entry := *sfx_catalog[it];
                        filename := Asset_File_Name.as_string(entry.filename);

                        source_path := tprint("./data/audio/%", filename);
                        dest_path   := tprint("./asset_build/audio/%", filename);

                        copy_asset(platform, source_path, dest_path);
                    }

                    for 0..music_catalog_count - 1 {
                        entry := *music_catalog[it];
                        filename := Asset_File_Name.as_string(entry.filename);

                        source_path := tprint("./data/audio/%", filename);
                        dest_path   := tprint("./asset_build/audio/%", filename);

                        copy_asset(platform, source_path, dest_path);
                    }

                    log("Asset build done");
                }
            }
        }

        #if DEVELOPER {
            //
            // TODO(jt): @Cleanup This code completely circumvents the platform layer, but is only
            // present in developer builds. Make it go through the platform layer eventually!
            //
            if do_run_solver_tests {
                run_solver_tests(platform);
            }
        }
    } else {
        game.pause_menu_delete_save_confirm = false;
        game.pause_menu_quit_game_confirm = false;

        if game.transition.type == {
            case .TO_OVERWORLD; {
                t    := game.transition;
                data := t.data.to_overworld;

                if data.solved {
                    log("Transitioning to overworld by winning a level");
                } else {
                    log("Transitioning to overworld by leaving a level");
                }

                overworld_save_level_state(*game.overworld, t.level, data.solved, t.board_state);

                game.scene = .OVERWORLD;

                clear_transition(*game.transition);
            }

            case .TO_LEVEL; {
                t    := game.transition;
                data := t.data.to_level;

                log("Transitioning to level %", t.level);

                level_load(*game.level, platform, game.transition.level, data.hint_flags, data.solved_on_the_overworld, t.board_state);
                game.scene = .LEVEL;

                clear_transition(*game.transition);
            }
        }

        if game.scene == {
            case .OVERWORLD; {
                game.transition = overworld_update_and_render(
                    *game.overworld,
                    platform,
                    input,
                    game.input_state,
                    *game.audio,
                    *game.gui,
                    render_lists,
                );

                if game.overworld.needs_save {
                    log("Saving overworld state");
                    state := overworld_serialize_state(game.overworld,, temp);

                    if platform.write_file("./save_slot.txt", state) {
                        game.overworld.needs_save = false;
                        log("Overworld save successful");
                    } else {
                        // TODO(jt): @Correctness Do not spam file write attempts here.
                    }
                }
            }

            case .LEVEL; {
                game.transition = level_update_and_render(
                    *game.level,
                    platform,
                    input,
                    game.input_state,
                    *game.audio,
                    *game.gui,
                    render_lists,
                );
            }
        }
    }

    audio_set_music_volume(*game.audio, game.settings.music_volume);
    audio_set_sfx_volume(*game.audio, game.settings.sfx_volume);
    audio_update(*game.audio, platform, cast(f32, to_float64_seconds(input.dtime)));

    array_add(*render_lists.rects, ..game.gui.render_lists.rects);

    return wants_quit;
}

// Even though this is a variable, we only write to it at compile time (and read from it at
// runtime).
//
// TODO(jt): We could have generated it as a constant with e.g. '#run -> [] Texture_Asset', but that
// would require we previously grouped all texture assets to a single constant we'd read from,
// similarly to what this code does:
// https://github.com/focus-editor/focus/blob/3c8c32106d24ebf2acf2099dea4e1bc6d20ae232/src/langs/jai.jai#L755.
// Maybe we should try it and see what we like more?
//
// TODO(jt): @Cleanup Even better, consider just doing this at runtime, so that we do not have to do
// any Asset_File_Name hacks (unless strings inside arrays get supported in #no_reset relatively quick?).
#no_reset texture_catalog:       [256] Texture_Asset;
#no_reset texture_catalog_count: s64;
#no_reset sfx_catalog:           [256] Sfx_Asset;
#no_reset sfx_catalog_count:     s64;
#no_reset music_catalog:         [256] Music_Asset;
#no_reset music_catalog_count:   s64;
#no_reset music_stream_count:    s64;

// TODO(jt): @Cleanup @Hack #no_reset Currently doesn't remap pointers of string literals (it thinks that
// they are not constant or something?), so instead we just store the string data inline.
//
// Alternatively, instead of trying to be fancy with compile time features, just initialize the
// catalogs in init code at runtime, so regular strings can be used, and we don't have another as_string bug.
Asset_File_Name :: struct {
    count:  s8;
    buffer: [127] u8; // 127 + 1 = 128

    // WARNING! If Asset_File_Name is on the stack, the string will become invalid once it goes out of scope.
    as_string :: (self: Asset_File_Name) -> string {
        return string.{ self.count, self.buffer.data, };
    }
}

Texture_Asset :: struct {
    index:    s64;
    filename: Asset_File_Name;
}

Sfx_Asset :: struct {
    index:    s64;
    filename: Asset_File_Name;
}

Music_Asset :: struct {
    index:    s64;
    filename: Asset_File_Name;
}

#scope_module

TextureAsset :: (filename: string) -> string {
    assert(#compile_time);
    assert(texture_catalog_count != texture_catalog.count, "Too many textures in texture catalog");

    asset: Texture_Asset;
    asset.index = texture_catalog_count;
    array_view_copy(asset.filename.buffer, cast([] u8, filename));
    asset.filename.count = cast(s8, filename.count);

    assert(Asset_File_Name.as_string(asset.filename) == filename);

    texture_catalog[texture_catalog_count] = asset;
    texture_catalog_count += 1;

    return filename;
}

SfxAsset :: (filename: string, tweak_volume := 1.0) -> Sfx {
    assert(#compile_time);
    assert(sfx_catalog_count != sfx_catalog.count, "Too many sounds in the sfx catalog");

    asset: Sfx_Asset;
    asset.index = sfx_catalog_count;
    array_view_copy(asset.filename.buffer, cast([] u8, filename));
    asset.filename.count = cast(s8, filename.count);

    assert(Asset_File_Name.as_string(asset.filename) == filename);

    sfx_catalog[sfx_catalog_count] = asset;
    sfx_catalog_count += 1;

    sfx := Sfx.{ filename, tweak_volume };

    return sfx;
}

MusicAsset :: (filename_for_loop: string, filename_for_intro := "", tweak_volume := 1.0) -> Music {
    assert(#compile_time);
    assert(music_catalog_count != music_catalog.count, "Too many music tracks in the music catalog");

    {
        asset: Music_Asset;
        asset.index = music_catalog_count;
        array_view_copy(asset.filename.buffer, cast([] u8, filename_for_loop));
        asset.filename.count = cast(s8, filename_for_loop.count);

        assert(Asset_File_Name.as_string(asset.filename) == filename_for_loop);

        music_catalog[music_catalog_count] = asset;
        music_catalog_count += 1;
    }

    if filename_for_intro.count {
        asset: Music_Asset;
        asset.index = music_catalog_count;
        array_view_copy(asset.filename.buffer, cast([] u8, filename_for_intro));
        asset.filename.count = cast(s8, filename_for_intro.count);

        assert(Asset_File_Name.as_string(asset.filename) == filename_for_intro);

        music_catalog[music_catalog_count] = asset;
        music_catalog_count += 1;
    }

    music := Music.{ music_stream_count, filename_for_loop, filename_for_intro, tweak_volume };

    music_stream_count += 1;

    return music;
}

//
// Textures
//

TEX_ORYX_TINY_DUNGEON_WORLD     :: #run TextureAsset("oryx/tiny_dungeon_world.png");
TEX_ORYX_TINY_DUNGEON_MONSTERS  :: #run TextureAsset("oryx/tiny_dungeon_monsters.png");
TEX_ORYX_TINY_DUNGEON_FONT      :: #run TextureAsset("oryx/tiny_dungeon_font.png");
TEX_ORYX_TINY_DUNGEON_FX        :: #run TextureAsset("oryx/tiny_dungeon_fx.png");
TEX_ORYX_TINY_DUNGEON_ITEMS     :: #run TextureAsset("oryx/tiny_dungeon_items.png");
TEX_ORYX_TINY_DUNGEON_INTERFACE :: #run TextureAsset("oryx/tiny_dungeon_interface.png");
TEX_XP_ICONS                    :: #run TextureAsset("xp_icons.png");
TEX_TRAP                        :: #run TextureAsset("trap.png");
TEX_FX                          :: #run TextureAsset("fx.png");
TEX_MARKERS                     :: #run TextureAsset("markers.png");
TEX_BORDERS                     :: #run TextureAsset("borders.png");
TEX_CRESTS                      :: #run TextureAsset("crests.png");
TEX_LEVEL_ENTRANCE_MARKED       :: #run TextureAsset("level_entrance_marked.png");
TEX_LEVEL_ENTRANCE_CENTER       :: #run TextureAsset("level_entrance_center.png");
TEX_MAGIC_MIRROR                :: #run TextureAsset("magic_mirror.png");
TEX_TUTORIAL                    :: #run TextureAsset("tutorial.png");

//
// Audio
//
// There are sounds effects and music tracks. Sound effects are fire and forget (they always run to
// completion). Music tracks have preallocated stream ids. There can only be one instance of each
// music track.
//
// Both music and sound effects have tweak_volume property. Because we pull music from multiple
// authors, the audio doesn't necessarily come at the same volume. For now we use tweak_volume to
// adjust.
//
// The Sound_Player module we use can play the 16-bit WAV format, and the OGG format. All (or most)
// of these assets should be in OGG, because either that's how I downloaded them, or because I
// manually re-encoded them to OGG in Audacity (using the highest quality preset).

// TODO(jt): Do variations of these sounds (tweak pitch and volume when launching).
SFX_ENTER_LEVEL             :: #run SfxAsset("Minifantasy_ForgottenPlains_SFX_Exclusive/DLC_05_Portal_close_2.ogg");
SFX_LEAVE_LEVEL             :: #run SfxAsset("Minifantasy_ForgottenPlains_SFX_Exclusive/DLC_05_Portal_close_2.ogg");
SFX_SOLVE_LEVEL_INSIDE      :: #run SfxAsset("RPG_Essentials_Free/8_Buffs_Heals_SFX/02_Heal_02.ogg");
SFX_SOLVE_LEVEL_OVERWORLD   :: #run SfxAsset("Minifantasy_ForgottenPlains_SFX_Exclusive/DLC_02_Portal_open_1.ogg");
SFX_ENTER_AREA              :: #run SfxAsset("Minifantasy_ForgottenPlains_SFX_Exclusive/DLC_04_Teleport_1.ogg");
SFX_UI_HOVER                :: #run SfxAsset("JDSherbert_Ultimate_UI_SFX_Pack_ogg/JDSherbert - Ultimate UI SFX Pack - Cursor - 3.ogg", tweak_volume = 0.3);
SFX_UI_ACTIVATE             :: #run SfxAsset("JDSherbert_Ultimate_UI_SFX_Pack_ogg/JDSherbert - Ultimate UI SFX Pack - Select - 2.ogg", tweak_volume = 0.5);
SFX_UI_BOOK_OPEN            :: #run SfxAsset("book_parchment_ui_SFX/01_book_open_1_fast.ogg");
SFX_UI_BOOK_CLOSE           :: #run SfxAsset("book_parchment_ui_SFX/02_book_close_1.ogg");
SFX_UI_BOOK_TURN_PAGE       :: #run SfxAsset("book_parchment_ui_SFX/03_flip_page_once_2.ogg");
SFX_UI_BOOK_HOVER           :: #run SfxAsset("book_parchment_ui_SFX/05_hover.ogg", tweak_volume = 0.5);
SFX_PLACE_OR_REMOVE_WALL    :: #run SfxAsset("RPG_Essentials_Free/12_Player_Movement_SFX/08_Step_rock_02.ogg");
SFX_PLACE_OR_REMOVE_EMPTY   :: #run SfxAsset("RPG_Essentials_Free/12_Player_Movement_SFX/42_Cling_climb_03.ogg");
SFX_PLACE_READ_ONLY_ATTEMPT :: #run SfxAsset("RPG_Essentials_Free/10_UI_Menu_SFX/071_Unequip_01.ogg");
SFX_DENIED                  :: #run SfxAsset("RPG_Essentials_Free/10_UI_Menu_SFX/033_Denied_03.ogg");
SFX_UNDO                    :: #run SfxAsset("JDSherbert_Ultimate_UI_SFX_Pack_ogg/JDSherbert - Ultimate UI SFX Pack - Cursor - 1.ogg", tweak_volume = 0.5);
SFX_RESET                   :: #run SfxAsset("JDSherbert_Ultimate_UI_SFX_Pack_ogg/JDSherbert - Ultimate UI SFX Pack - Cancel - 2.ogg", tweak_volume = 0.5);

MUSIC_PLAINS          :: #run MusicAsset("RPG-Music_Extras_Orchestral/MysticalTheme_Orch_Loop.ogg", filename_for_intro = "RPG-Music_Extras_Orchestral/MysticalTheme_Orch_Intro.ogg");
MUSIC_FOREST          :: #run MusicAsset("RPG-Music_Orchestral/04-Forest_Orchestral.ogg", tweak_volume = 0.6);
MUSIC_DESERT          :: #run MusicAsset("JDSherbert_Ambiences_ogg/JDSherbert - Ambiences Music Pack - Desert Sirocco.ogg");
MUSIC_BOG             :: #run MusicAsset("RPG-Music_Extras_Orchestral/Swamp_Orchestral.ogg");
// TODO(jt): MUSIC_MOUNTAINS doesn't loop seemlessly T_T
MUSIC_MOUNTAINS       :: #run MusicAsset("JDSherbert_Ambiences_ogg/JDSherbert - Ambiences Music Pack - Frost Mountain Aura.ogg");
MUSIC_ASHLANDS        :: #run MusicAsset("RPG-Music_Orchestral/08-Catacombs_Orchestral.ogg");

// TODO(jt): This viewport selection does quite a lot of letterboxing. We should either choose a
// good resolution to minimize that, OR do coverage based subpixel filtering, as described by Casey
// (https://guide.handmadehero.org/chat/chat018/#183)

Viewport :: struct {
    rect:  Rect;
    scale: f32;
}

viewport_for_scene :: (_scene_size_in_tiles: IVector2, _tileset_size_in_pixels: IVector2, _window_size_in_pixels: IVector2) -> Viewport {
    // Find the largest integer multiple of the tileset size we can use, and then center that.

    scale_vector := max(ivector_to_vector(_window_size_in_pixels / (_scene_size_in_tiles * _tileset_size_in_pixels)), Vector2.{ 1.0, 1.0 });
    scale        := min(scale_vector.x, scale_vector.y);

    scene_size_in_tiles    := ivector_to_vector(_scene_size_in_tiles);
    tileset_size_in_pixels := ivector_to_vector(_tileset_size_in_pixels);
    window_size_in_pixels  := ivector_to_vector(_window_size_in_pixels);

    scene_size_in_pixels := scale * scene_size_in_tiles * tileset_size_in_pixels;

    // Floor after divide to prevent artifacts when size is odd.
    half_scene_size  := floor(0.5 * scene_size_in_pixels);
    half_window_size := floor(0.5 * window_size_in_pixels);

    position := half_window_size - half_scene_size;
    size     := scene_size_in_pixels;

    rect := Rect.{ position.x, position.y, size.x, size.y };

    return Viewport.{ rect, scale };
}

viewport_transform_position :: inline (viewport: Viewport, position: Vector2) -> Vector2 {
    return viewport.rect.p0 + position * viewport.scale;
}

viewport_transform_rect :: inline (viewport: Viewport, r: Rect) -> Rect {
    return Rect.{
        viewport.rect.x + r.x * viewport.scale,
        viewport.rect.y + r.y * viewport.scale,
        r.w * viewport.scale,
        r.h * viewport.scale,
    };
}

SCREEN_SIZE_IN_TILES       :: IVector2.{ 24, 15 };
SCREEN_SIZE_IN_GAME_PIXELS :: #run SCREEN_SIZE_IN_TILES * TINY_DUNGEON_TILE_SIZE;

//
// TODO(jt): @Cleanup Think about a little more structured way of declaring texture rects. We could
// declare the existence of a texture (Texture_Asset), and within it also the tile size. We could
// have a make_texture_rect, which would be like make_tile_rect, but return a struct containing both
// the rect and the reference to the texture. Then we also have a way of drawing a textured rect
// directly, so we don't have to redundantly specify the texture in draw_rect? Try it out and see if
// it works better.
//

TINY_DUNGEON_TILE_SIZE :: IVector2.{ 16, 16 };

// The characters in the font are actually 5x5, but 6x6 includes the spacing so that we can just lay
// out the font tiles directly and not think about it. The additional height pixel (6x7), comes from
// the drop shadow from one variant of the font.
TINY_DUNGEON_FONT_TILE_SIZE              :: IVector2.{ 6, 7 };
TINY_DUNGEON_FONT_REGULAR_CHARACTER_SIZE :: IVector2.{ 5, 5 };
TINY_DUNGEON_FONT_SHADOW_CHARACTER_SIZE  :: IVector2.{ 5, 6 };

MAGIC_MIRROR_TILE_SIZE :: IVector2.{  32,  32 };
XP_ICONS_TILE_SIZE     :: IVector2.{  64,  64 };
TUTORIAL_TILE_SIZE     :: IVector2.{ 144, 144 };

UI_SETTINGS_RECT        :: #run make_tile_rect(3, 6, TINY_DUNGEON_TILE_SIZE);
UI_CROSSHAIR_GREEN_RECT :: #run make_tile_rect(10, 10, TINY_DUNGEON_TILE_SIZE);
UI_CROSSHAIR_RED_RECT   :: #run make_tile_rect(13, 10, TINY_DUNGEON_TILE_SIZE);

MARKED_WALL_RECT       :: #run make_tile_rect(2, 0, TINY_DUNGEON_TILE_SIZE);
MARKED_EMPTY_RECT      :: #run make_tile_rect(0, 0, TINY_DUNGEON_TILE_SIZE);
GROUND_RO_RECT         :: #run make_tile_rect(0, 1, TINY_DUNGEON_TILE_SIZE);
GROUND_RO_HOVERED_RECT :: #run make_tile_rect(1, 1, TINY_DUNGEON_TILE_SIZE);
GROUND_RW_RECT         :: #run make_tile_rect(2, 1, TINY_DUNGEON_TILE_SIZE);
GROUND_RW_HOVERED_RECT :: #run make_tile_rect(3, 1, TINY_DUNGEON_TILE_SIZE);

CLUE_MONSTER_RECT           :: #run make_tile_rect(9, 14, TINY_DUNGEON_TILE_SIZE);
CLUE_TREASURE_RECT          :: #run make_tile_rect(2, 12, TINY_DUNGEON_TILE_SIZE);
CLUE_TRAP_RECT              :: #run make_tile_rect(0, 0, TINY_DUNGEON_TILE_SIZE);
CLUE_CREST_SINGLE_RECT      :: #run make_tile_rect(0, 0, TINY_DUNGEON_TILE_SIZE);
CLUE_CREST_DOUBLE_RECT      :: #run make_tile_rect(1, 0, TINY_DUNGEON_TILE_SIZE);
CLUE_CREST_TRIPLE_RECT      :: #run make_tile_rect(2, 0, TINY_DUNGEON_TILE_SIZE);
CLUE_CREST_SINGLE_ALT_RECT  :: #run make_tile_rect(0, 1, TINY_DUNGEON_TILE_SIZE);
CLUE_CREST_DOUBLE_ALT_RECT  :: #run make_tile_rect(1, 1, TINY_DUNGEON_TILE_SIZE);
CLUE_CREST_TRIPLE_ALT_RECT  :: #run make_tile_rect(2, 1, TINY_DUNGEON_TILE_SIZE);
CLUE_MIRROR_NE_RECT         :: #run make_tile_rect(2, 0, MAGIC_MIRROR_TILE_SIZE);
CLUE_MIRROR_NW_RECT         :: #run make_tile_rect(3, 0, MAGIC_MIRROR_TILE_SIZE);
CLUE_MIRROR_SW_RECT         :: #run make_tile_rect(0, 0, MAGIC_MIRROR_TILE_SIZE);
CLUE_MIRROR_SE_RECT         :: #run make_tile_rect(1, 0, MAGIC_MIRROR_TILE_SIZE);

BORDER_NORTH_RECT        :: #run make_tile_rect(0, 0, TINY_DUNGEON_TILE_SIZE);
BORDER_SOUTH_RECT        :: #run make_tile_rect(2, 0, TINY_DUNGEON_TILE_SIZE);
BORDER_EAST_RECT         :: #run make_tile_rect(1, 0, TINY_DUNGEON_TILE_SIZE);
BORDER_WEST_RECT         :: #run make_tile_rect(3, 0, TINY_DUNGEON_TILE_SIZE);
BORDER_NORTH_WEST_RECT   :: #run make_tile_rect(0, 2, TINY_DUNGEON_TILE_SIZE);
BORDER_NORTH_EAST_RECT   :: #run make_tile_rect(1, 2, TINY_DUNGEON_TILE_SIZE);
BORDER_SOUTH_EAST_RECT   :: #run make_tile_rect(2, 2, TINY_DUNGEON_TILE_SIZE);
BORDER_SOUTH_WEST_RECT   :: #run make_tile_rect(3, 2, TINY_DUNGEON_TILE_SIZE);
BORDER_SHADOW_NORTH_RECT :: #run make_tile_rect(0, 1, TINY_DUNGEON_TILE_SIZE);
BORDER_SHADOW_SOUTH_RECT :: #run make_tile_rect(2, 1, TINY_DUNGEON_TILE_SIZE);
BORDER_SHADOW_EAST_RECT  :: #run make_tile_rect(1, 1, TINY_DUNGEON_TILE_SIZE);
BORDER_SHADOW_WEST_RECT  :: #run make_tile_rect(3, 1, TINY_DUNGEON_TILE_SIZE);

GROUND_BASE_RECT    :: #run make_tile_rect(1, 6, TINY_DUNGEON_TILE_SIZE);
GROUND_RECT0        :: #run make_tile_rect(2, 6, TINY_DUNGEON_TILE_SIZE);
GROUND_RECT1        :: #run make_tile_rect(3, 6, TINY_DUNGEON_TILE_SIZE);
GROUND_RECT2        :: #run make_tile_rect(4, 6, TINY_DUNGEON_TILE_SIZE);
GROUND_RECT3        :: #run make_tile_rect(5, 6, TINY_DUNGEON_TILE_SIZE);
GROUND_COBBLE_RECT0 :: #run make_tile_rect(7, 7, TINY_DUNGEON_TILE_SIZE);
GROUND_COBBLE_RECT1 :: #run make_tile_rect(8, 7, TINY_DUNGEON_TILE_SIZE);

GROUND_OVERGROWN_BASE_RECT    :: #run make_tile_rect(11, 7, TINY_DUNGEON_TILE_SIZE);
GROUND_OVERGROWN_RECT0        :: #run make_tile_rect(12, 7, TINY_DUNGEON_TILE_SIZE);
GROUND_OVERGROWN_RECT1        :: #run make_tile_rect(13, 7, TINY_DUNGEON_TILE_SIZE);
GROUND_OVERGROWN_RECT2        :: #run make_tile_rect(14, 7, TINY_DUNGEON_TILE_SIZE);
GROUND_OVERGROWN_RECT3        :: #run make_tile_rect(15, 7, TINY_DUNGEON_TILE_SIZE);
GROUND_OVERGROWN_COBBLE_RECT0 :: #run make_tile_rect(9, 7, TINY_DUNGEON_TILE_SIZE);
GROUND_OVERGROWN_COBBLE_RECT1 :: #run make_tile_rect(10, 7, TINY_DUNGEON_TILE_SIZE);

LEVEL_ENTRANCE_RECT        :: #run make_tile_rect(6, 13, TINY_DUNGEON_TILE_SIZE);
LEVEL_ENTRANCE_SOLVED_RECT :: #run make_tile_rect(5, 13, TINY_DUNGEON_TILE_SIZE);
LEVEL_ENTRANCE_CENTER_RECT :: #run make_tile_rect(0, 0, TINY_DUNGEON_TILE_SIZE);
AREA_ENTRANCE_RECT         :: #run make_tile_rect(7, 13, TINY_DUNGEON_TILE_SIZE);
SCROLL_RECT                :: #run make_tile_rect(6, 0, TINY_DUNGEON_TILE_SIZE);

SPARKLE_ANIM_RECT0 :: #run make_tile_rect( 5, 5, TINY_DUNGEON_TILE_SIZE);
SPARKLE_ANIM_RECT1 :: #run make_tile_rect( 6, 5, TINY_DUNGEON_TILE_SIZE);
SPARKLE_ANIM_RECT2 :: #run make_tile_rect( 7, 5, TINY_DUNGEON_TILE_SIZE);
SPARKLE_ANIM_RECT3 :: #run make_tile_rect( 8, 5, TINY_DUNGEON_TILE_SIZE);
SPARKLE_ANIM_RECT4 :: #run make_tile_rect( 9, 5, TINY_DUNGEON_TILE_SIZE);
SPARKLE_ANIM_RECT5 :: #run make_tile_rect(10, 5, TINY_DUNGEON_TILE_SIZE);
SPARKLE_ANIM_RECT6 :: #run make_tile_rect(11, 5, TINY_DUNGEON_TILE_SIZE);

FX_CLUE_ANIM_RECT0         :: #run make_tile_rect(0, 2, TINY_DUNGEON_TILE_SIZE);
FX_CLUE_ANIM_RECT1         :: #run make_tile_rect(1, 2, TINY_DUNGEON_TILE_SIZE);
FX_CLUE_ANIM_RECT2         :: #run make_tile_rect(2, 2, TINY_DUNGEON_TILE_SIZE);
FX_POOL_ANIM_RECT0         :: #run make_tile_rect(0, 0, TINY_DUNGEON_TILE_SIZE);
FX_POOL_ANIM_RECT1         :: #run make_tile_rect(1, 0, TINY_DUNGEON_TILE_SIZE);
FX_DEAD_END_ANIM_RECT0     :: #run make_tile_rect(2, 0, TINY_DUNGEON_TILE_SIZE);
FX_DEAD_END_ANIM_RECT1     :: #run make_tile_rect(3, 0, TINY_DUNGEON_TILE_SIZE);
FX_CONNECTIVITY_ANIM_RECT0 :: #run make_tile_rect(0, 1, TINY_DUNGEON_TILE_SIZE);
FX_CONNECTIVITY_ANIM_RECT1 :: #run make_tile_rect(1, 1, TINY_DUNGEON_TILE_SIZE);

CONNECTIVITY_SYMBOL_RECT :: #run make_tile_rect(0, 2, TINY_DUNGEON_TILE_SIZE);

LOCKED_ENTITY_RECT :: #run make_tile_rect(9, 5, TINY_DUNGEON_TILE_SIZE);

CHARACTER0_RECT :: #run make_tile_rect(26, 2, TINY_DUNGEON_FONT_TILE_SIZE);
CHARACTER1_RECT :: #run make_tile_rect(27, 2, TINY_DUNGEON_FONT_TILE_SIZE);
CHARACTER2_RECT :: #run make_tile_rect(28, 2, TINY_DUNGEON_FONT_TILE_SIZE);
CHARACTER3_RECT :: #run make_tile_rect(29, 2, TINY_DUNGEON_FONT_TILE_SIZE);
CHARACTER4_RECT :: #run make_tile_rect(30, 2, TINY_DUNGEON_FONT_TILE_SIZE);
CHARACTER5_RECT :: #run make_tile_rect(31, 2, TINY_DUNGEON_FONT_TILE_SIZE);
CHARACTER6_RECT :: #run make_tile_rect(32, 2, TINY_DUNGEON_FONT_TILE_SIZE);
CHARACTER7_RECT :: #run make_tile_rect(33, 2, TINY_DUNGEON_FONT_TILE_SIZE);
CHARACTER8_RECT :: #run make_tile_rect(34, 2, TINY_DUNGEON_FONT_TILE_SIZE);
CHARACTER9_RECT :: #run make_tile_rect(35, 2, TINY_DUNGEON_FONT_TILE_SIZE);

CHARACTER0_TIGHT_RECT :: #run rect_inset_max(CHARACTER0_RECT, .{ 1, 2 });
CHARACTER1_TIGHT_RECT :: #run rect_inset_max(CHARACTER1_RECT, .{ 1, 2 });
CHARACTER2_TIGHT_RECT :: #run rect_inset_max(CHARACTER2_RECT, .{ 1, 2 });
CHARACTER3_TIGHT_RECT :: #run rect_inset_max(CHARACTER3_RECT, .{ 1, 2 });
CHARACTER4_TIGHT_RECT :: #run rect_inset_max(CHARACTER4_RECT, .{ 1, 2 });
CHARACTER5_TIGHT_RECT :: #run rect_inset_max(CHARACTER5_RECT, .{ 1, 2 });
CHARACTER6_TIGHT_RECT :: #run rect_inset_max(CHARACTER6_RECT, .{ 1, 2 });
CHARACTER7_TIGHT_RECT :: #run rect_inset_max(CHARACTER7_RECT, .{ 1, 2 });
CHARACTER8_TIGHT_RECT :: #run rect_inset_max(CHARACTER8_RECT, .{ 1, 2 });
CHARACTER9_TIGHT_RECT :: #run rect_inset_max(CHARACTER9_RECT, .{ 1, 2 });

ARROW_UP_RECT    :: #run make_tile_rect(1, 11, XP_ICONS_TILE_SIZE);
ARROW_RIGHT_RECT :: #run make_tile_rect(2, 11, XP_ICONS_TILE_SIZE);
ARROW_LEFT_RECT  :: #run make_tile_rect(3, 11, XP_ICONS_TILE_SIZE);
ARROW_DOWN_RECT  :: #run make_tile_rect(4, 11, XP_ICONS_TILE_SIZE);

SCROLL_BACKGROUND_TOP_LEFT_RECT     :: #run make_tile_rect(9, 0, TINY_DUNGEON_TILE_SIZE);
SCROLL_BACKGROUND_TOP_RECT          :: #run make_tile_rect(10, 0, TINY_DUNGEON_TILE_SIZE);
SCROLL_BACKGROUND_TOP_RIGHT_RECT    :: #run make_tile_rect(11, 0, TINY_DUNGEON_TILE_SIZE);
SCROLL_BACKGROUND_MID_LEFT_RECT     :: #run make_tile_rect(9, 1, TINY_DUNGEON_TILE_SIZE);
SCROLL_BACKGROUND_MID_RECT          :: #run make_tile_rect(10, 1, TINY_DUNGEON_TILE_SIZE);
SCROLL_BACKGROUND_MID_RIGHT_RECT    :: #run make_tile_rect(11, 1, TINY_DUNGEON_TILE_SIZE);
SCROLL_BACKGROUND_BOTTOM_LEFT_RECT  :: #run make_tile_rect(9, 2, TINY_DUNGEON_TILE_SIZE);
SCROLL_BACKGROUND_BOTTOM_RECT       :: #run make_tile_rect(10, 2, TINY_DUNGEON_TILE_SIZE);
SCROLL_BACKGROUND_BOTTOM_RIGHT_RECT :: #run make_tile_rect(11, 2, TINY_DUNGEON_TILE_SIZE);

TUTORIAL_ANIM_FRAMES :: #run Rect.[
    make_tile_rect(0, 0, TUTORIAL_TILE_SIZE),
    make_tile_rect(1, 0, TUTORIAL_TILE_SIZE),
    make_tile_rect(2, 0, TUTORIAL_TILE_SIZE),
    make_tile_rect(3, 0, TUTORIAL_TILE_SIZE),
    make_tile_rect(4, 0, TUTORIAL_TILE_SIZE),
    make_tile_rect(5, 0, TUTORIAL_TILE_SIZE),

    make_tile_rect(0, 1, TUTORIAL_TILE_SIZE),
    make_tile_rect(1, 1, TUTORIAL_TILE_SIZE),
    make_tile_rect(2, 1, TUTORIAL_TILE_SIZE),
    make_tile_rect(3, 1, TUTORIAL_TILE_SIZE),
    make_tile_rect(4, 1, TUTORIAL_TILE_SIZE),
    make_tile_rect(5, 1, TUTORIAL_TILE_SIZE),

    make_tile_rect(0, 2, TUTORIAL_TILE_SIZE),
    make_tile_rect(1, 2, TUTORIAL_TILE_SIZE),
    make_tile_rect(2, 2, TUTORIAL_TILE_SIZE),
    make_tile_rect(3, 2, TUTORIAL_TILE_SIZE),
    make_tile_rect(4, 2, TUTORIAL_TILE_SIZE),
    make_tile_rect(5, 2, TUTORIAL_TILE_SIZE),

    make_tile_rect(0, 3, TUTORIAL_TILE_SIZE),
    make_tile_rect(1, 3, TUTORIAL_TILE_SIZE),
    make_tile_rect(2, 3, TUTORIAL_TILE_SIZE),
    make_tile_rect(3, 3, TUTORIAL_TILE_SIZE),
    make_tile_rect(4, 3, TUTORIAL_TILE_SIZE),
    make_tile_rect(5, 3, TUTORIAL_TILE_SIZE),

    make_tile_rect(0, 4, TUTORIAL_TILE_SIZE),
    make_tile_rect(1, 4, TUTORIAL_TILE_SIZE),
    make_tile_rect(2, 4, TUTORIAL_TILE_SIZE),
    make_tile_rect(3, 4, TUTORIAL_TILE_SIZE),
    make_tile_rect(4, 4, TUTORIAL_TILE_SIZE),
];

// TODO(jt): @Cleanup We do this quite a lot. Are we sure that min/max is a good rect definition? Or
// maybe we should just make a similar function available in the math library.

make_tile_rect :: (x: s32, y: s32, size: IVector2) -> Rect {
    result: Rect = ---;

    result.x = cast(f32, x) * cast(f32, size.x);
    result.y = cast(f32, y) * cast(f32, size.y);
    result.w = cast(f32, size.x);
    result.h = cast(f32, size.y);

    return result;
}

#scope_file

clear_transition :: (transition: *Game_Transition) {
    t: Game_Transition;
    transition.* = t;
}

serialize_game_settings :: (array: *[..] u8, settings: Game_Settings) {
    write_value(array, settings.version);
    write_value(array, settings.music_volume);
    write_value(array, settings.sfx_volume);
}

deserialize_game_settings :: (array: [] u8, settings: *Game_Settings) {
    read_value(*array, *settings.version);
    read_value(*array, *settings.music_volume);
    read_value(*array, *settings.sfx_volume);

    // To start versioning this file, skip over read_value calls for stuff that is not present in
    // the version being deserialized.
}

write_value :: (array: *[..] u8, value: $T)
#modify { return IsScalar(T), "Argument is not of a scalar type"; }
{
    bytes := cast,force([size_of(T)] u8, *value);
    array_add(array, ..bytes);
}

read_value :: (array: *[] u8, value: *$T)
#modify { return IsScalar(T), "Argument is not of a scalar type"; }
{
    value_bytes := array_view(array.*, 0, size_of(T));

    // We cast both to pointer to [size_of(T)] u8 and do the copy that way (hopefully it doesn't
    // copy byte by byte?), because at least in Rust and possibly in all languages that use LLVM,
    // creating unaligned pointers would be UB, unless JAI specifically avoids that.
    //
    // One other way to fix this would be to pre-align the array and evolve the format such that the
    // alignment is always taken care of, but I think that for flexibility of changing the
    // serialized format, we do not want to be constantly thinking of alignment and padding across
    // all versions of the file, therefore the values have to be copied as bytes here.
    array_pointer := cast(*[size_of(T)] u8, value_bytes.data);
    value_pointer := cast(*[size_of(T)] u8, value);
    value_pointer.* = array_pointer.*;

    array.* = array_view(array.*, size_of(T));
}
