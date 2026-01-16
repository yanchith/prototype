// TODO(jt): @Cleanup Decide what to do with print/logging in this file.

run_solver_tests :: (platform: Platform) {
    time_start := current_time_monotonic();

    // TODO(jt): #malloc @Memory Because we auto_release_temp per test, failures and warnings are
    // collected in a different arena. For now that arena is just malloc.
    //
    // TODO(jt): Make enums for failures and warnings instead of allocating a string for each one.
    failures: [..] string;
    warnings: [..] string;

    solve_and_print_board :: (
        failures: *[..] string,
        warnings: *[..] string,
        global_deduction_stats: *Deduction_Solve_Stats,
        capabilities: Deduction_Capabilities,
        _board: Board,
        label := "",
        expected_check: Board_Check,
        expected_check_flags: Board_Check_Flags,
        expected_solutions := 1,
        max_backtrack := -1
    ) {
        original_board := _board;
        unsolved_board := board_copy(_board,, temp);
        board_unsolve(*unsolved_board);

        print(right_pad(tprint("Solving % (%x%)... ", label, original_board.xsize, original_board.ysize, label), 100));
        #if SOLVER_TESTS_VERBOSE {
            print("\n");
            board_print(original_board);
            print("\n");
        }

        {
            check, flags := board_check(original_board);
            if check != expected_check || flags != expected_check_flags {
                array_add(failures, sprint("              CHECK  %", label));
                print("FAILED(CHECK, expected %: %, but found %: %)\n", expected_check, expected_check_flags, check, flags);

                #if SOLVER_TESTS_VERBOSE {
                    print("\n-----------------------------------\n\n");
                }
                return;
            }

            if check != .SOLVED {
                print("EXPECTED_FAIL(CHECK, %: %)\n", check, flags);

                #if SOLVER_TESTS_VERBOSE {
                    print("\n-----------------------------------\n\n");
                }
                return;
            }
        }

        board_contains_secret_clues := false;
        for original_board.tiles {
            if tile_is_secret_clue(it) {
                board_contains_secret_clues = true;
                break;
            }
        }


        solve_internal :: (failures: *[..] string, warnings: *[..] string, capabilities: Deduction_Capabilities, original_board: Board, board: Board, label: string, expected_solutions: s64, max_backtrack: s64) -> success: bool, stats: Solve_Stats {
            success := true;

            solve_time_start := current_time_monotonic();
            solved_boards, stats := solve(board, capabilities, max_backtrack, verbose=SOLVER_VERBOSE, very_verbose=SOLVER_VERY_VERBOSE,, temp);
            solve_time_end := current_time_monotonic();

            if solved_boards.count {
                if stats.terminated_due_to_limit {
                    print(
                        "FAILED(%, LIMIT) in % seconds\n",
                        solved_boards.count,
                        formatFloat(to_float64_seconds(solve_time_end) - to_float64_seconds(solve_time_start), trailing_width = 3, zero_removal = .NO),
                    );
                    array_add(failures, sprint("              LIMIT  %", label));
                    success = false;
                } else if expected_solutions == 1 && solved_boards.count == 1 {
                    if solved_boards[0] == original_board {
                        print(
                            "SOLVED(%) in % seconds\n",
                            solved_boards.count,
                            formatFloat(to_float64_seconds(solve_time_end) - to_float64_seconds(solve_time_start), trailing_width = 3, zero_removal = .NO),
                        );
                    } else {
                        print(
                            "FAILED(SINGLE SOLUTION MISMATCH) in % seconds\n",
                            formatFloat(to_float64_seconds(solve_time_end) - to_float64_seconds(solve_time_start), trailing_width = 3, zero_removal = .NO),
                        );
                        array_add(failures, sprint("     SINGLE SOLUTION MISMATCH  %", label));
                        success = false;
                    }
                } else if expected_solutions < 0 || solved_boards.count == expected_solutions {
                    print(
                        "SOLVED(%) in % seconds\n",
                        solved_boards.count,
                        formatFloat(to_float64_seconds(solve_time_end) - to_float64_seconds(solve_time_start), trailing_width = 3, zero_removal = .NO),
                    );
                } else {
                    print(
                        "FAILED(AMBIGUOUS, expected % but found %) in % seconds\n",
                        expected_solutions,
                        solved_boards.count,
                        formatFloat(to_float64_seconds(solve_time_end) - to_float64_seconds(solve_time_start), trailing_width = 3, zero_removal = .NO),
                    );
                    array_add(failures, sprint("          AMBIGUOUS  %", label));
                    success = false;
                }
            } else {
                print(
                    "FAILED(UNSOLVABLE) in % seconds\n",
                    formatFloat(to_float64_seconds(solve_time_end) - to_float64_seconds(solve_time_start), trailing_width = 3, zero_removal = .NO),
                );
                array_add(failures, sprint("         UNSOLVABLE  %", label));
                success = false;
            }

            #if SOLVER_TESTS_VERBOSE {
                print("\n");
                for solved_boards {
                    board_print(it);
                }

                print("solution_path_count   = %\n", stats.solution_path_count);
                print("backtrack_guess_count = %\n", stats.backtrack_guess_count);
                print("backtrack_max_depth   = %\n", stats.backtrack_max_depth);
                print("deduction_max_depth   = %\n", stats.deduction.max_depth);
                print("\n");

                print("deduction_applies_for_mark_remaining_walls                           = %\n", stats.deduction.applies_for_mark_remaining_walls);
                print("deduction_applies_for_mark_remaining_monster_adjacent_tiles          = %\n", stats.deduction.applies_for_mark_remaining_monster_adjacent_tiles);
                print("deduction_applies_for_mark_remaining_pool_wall                       = %\n", stats.deduction.applies_for_mark_remaining_pool_wall);
                print("deduction_applies_for_mark_remaining_dead_ends                       = %\n", stats.deduction.applies_for_mark_remaining_dead_ends);
                print("deduction_applies_for_mark_remaining_disconnected_subgraphs          = %\n", stats.deduction.applies_for_mark_remaining_disconnected_subgraphs);
                print("deduction_applies_for_mark_some_treasure_room_tiles                  = %\n", stats.deduction.applies_for_mark_some_treasure_room_tiles);
                print("deduction_applies_for_mark_some_walls_between_treasure_room_and_clue = %\n", stats.deduction.applies_for_mark_some_walls_between_treasure_room_and_clue);
                print("deduction_applies_for_mark_empty_tiles_adjacent_to_bottlenecks       = %\n", stats.deduction.applies_for_mark_empty_tiles_adjacent_to_bottlenecks);
                print("\n");
            }

            return success, stats;
        }

        accumulate_deduction_stats :: (dest: *Deduction_Solve_Stats, source: Deduction_Solve_Stats) {
            dest.max_depth = max(dest.max_depth, source.max_depth);
            dest.applies_for_mark_remaining_walls += source.applies_for_mark_remaining_walls;
            dest.applies_for_mark_remaining_monster_adjacent_tiles += source.applies_for_mark_remaining_monster_adjacent_tiles;
            dest.applies_for_mark_remaining_pool_wall += source.applies_for_mark_remaining_pool_wall;
            dest.applies_for_mark_remaining_dead_ends += source.applies_for_mark_remaining_dead_ends;
            dest.applies_for_mark_remaining_disconnected_subgraphs += source.applies_for_mark_remaining_disconnected_subgraphs;
            dest.applies_for_mark_some_treasure_room_tiles += source.applies_for_mark_some_treasure_room_tiles;
            dest.applies_for_mark_some_walls_between_treasure_room_and_clue += source.applies_for_mark_some_walls_between_treasure_room_and_clue;
            dest.applies_for_mark_empty_tiles_adjacent_to_bottlenecks += source.applies_for_mark_empty_tiles_adjacent_to_bottlenecks;
        }

        success1, stats1 := solve_internal(failures, warnings, capabilities, original_board, unsolved_board, label, expected_solutions, max_backtrack);
        accumulate_deduction_stats(global_deduction_stats, stats1.deduction);

        if success1 && board_contains_secret_clues {
            erased_original_board := board_copy(original_board,, temp);
            board_erase_secret_clues(*erased_original_board);

            erased_unsolved_board := board_copy(unsolved_board,, temp);
            board_erase_secret_clues(*erased_unsolved_board);

            print(right_pad(tprint("Solving %_ERASED (%x%)... ", label, original_board.xsize, original_board.ysize, label), 100));
            success2, stats2 := solve_internal(failures, warnings, capabilities, erased_original_board, erased_unsolved_board, tprint("%_ERASED", label), -1, max_backtrack);
            accumulate_deduction_stats(global_deduction_stats, stats2.deduction);

            if success2 && stats2.backtrack_guess_count < stats1.backtrack_guess_count {
                array_add(warnings, sprint("  ERASED IS SIMPLER  %", label));
            }
        }

        #if SOLVER_TESTS_VERBOSE {
            print("\n-----------------------------------\n\n");
        }
    }

    solve_and_print_board_from_file :: (
        platform: Platform,
        failures: *[..] string,
        warnings: *[..] string,
        global_deduction_stats: *Deduction_Solve_Stats,
        capabilities: Deduction_Capabilities,
        path: string,
        expected_check: Board_Check,
        expected_check_flags: Board_Check_Flags,
        expected_solutions: s64,
        max_backtrack := -1
    ) {
        s: string;
        {
            success, _s := platform.read_file(path);
            if !success {
                array_add(failures, sprint("               LOAD  %", path));
                print("%... FAILED(LOAD)\n", path);
                #if SOLVER_TESTS_VERBOSE {
                    print("\n-----------------------------------\n\n");
                }
                return;
            }

            s = _s;
        }

        b, success := board_parse(s, unsolve = false, unsolve_except_walls = false,, temp);
        label := String.path_strip_extension(String.path_filename(path,, temp),, temp);
        if success {
            solve_and_print_board(failures, warnings, global_deduction_stats, capabilities, b, label, expected_check, expected_check_flags, expected_solutions, max_backtrack);
        } else {
            print("%... FAILED(PARSE)\n", label);
            array_add(failures, sprint("              PARSE  %", label));
        }
    }

    Test :: struct {
        level: string;
        solutions    := 1;
        capabilities := Deduction_Capabilities.ALL;

        check       := Board_Check.SOLVED;
        check_flags := Board_Check_Flags.NONE;
    }

    TESTS :: Test.[
        //
        // Artificial tests
        //
        Test.{ level = "test001_traps" },
        Test.{ level = "test002_traps" },
        Test.{ level = "test003_traps" },
        Test.{ level = "test005_empty" },
        Test.{ level = "test006_crests" },
        Test.{ level = "test007_crests_alt" },
        // TODO(jt): Our new, faster crest verifier can't do triple crests.
        // "test008_crests_triple",
        // "test009_crests_and_minotaurs",
        Test.{ level = "test010_crests_fail",          check = .OPEN, check_flags = .CRESTS_OPEN },
        Test.{ level = "test011_crests_and_monsters" },
        Test.{ level = "test012_crests_and_monsters2" },

        //
        // Original Dungeons & Diagrams levels
        //
        // TODO(jt): Find levels with low backtrack guess counts and try bringing that guess count to zero.
        Test.{ level = "pdf000_tutorial" },
        Test.{ level = "pdf001_tenaxxuss_gullet" },
        Test.{ level = "pdf002_the_twin_cities_of_the_dead" },
        Test.{ level = "pdf003_the_gardens_of_hell" },
        Test.{ level = "pdf004_the_house_penumbral" },
        Test.{ level = "pdf005_the_maze_of_the_minotaur" },
        Test.{ level = "pdf006_the_halls_of_the_golemancer" },
        Test.{ level = "pdf007_the_tomb_of_the_broken_god" },
        Test.{ level = "pdf008_the_hive_of_great_sorrow" },
        Test.{ level = "pdf009_the_lair_of_the_elemental_king" },

        Test.{ level = "001_brightleaf_iron_mine",             },    // No backtracking
        Test.{ level = "002_the_secret_tunnels",               },    // No backtracking
        Test.{ level = "003_the_graveyard_of_the_vernal_king", },    // No backtracking
        Test.{ level = "004_shifting_walls",                   },    // No backtracking
        Test.{ level = "005_the_fetid_sewers",                 },    // No backtracking
        Test.{ level = "006_the_dias_of_the_sun_god",          },    // No backtracking
        Test.{ level = "007_the_coronation_of_the_lich",       },    // No backtracking, although a little bit advanced
        Test.{ level = "008_the_demon_marquis_of_lust",        },    // No backtracking

        Test.{ level = "009_the_promenade" },                        // No backtracking
        Test.{ level = "010_the_bloodsoaked_den" },                  // No backtracking
        Test.{ level = "011_the_false_maze_of_the_minotaur" },       // No backtracking
        Test.{ level = "012_the_phylactery_of_the_lich" },           // No backtracking
        Test.{ level = "013_the_trials_of_the_anointed_one" },       // No backtracking
        Test.{ level = "014_the_demon_count_of_gluttony" },          // No backtracking
        Test.{ level = "015_the_winding_warren" },                   // No backtracking
        Test.{ level = "016_the_gleaming_sky-vaults" },              // No backtracking

        Test.{ level = "017_the_corridor_of_vise" },                 // No backtracking
        Test.{ level = "018_the_twin_cities_of_the_dead" },          // No backtracking
        Test.{ level = "019_the_tainted_glade" },                    // No backtracking
        Test.{ level = "020_the_demon_duke_of_avarice" },            // No backtracking, although requires exit sharing reasoning
        Test.{ level = "021_the_altar_of_unkown_sacrifice" },        // No backtracking
        Test.{ level = "022_old_saulksburgh_gold_vaults" },          // No backtracking
        Test.{ level = "023_the_illusory_hoard" },                   // No backtracking, although a little hard?
        Test.{ level = "024_the_skittering_gallery" },               // No backtracking, requires advanced reasoning: exit sharing and 1 wall for 2 monsters.

        Test.{ level = "025_the_thiefs_dilemma" },                   // No backtracking, although a little hard
        Test.{ level = "026_the_chapel_of_the_undying_martyr" },     // No backtracking
        Test.{ level = "027_the_hungering_caverns" },                // No backtracking
        Test.{ level = "028_the_cosmic_orrery" },                    // No backtracking, nice placement of the treasure room between two monsters, also very nice deduction of treasure room exit!
        Test.{ level = "029_the_house_penumbral" },                  // No backtracking, nice and advanced wall column spacing!
        Test.{ level = "030_the_demon_prince_of_wrath" },            // No backtracking
        Test.{ level = "031_krogmars_last_stand" },                  // First hints of backtracking in the lategame
        Test.{ level = "032_the_catacombs_of_the_lichs_army" },      // No backtracking

        Test.{ level = "033_wardens_of_the_uncaged_chaos" },
        Test.{ level = "034_the_eye_of_the_minotaur" },
        Test.{ level = "035_the_corroded_corridors" },
        Test.{ level = "036_the_triumvirate_of_the_planar_keep" },
        Test.{ level = "037_the_halls_of_the_golemancer" },
        Test.{ level = "038_the_glacial_nest" },
        Test.{ level = "039_fort_impenetrable" },
        Test.{ level = "040_the_artificers_museum" },

        Test.{ level = "041_beneath_the_haunted_woods" },
        Test.{ level = "042_the_scoured_halls" },
        Test.{ level = "043_the_tomb_of_the_summer_king" },
        Test.{ level = "044_the_living_reliquary" },
        Test.{ level = "045_the_twisting_descent" },
        Test.{ level = "046_the_edge_of_the_endless_swarm" },
        Test.{ level = "047_the_ascension_of_the_archlich" },
        Test.{ level = "048_the_tomb_of_the_broken_god" },

        Test.{ level = "049_the_ashen_remnant" },
        Test.{ level = "050_the_tomb_of_the_autumn_king" },
        Test.{ level = "051_the_oblivion_hoard" },
        Test.{ level = "052_the_minotaurs_pursuit" },
        Test.{ level = "053_the_engine_of_the_golemancer" },
        Test.{ level = "054_the_hive_of_great_sorrow" },
        Test.{ level = "055_the_masters_of_the_astral_voyager" },
        Test.{ level = "056_the_barrow_of_the_winter_king" },

        Test.{ level = "057_the_demon_king_of_vainglory" },
        Test.{ level = "058_the_water_temple" },
        Test.{ level = "059_the_counil_of_unmaking" },
        Test.{ level = "060_ickbogs_grave_mistake" },
        Test.{ level = "061_tenaxxuss_gullet" },
        Test.{ level = "062_the_undertower_of_the_archlich" },
        Test.{ level = "063_the_true_maze_of_the_minotaur" },

        Test.{ level = "shadow_caverns_64397677" },
        //
        // Diagrams & Dragons levels
        //
        // TODO(jt): @Design Audit each level that doesn't have a comment here here and either:
        // - If the level is good, make that short comment about what the level is is about,
        // - If the level is not good enough, try and make it better,
        // - If the level is not salvageable, cut it.
        //
        // Tags:
        //
        // - #vanilla or #mechanic1 #mechanic2 #mechanic3...:
        //
        //   Which mechanics/ideas are used in the puzzle. Maybe we need to also tag vanilla
        //   mechanics so that we can have our spreadsheet.
        //
        // - #observation or #assuming
        //
        //   The scale of whether the level is teaching or testing the mechanic.
        //
        // - #easy or #medium or #hard:
        //
        //   Has to be interpretted together with the tutorialness, as that changes the meaning. A
        //   #hard #observation is a hard level that does not assume the player knows the mechanic.
        //

        Test.{ level = "jt001_temple_of_decaying_symmetry" },              // #vanilla #medium              Strong visual start (and utilization of forced placing walls between monsters), but after that all over the place. TODO(jt): @Design Is there a way to make this better, or do we have to cut?
        Test.{ level = "jt002_forgotten_trail" },                          // #vanilla #easy                Flowy but not too easy.
        Test.{ level = "jt003_the_archmages_vault" },                      // #traps   #medium #assuming    Okay visuals and theme.
        Test.{ level = "jt004_city_watch_armory" },                        // #vanilla #easy                Almost too easy and overclued, but possibly a good warmup.
        Test.{ level = "jt005_temple_of_the_sun_god" },                    // #vanilla #medium              Requires grind, and then maybe too easy. TODO(jt): @Design Make this better later.
        Test.{ level = "jt006_twisting_halls" },                           // #traps   #easy   #assuming    A little unfocused, but otherwise alright. Definitely not too easy. Assuming also because ambiguous otherwise.
        Test.{ level = "jt007_tenaxxuss_gullet_with_hints" },              // CUT                           This was a temporary early test.
        Test.{ level = "jt008_the_true_maze_of_the_minotaur_with_hints" }, // CUT                           This was a temporary early test.
        Test.{ level = "jt009_the_golden_mirage" },                        // CUT
        Test.{ level = "jt010_the_twin_archmages" },                       // CUT
        Test.{ level = "jt011_the_twin_archmages_rematch" },               // CUT
        Test.{ level = "jt012_the_cycle_of_calamity" },                    // CUT
        Test.{ level = "jt013_the_guardian_of_the_twin_artifacts" },       // CUT
        Test.{ level = "jt014_the_summoning_loop" },                       // CUT
        Test.{ level = "jt015_the_summoning_circuit" },                    // CUT
        Test.{ level = "jt016_the_dragon_hoards" },                        // CUT
        Test.{ level = "jt017_the_halls_of_greed" },                       // CUT
        Test.{ level = "jt018_bandits_den" },                              // CUT
        Test.{ level = "jt019_the_tomb_without_spikes" },                  // #vanilla #medium              Erased version of a spike observation puzzle.
        Test.{ level = "jt020_the_crossroads" },                           // #vanilla #medium              Erased version of a spike observation puzzle.
        Test.{ level = "jt021_the_vaults_of_order" },                      // #vanilla #medium              Erased version of a spike observation puzzle.
        Test.{ level = "jt022_the_inner_sanctum" },                        // #traps   #medium #assuming    Trap + 6-constraints decide orientations. After that some internal simulation required to see where paths can and can not go.
        Test.{ level = "jt023_the_branching_dungeon" },                    // #vanilla #medium              Erased version of a spike observation puzzle.
        Test.{ level = "jt024_treasury_of_the_underking" },                // #traps   #medium #assuming    The single trap the level currently has really does help bridge the moves to the solution.
        Test.{ level = "jt025_the_architects_gambit" },                    // #traps   #medium #assuming    TODO(jt): @Design The current trap placement gives it away a little bit too much. The ambiguous erased level is actually very pleasant (in an advanced way). Maybe we can make it not ambiguous and move it to the forest?
        Test.{ level = "jt026_the_walk_of_penance" },                      // #vanilla #medium              Erased version of a spike observation puzzle. The bottom left monster actually isn't grindy, because there's just one way it could go.
        Test.{ level = "jt027_the_house_of_lust" },                        // #vanilla #easy                Flowy, maybe has slight overabundance of clues, but not every level needs to be a gem.
        Test.{ level = "jt028_the_sunken_temple" },                        // #vanilla #easy                Flowy, has entrance sharing.
        Test.{ level = "jt029_the_flooded_tomb" },                         // #vanilla #easy                Flowy, has treasure room entrance sharing.
        Test.{ level = "jt030_the_sanctum_guardians" },                    // #vanilla #medium              Alright. Requires global reasoning and advanced deductions, but otherwise flowy.
        Test.{ level = "jt031_the_west_sewers_complex" },                  // #vanilla #medium              Alright. Has one move that Lucy would probably figure out mentally, but I had to backtrack a little.
        Test.{ level = "jt032_the_maze_of_many_perils" },                  // #vanilla #medium              Alright. I originally considered the ending grindy, but recently I managed to do it without backtracking.
        Test.{ level = "jt033_the_lost_labyrinth" },                       // #vanilla #hard                Requires advanced deductions (three monsters on the left, but only two exits are possible) and a little grind in the beginning and gives in after. I like the fact that the 7 serves two uses. However, is it too difficult if the correct advanced deductions aren't made?
        Test.{ level = "jt034_the_lost_labyrinth_v2" },                    // #vanilla #hard                Requires a lot of thinking and a little grinding on top. TODO(jt): @Design Can we make the grind go away completely?
        Test.{ level = "jt035_the_lost_labyrinth_v3" },                    // #vanilla #medium              Easier than V2, also nicer? Only had to guess once, and the dead branch was short.
        Test.{ level = "jt036_the_secret_cave" },                          // #vanilla #medium              Tough but fair, good visuals.
        Test.{ level = "jt037_the_clay_army" },                            // #vanilla #easy                Interesting? Also not completely trivial.
        Test.{ level = "jt038_the_buried_monarchs" },                      // #vanilla #medium              The beginning requires advanced deduction and then flows (or almost falls apart?).
        Test.{ level = "jt039_the_temple_of_the_frogfolk" },               // #vanilla #easy                Easy breather. Funny shape. Even our solver doesn't need to guess.
        Test.{ level = "jt040_the_temple_of_the_snake" },                  // #vanilla #medium              Not so easy for humans (requires advanced deductions), but otherwise good.
        Test.{ level = "jt041_the_overrun_mines" },                        // #vanilla #medium              Requires advanced deductions to place treasure room. After that it requires an additional advanced deduction (realizing that tiles not covering the treasure room have to be marked empty) to avoid grind.
        Test.{ level = "jt042_the_hidden_vault" },                         // #vanilla #medium              Requires treasure room advanced guess, then flows from that (except the last 3 tiles).
        Test.{ level = "jt043_the_lair_of_the_shadow_guardian" },          // #vanilla #medium              Erased version of a spike observation puzzle.
        Test.{ level = "jt044_the_lair_of_the_cornered_beast" },           // #traps   #medium #assuming    Maybe I initially could solve this without the trap clue while also not backtracking, but now I can't. Moved to assuming.
        Test.{ level = "jt045_the_antechamber" },                          // #vanilla #medium              Requires global reasoning.
        Test.{ level = "jt046_the_hollow_tomb" },                          // #traps   #medium #assuming    Significantly easier if numeric constraint + trap is utilized. Also not too hard without the trap. TODO(jt): @Design consider using the erased version.
        Test.{ level = "jt047_the_cursed_garrison" },                      // #traps   #hard   #assuming    Forces using numeric constraint + trap + treasure chest. TODO(jt): Using advanced reasoning on the left side, I managed to solve this without the expected aha.
        Test.{ level = "jt048_the_false_gate" },                           // #traps   #hard   #assuming    Minimal and beautiful. Also probably hard.
        Test.{ level = "jt049_the_unholy_pilgrimage" },                    // #vanilla #medium              Actually too easy, if the player realizes the 6-constraint pushes the treasure room around.
        Test.{ level = "jt050_spontaneous_symmetry_breaking" },            // #traps   #medium #assuming
        Test.{ level = "jt051_the_impostor_beast" },                       // #traps   #hard   #assuming    Let it be known that I actually managed do complete-deduce this, even if I forget.
        Test.{ level = "jt052_the_rift" },                                 // #vanilla #medium              Erased version of a spike observation puzzle.
        Test.{ level = "jt053_the_godstone" },                             // #vanilla #medium              Erased version of a spike observation puzzle.
        Test.{ level = "jt054_the_stronghold_of_the_false_king" },         // #vanilla #medium              Erased version of a spike assuming puzzle.
        Test.{ level = "jt055_the_illusionists_cavity" },                  // #vanilla #medium              It does have a little misdirection, I like it!
        Test.{ level = "jt056_the_grand_veziers_dilemma" },                // #crests  #hard   #assuming    Difficult and misleading. A rare puzzle where single crest knowledge actually helps determine something. Requires global crest reasoning. Doesn't need grind.
        Test.{ level = "jt057_the_materializing_path" },                   // CUT
        // jt058 got promoted to teaching material
        Test.{ level = "jt059_the_winding_catacombs" },                    // #crests  #medium #assuming    Requires global reasoning about the two paths.
        Test.{ level = "jt060" },                                          // #crests  #easy   #assuming    Easy, but alright.
        Test.{ level = "jt061_the_pale_lines" },                           // #crests  #medium #assuming    Requires realization, that if a loop connects to a single crest, that single crest must have another entrance!
        Test.{ level = "jt062_leyline_ritual" },                           // #crests  #medium #assuming    Requires realization, that the red crest needs to loop, which determines the nearby monster's exit.
        // Test.{ level = "jt063_the_geometers_crown" },                   // CUT & BROKEN
        Test.{ level = "jt064_the_geometers_shield" },                     // #crests  #medium #assuming    Once you know you have to avoid the 2-crest loop and that the 1-crests can only be capped by monsters, this is actually a little too easy. However, that initial realization is not trivial. UPDATE: No, this is actually quite hard after I had some time away from it.
        Test.{ level = "jt065_the_true_ring_of_the_geometer" },            // #crests  #medium #assuming
        Test.{ level = "jt066_the_new_threads_of_the_geometer" },          // #crests  #easy   #assuming    TODO(jt): @Design Not sure if this level is very good. The upper crests mostly help because they help you place walls because of the 5-constraint.
        Test.{ level = "jt067_the_narrow_path" },                          // #crests  #hard   #assuming    The solver says this is somewhat hard (and ambiguous without crests). Otherwise, crest knowledge helps. Re-evaluate once this isn't fresh in my mind.
        Test.{ level = "jt068_the_geometers_castle" },                     // #combi   #hard   #assuming    Quite hard, but good!
        Test.{ level = "jt069_the_ripples_of_peril" },                     // #combi   #medium #assuming

        Test.{ level = "endgame001_the_cathedral_of_preserved_heroes" },   // #vanilla #easy                Easy one to get comfortable with the larger size.
        Test.{ level = "endgame002_the_consult" },                         // #traps   #medium              This took me some time to solve, and required a lot of advanced deductions and path reasoning, and even then I had to resort to a shallow backtrack in a few places. (UPDATE: Solved without backtracking now)
        Test.{ level = "endgame003" },                                     // #traps   TODO                 Is this one good enough?
        Test.{ level = "endgame004_fortress_of_the_lost" },                // #traps   #easy                But requires a guess on the three top traps? (The backtracking is shallow either way)
        Test.{ level = "endgame005" },                                     // #traps   TODO                 Is this one good enough?
        Test.{ level = "endgame006_the_tree_of_decay" },                   // #traps   #easy   CUT          Cut, because we made a 10x10 version.
        Test.{ level = "endgame007_the_light_bending_coffers" },           // #crests  #medium              The solver is having a really bad time on this one, but it just doesn't know how to play this game. I like the visuals!
        Test.{ level = "endgame008_the_world_tree" },                      // #combi   #medium
        Test.{ level = "endgame009_the_decaying_roots" },                  // #traps   #medium              The solver things this is easy.
        Test.{ level = "endgame010_the_lost_vaults" },                     // #combi   #easy
        Test.{ level = "endgame011_the_sealed_warren" },                   // #crests  #easy
        Test.{ level = "endgame012_the_descent" },                         // #crests  #easy                TODO(jt): @Design This one isn't very strong.
        Test.{ level = "endgame013_the_gnostic_court" },                   // #crests  TODO

        // Test.{ level = "teachingcrests001_valley_trail" },              // CUT
        Test.{ level = "teachingcrests002_valley_trail",   solutions =  4 },
        // Test.{ level = "teachingcrests003_valley_trail" },              // CUT
        Test.{ level = "teachingcrests004_valley_trail",   solutions =  2 },
        // Test.{ level = "teachingcrests005_valley_trail" },              // CUT
        // Test.{ level = "teachingcrests006_valley_trail" },              // CUT
        // Test.{ level = "teachingcrests007_valley_trail" },              // CUT                           Required backtracking
        // Test.{ level = "teachingcrests008_valley_trail" },              // CUT & BROKEN
        Test.{ level = "teachingcrests009_valley_trail",   solutions =  5 },
        // Test.{ level = "teachingcrests010_valley_trail" },              // CUT
        Test.{ level = "teachingcrests011_valley_trail",   solutions = 26 }, // TODO(jt): These 26 solutions are not hand-verified.
        // Test.{ level = "teachingcrests012_valley_trail" },              // CUT & BROKEN
        // Test.{ level = "teachingcrests013_valley_trail" },              // CUT & BROKEN
        // Test.{ level = "teachingcrests014_valley_trail" },              // CUT & BROKEN
        // Test.{ level = "teachingcrests015_valley_trail" },              // CUT & BROKEN
        // Test.{ level = "teachingcrests016_valley_trail" },              // CUT & BROKEN
        Test.{ level = "teachingcrests017_valley_trail" },
        Test.{ level = "teachingcrests018_valley_trail" },
        // Test.{ level = "teachingcrests019_valley_trail" },              // CUT
        Test.{ level = "teachingcrests020_valley_trail",   solutions = 35 }, // TODO(jt): These 35 solutions are not hand-verified.
        Test.{ level = "teachingcrests021_valley_trail",   solutions = 12 },
        // Test.{ level = "teachingcrests022_valley_trail" },              // CUT
        // Test.{ level = "teachingcrests023_valley_trail" },              // CUT
        // Test.{ level = "teachingcrests024_valley_trail" },              // CUT
        // Test.{ level = "teachingcrests025_valley_trail" },              // CUT
        Test.{ level = "teachingcrests026_valley_trials" },
        Test.{ level = "teachingcrests027_valley_trail" },
        Test.{ level = "teachingcrests028_valley_trail" },
        Test.{ level = "teachingcrests029_valley_trail" },
        Test.{ level = "teachingcrests030_valley_trail" },
        Test.{ level = "teachingcrests031_valley_trail" },
        Test.{ level = "teachingcrests032_valley_trail" },

        Test.{ level = "teachingtraps001_the_tomb_of_many_spikes" },
        Test.{ level = "teachingtraps002_the_tomb_of_many_spikes" },
        Test.{ level = "teachingtraps003_the_tomb_of_many_spikes" },
        Test.{ level = "teachingtraps004_the_tomb_of_many_spikes" },
        Test.{ level = "teachingtraps005_the_tomb_of_many_spikes" },
        Test.{ level = "teachingtraps006_the_tomb_of_many_spikes" },

        // TODO(jt): @Correctness Some levels in here require capabilities=.NONE. See
        // #mark_empty_tiles_adjacent_to_bottlenecks.
        Test.{ level = "teaching001a_mysterious_cavelets", solutions = 1,  capabilities = .NONE },
        Test.{ level = "teaching001b_mysterious_cavelets", solutions = 3,  capabilities = .NONE },
        Test.{ level = "teaching001c_mysterious_cavelets", solutions = 1,  capabilities = .NONE },
        Test.{ level = "teaching002_mysterious_cavelets",  solutions = 6,  capabilities = .NONE },
        Test.{ level = "teaching003_mysterious_cavelets",  solutions = 4,  capabilities = .NONE },
        Test.{ level = "teaching004_mysterious_cavelets",  solutions = 4,  capabilities = .NONE },
        Test.{ level = "teaching005_mysterious_cavelets",  solutions = 2,  capabilities = .NONE },
        Test.{ level = "teaching006_mysterious_cavelets",  solutions = 11, capabilities = .NONE },
        Test.{ level = "teaching007a_mysterious_cavelets", solutions = 1,  capabilities = .NONE },
        Test.{ level = "teaching007b_mysterious_cavelets", solutions = 1,  capabilities = .NONE },
        Test.{ level = "teaching007c_mysterious_cavelets", solutions = 4,  capabilities = .NONE },
        Test.{ level = "teaching007d_mysterious_cavelets", solutions = 1,  capabilities = .NONE },
        Test.{ level = "teaching008_mysterious_cavelets",  solutions = 6,  capabilities = .NONE },
        Test.{ level = "teaching009_mysterious_cavelets",  solutions = 4,  capabilities = .NONE },
        Test.{ level = "teaching010a_mysterious_cavelets", solutions = 9,  capabilities = .NONE },
        Test.{ level = "teaching010b_mysterious_cavelets", solutions = 1,  capabilities = .NONE },
        Test.{ level = "teaching010c_mysterious_cavelets", solutions = 3,  capabilities = .NONE },

        Test.{ level = "teaching011a_mysterious_caves",    solutions = 1,  capabilities = .NONE },
        Test.{ level = "teaching011b_mysterious_caves",    solutions = 3,  capabilities = .NONE },
        Test.{ level = "teaching011c_mysterious_caves",    solutions = 3,  capabilities = .NONE },
        Test.{ level = "teaching011d_mysterious_caves",    solutions = 3,  capabilities = .NONE },
        // TODO(jt): @Bug The solver finds two bad solutions here. For some reason it puts a wall in
        // the treasure room center (and doesn't later reject them).
        Test.{ level = "teaching013_mysterious_caves",    solutions = 2,  capabilities = .ALL /* Because .NONE was too slow. */ },
        Test.{ level = "teaching014_mysterious_caves",    solutions = 2,  capabilities = .ALL /* Because .NONE was too slow. */ },
        // TODO(jt): @Bug Solver bug... Does not find the good solution, but finds a bad one!
        Test.{ level = "teaching015_mysterious_caves",    solutions = 2,  capabilities = .NONE },

        Test.{ level = "teaching021_mysterious_caverns",  solutions = 1 },
        Test.{ level = "teaching022_mysterious_caverns",  solutions = 1 },
        Test.{ level = "teaching023_mysterious_caverns",  solutions = 1 },
        Test.{ level = "teaching024_mysterious_caverns",  solutions = 1 },
    ];

    global_deduction_stats: Deduction_Solve_Stats;
    for TESTS {
        auto_release_temp();
        solve_and_print_board_from_file(
            platform,
            *failures,
            *warnings,
            *global_deduction_stats,
            it.capabilities,
            tprint("data/puzzles/%.txt", it.level),
            it.check,
            it.check_flags,
            it.solutions,
            -1,
        );
    }

    time_end := current_time_monotonic();

    print("SUCCEEDED: %, FAILED: % (% WARNINGS)\n\n", TESTS.count - failures.count, failures.count, warnings.count);

    if failures.count {
        print("Failures:\n");
        for failures {
            print("%\n", it);
        }
        print("\n");
    }

    if warnings.count {
        print("Warnings:\n");
        for warnings {
            print("%\n", it);
        }
        print("\n");
    }

    print("Deduction stats across the entire run:\n");
    print("deduction_max_depth                                                  = %\n", global_deduction_stats.max_depth);
    print("deduction_applies_for_mark_remaining_walls                           = %\n", global_deduction_stats.applies_for_mark_remaining_walls);
    print("deduction_applies_for_mark_remaining_monster_adjacent_tiles          = %\n", global_deduction_stats.applies_for_mark_remaining_monster_adjacent_tiles);
    print("deduction_applies_for_mark_remaining_pool_wall                       = %\n", global_deduction_stats.applies_for_mark_remaining_pool_wall);
    print("deduction_applies_for_mark_remaining_dead_ends                       = %\n", global_deduction_stats.applies_for_mark_remaining_dead_ends);
    print("deduction_applies_for_mark_remaining_disconnected_subgraphs          = %\n", global_deduction_stats.applies_for_mark_remaining_disconnected_subgraphs);
    print("deduction_applies_for_mark_some_treasure_room_tiles                  = %\n", global_deduction_stats.applies_for_mark_some_treasure_room_tiles);
    print("deduction_applies_for_mark_some_walls_between_treasure_room_and_clue = %\n", global_deduction_stats.applies_for_mark_some_walls_between_treasure_room_and_clue);
    print("deduction_applies_for_mark_empty_tiles_adjacent_to_bottlenecks       = %\n", global_deduction_stats.applies_for_mark_empty_tiles_adjacent_to_bottlenecks);


    print("Solver tests took % seconds\n\n", to_float64_seconds(time_end) - to_float64_seconds(time_start));
}

right_pad :: (str: string, size: s64) -> string /* Temporary_Storage */ {
    builder: String_Builder;
    append(*builder, str);
    for str.count..size-1 {
        append(*builder, #char " ");
    }
    return builder_to_string(*builder,, temp);
}
