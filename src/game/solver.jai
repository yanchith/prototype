Deduction_Solve_Stats :: struct {
    max_depth:                                                  s64;
    applies_for_mark_remaining_walls:                           s64;
    applies_for_mark_remaining_monster_adjacent_tiles:          s64;
    applies_for_mark_remaining_pool_wall:                       s64;
    applies_for_mark_remaining_dead_ends:                       s64;
    applies_for_mark_remaining_disconnected_subgraphs:          s64;
    applies_for_mark_some_treasure_room_tiles:                  s64;
    applies_for_mark_some_walls_between_treasure_room_and_clue: s64;
    applies_for_mark_empty_tiles_adjacent_to_bottlenecks:       s64;
}

Solve_Stats :: struct {
    // Because deduction skips ahead, we can reach the same solution multiple times. To know actual
    // solution count, we need to deduplicate.
    solution_path_count: s64;

    // TODO(jt): Add metric that tracks the deepest false branch (since the depth where it diverged
    // from the true branch). To do this, we must know what the true path is (or what the final true
    // state looks like). Most good puzzles would keep that metric low (given all deductions are
    // applied, etc.)
    backtrack_guess_count: s64;
    backtrack_max_depth:   s64;

    deduction: Deduction_Solve_Stats;

    terminated_due_to_limit: bool;
}

Deduction_Capabilities :: enum_flags {
    NONE :: 0;

    BASIC    :: 0x01;
    ADVANCED :: 0x02;
    SECRET   :: 0x04;

    ALL :: Deduction_Capabilities.BASIC | .ADVANCED | .SECRET;
}


solve :: (board: Board, deduction_capabilities := Deduction_Capabilities.ALL, max_backtrack := -1, $verbose := false, $very_verbose := false) -> [..] Board, Solve_Stats {
    // 1) Run deduction solver. If it fails, the board is unsolvable. If it succeeds, return
    //    true. Otherwise, fall back to the backtracking solver.
    //
    // 2) For each backtracking solver decision, attempt running the deduction solver again. If it
    //    fails, revert to checkpoint. If it succeeds, return true. Otherwise, fall back to
    //    backtracking solver to make a decision again.
    //
    // Good puzzles utilize just the deduction solver (if it were perfect), or a minimum amount of
    // guesses with quickly verifiable dead ends. We will want to score each puzzle to prefilter for
    // manual curation.

    if max_backtrack == -1 {
        max_backtrack = 1_000_000;
    }

    solutions: [..] Board;
    solutions.allocator = context.allocator;

    stats: Solve_Stats;

    State :: struct {
        board:         Board;
        board_deduced: bool;
        index: s64;
    }

    stack: [..] State;
    stack.allocator = temp;

    array_add(*stack, .{ board_copy(board,, temp), false, 0 });
    stats.backtrack_max_depth = 1;

    //
    // TODO(jt): Albeit the rules of the puzzle may make it less likely, this solver can visit a
    // single state multiple times. Add a hash table for state deduplication (and early branch
    // kill)? First maybe just count how many times this happens.
    //

    while stack.count {
        state := peek_pointer(stack);

        if state.index >= state.board.tiles.count {
            pop(*stack);
            #if verbose {
                if stack.count {
                    print("FALLBACK (end of branch)\n");
                    #if very_verbose {
                        s := peek_pointer(stack);
                        board_print(s.board);
                    }
                }
            }

            continue;
        }

        if stats.backtrack_guess_count >= max_backtrack {
            stats.terminated_due_to_limit = true;
            break;
        }

        #if SOLVER_VERBOSE {
            if stats.backtrack_guess_count % 10000 == 0 {
                print("% GUESSES TAKEN\n", stats.backtrack_guess_count);
            }
        }

        if !state.board_deduced {
            check := solve_deductively(*state.board, deduction_capabilities, *stats, verbose, very_verbose);
            state.board_deduced = true;

            if check == {
                case .OPEN; // Continue to guessing code below.
                case .SOLVED; {
                    stats.solution_path_count += 1;
                    b := board_copy(state.board,, context.allocator);
                    board_unsolve_except_walls(*b);
                    array_add_if_unique_board(*solutions, b);

                    // Continue to guessing code below.
                }
                case .UNSOLVABLE; {
                    pop(*stack);
                    #if verbose {
                        if stack.count {
                            print("FALLBACK\n");
                            #if very_verbose {
                                s := peek_pointer(stack);
                                board_print(s.board);
                            }
                        } else {
                            print("DONE\n");
                        }
                    }

                    continue;
                }
            }
        }

        index := state.index;
        state.index += 1;

        // TODO(jt): @Speed seek to first guessable tile directly here.
        tile := state.board.tiles[index];
        if tile_is_clue(tile)    continue; // Nothing to decide on clue tiles.
        if tile_is_marked(tile)  continue; // Pre-filled by deduction, or read-only and filled by design.

        stats.backtrack_guess_count += 1;

        // Make two guesses at once: one where we mark the current index as wall (primary), and one
        // where we mark it empty (fallback).
        //
        // The primary guess will be branched off, if we don't detect a contradiction straight away.
        //
        // The fallback guess is written to the current state.
        new_board := board_copy(state.board,, temp);
        new_board.tiles[index]   |= .MARKED_WALL;
        state.board.tiles[index] |= .MARKED_EMPTY;
        state.board_deduced = false; // Make sure we deduce the fallback branch when we come back to it.

        #if verbose {
            print("GUESS\n");
            #if very_verbose {
                board_print(new_board);
            }
        }

        check := board_check(new_board);

        // If we are open-ended after taking a guess, try running the deductive solver to see if it can finish the job.
        if check == .OPEN {
            check = solve_deductively(*new_board, deduction_capabilities, *stats, verbose, very_verbose);
        }

        if check == {
            case .OPEN; {
                // If the state is still open, we need to explore it further. Push it onto the stack!
                array_add(*stack, .{ new_board, true, index + 1 });
                if stack.count > stats.backtrack_max_depth {
                    stats.backtrack_max_depth = stack.count;
                }
            }

            case .SOLVED; {
                // If the state is solved, we still need to explore it further. Push it onto the stack! (Explanation below)
                //
                // In Dungeons & Diagrams rules as usually experienced, it is almost impossible to
                // find another solution by placing more walls into an already solved
                // puzzle. However, in really degenerate cases, and depending on how a single empty
                // cell in a filled puzzle is interpreted, or how a fully filled puzzle is
                // interpreted, it MAY very well be possible to arrive at another solution by
                // placing more walls. Example:
                //
                // If this is valid         ...      then so is this!
                //
                // ###                               ###
                // ###                      ->       ###
                // ##,                               ###
                //
                // Yes, both cases above are technically undefined by the OG ruleset. Originally,
                // this solver followed that ruleset very closely (and used to NOT push the new
                // state here), but as it moved towards deciding the extreme edge cases in the
                // levels without numeric constraints, I had to make a call and say that this is in
                // theory possible.
                array_add(*stack, .{ new_board, true, index + 1 });

                stats.solution_path_count += 1;
                b := board_copy(new_board,, context.allocator);
                board_unsolve_except_walls(*b);
                array_add_if_unique_board(*solutions, b);
            }


            // If the primary guess lead to a contradiction, Do not push it onto the stack. We will
            // continue with the fallback guess the next time through the loop.
            case .UNSOLVABLE; {
                #if verbose {
                    if stack.count {
                        print("FALLBACK (unpushed)\n");
                        #if very_verbose {
                            s := peek_pointer(stack);
                            board_print(s.board);
                        }
                    }
                }
            }
        }
    }

    return solutions, stats;
}

solve_deductively :: (board: *Board, capabilities: Deduction_Capabilities, stats: *Solve_Stats, $verbose := false, $very_verbose := false) -> Board_Check {
    if capabilities == .NONE {
        return board_check(board);
    }

    #if verbose {
        print("DEDUCTION START\n");
        #if very_verbose {
            board_print(board);
        }
    }

    deduction_depth := 0;
    while true {
        deduction_depth += 1;

        // TODO(jt): Change this to true for builds where we don't need to explain step by step, or
        // consider removing altogether (and keeping it false).
        FUSE :: false;

        //
        // TODO(jt): Add following deduction steps, because otherwise the solver often misranks levels
        //
        // - Finish treasure room layout: If we have all the empty tiles (including the exit), we
        //   know the rest are walls, and can mark them as such.
        //
        // - Complete L shapes in treasure room layout.
        //
        // - We know that if a path going straight is blocked, it must turn right or left (or both)
        //   at the end, otherwise it would be a dead end. If it is also blocked on the right or
        //   left, we know the other direction must continue the path.
        //
        // - 2-wide dead ends are still dead ends. It requires 3-wide for a corridor form such that
        //   it can escape. We used to have a special-case deduction that just checked a subset of
        //   this on the level edges. It did not help much, but I use the general idea all the time
        //   when solving, so maybe a better implementation would be more helpful?
        //
        // - Global connectivity reasoning coupled with numeric constraints: "I know there has to be
        //   a path here, and I know it does not lead through the monsters, because they would block
        //   it with the dead ends they produce" or "I know there has to be a path here, but it must
        //   not lead through the treasure room, because that is a dead end".
        //
        // - If there's two monsters with a single space next to each other, they are very likely
        //   separated by a wall (M#M), unless the puzzle is so small that this is basically the
        //   entire puzzle, and there is no other connectivity to enforece.
        //

        if capabilities & .BASIC && mark_remaining_walls(board, FUSE) {
            stats.deduction.applies_for_mark_remaining_walls += 1;

            #if verbose {
                print("APPLY mark_remaining_walls\n");
                #if very_verbose {
                    board_print(board);
                }
            }

            assert(board_is_valid(board));
            continue;
        }

        if capabilities & .BASIC && mark_remaining_monster_adjacent_tiles(board, FUSE) {
            stats.deduction.applies_for_mark_remaining_monster_adjacent_tiles += 1;

            #if verbose {
                print("APPLY mark_remaining_monster_adjacent_tiles\n");
                #if very_verbose {
                    board_print(board);
                }
            }

            assert(board_is_valid(board));
            continue;
        }

        if capabilities & .BASIC && mark_remaining_pool_wall(board, FUSE) {
            stats.deduction.applies_for_mark_remaining_pool_wall += 1;

            #if verbose {
                print("APPLY mark_remaining_pool_wall\n");
                #if very_verbose {
                    board_print(board);
                }
            }

            assert(board_is_valid(board));
            continue;
        }

        if capabilities & .BASIC && mark_remaining_dead_ends(board, FUSE) {
            stats.deduction.applies_for_mark_remaining_dead_ends += 1;

            #if verbose {
                print("APPLY mark_remaining_dead_ends\n");
                #if very_verbose {
                    board_print(board);
                }
            }

            assert(board_is_valid(board));
            continue;
        }

        if capabilities & .ADVANCED && mark_remaining_disconnected_subgraphs(board, FUSE) {
            stats.deduction.applies_for_mark_remaining_disconnected_subgraphs += 1;

            #if verbose {
                print("APPLY mark_remaining_disconnected_subgraphs\n");
                #if very_verbose {
                    board_print(board);
                }
            }

            assert(board_is_valid(board));
            continue;
        }

        if capabilities & .ADVANCED && mark_some_treasure_room_tiles(board, FUSE) {
            stats.deduction.applies_for_mark_some_treasure_room_tiles += 1;

            #if verbose {
                print("APPLY mark_some_treasure_room_tiles\n");
                #if very_verbose {
                    board_print(board);
                }
            }

            assert(board_is_valid(board));
            continue;
        }

        if capabilities & .ADVANCED && mark_some_walls_between_treasure_room_and_clue(board, FUSE) {
            stats.deduction.applies_for_mark_some_walls_between_treasure_room_and_clue += 1;

            #if verbose {
                print("APPLY mark_some_walls_between_treasure_room_and_clue\n");
                #if very_verbose {
                    board_print(board);
                }
            }

            assert(board_is_valid(board));
            continue;
        }

        if capabilities & .ADVANCED && mark_empty_tiles_adjacent_to_bottlenecks(board, FUSE, capabilities) {
            stats.deduction.applies_for_mark_empty_tiles_adjacent_to_bottlenecks += 1;

            #if verbose {
                print("APPLY mark_empty_tiles_adjacent_to_bottlenecks\n");
                #if very_verbose {
                    board_print(board);
                }
            }

            assert(board_is_valid(board));
            continue;
        }

        // TODO(jt): Add mark_remaining_trap_adjacent_tiles (Deduction_Capabilities.SECRET)

        break;
    }

    if deduction_depth > stats.deduction.max_depth {
        stats.deduction.max_depth = deduction_depth;
    }

    #if verbose {
        print("DEDUCTION END\n");
        #if very_verbose {
            board_print(board);
        }
    }

    return board_check(board);
}

#scope_file

mark_remaining_walls :: (board: *Board, $fuse := false) -> bool {
    modified := false;

    for x: 0..board.xsize - 1 {
        if board.xconstraints[x] < 0 {
            continue;
        }

        clue_count         := 0;
        marked_wall_count  := 0;
        marked_empty_count := 0;
        unmarked_count     := 0;
        for y: 0..board.ysize - 1 {
            tile := board_get(board, x, y);
            if      tile & .MARKED_WALL                             marked_wall_count += 1;
            else if tile & (.MARKED_EMPTY | .MARKED_TREASURE_ROOM)  marked_empty_count += 1;
            else if tile_is_clue(tile)                              clue_count += 1;
            else                                                    unmarked_count += 1;
        }

        if unmarked_count == 0 {
            continue;
        }

        max_count          := board.ysize;
        target_wall_count  := board.xconstraints[x];
        target_empty_count := max_count - target_wall_count - clue_count;

        missing_wall_count  := target_wall_count - marked_wall_count;
        missing_empty_count := target_empty_count - marked_empty_count;

        if missing_wall_count == unmarked_count {
            for y: 0..board.ysize - 1 {
                tile := board_get_pointer(board, x, y);
                if tile.* == .NONE {
                    tile.* |= .MARKED_WALL;
                    modified = true;
                }
            }
        } else if missing_empty_count == unmarked_count {
            for y: 0..board.ysize - 1 {
                tile := board_get_pointer(board, x, y);
                if tile.* == .NONE {
                    tile.* |= .MARKED_EMPTY;
                    modified = true;
                }
            }
        }

        if !fuse && modified {
            return true;
        }
    }

    for y: 0..board.ysize - 1 {
        if board.yconstraints[y] < 0 {
            continue;
        }

        clue_count         := 0;
        marked_wall_count  := 0;
        marked_empty_count := 0;
        unmarked_count     := 0;
        for x: 0..board.xsize - 1 {
            tile := board_get(board, x, y);
            if      tile & .MARKED_WALL                             marked_wall_count += 1;
            else if tile & (.MARKED_EMPTY | .MARKED_TREASURE_ROOM)  marked_empty_count += 1;
            else if tile_is_clue(tile)                              clue_count += 1;
            else                                                    unmarked_count += 1;
        }

        if unmarked_count == 0 {
            continue;
        }

        max_count          := board.xsize;
        target_wall_count  := board.yconstraints[y];
        target_empty_count := max_count - target_wall_count - clue_count;

        missing_wall_count  := target_wall_count - marked_wall_count;
        missing_empty_count := target_empty_count - marked_empty_count;

        if missing_wall_count == unmarked_count {
            for x: 0..board.xsize - 1 {
                tile := board_get_pointer(board, x, y);
                if tile.* == .NONE {
                    tile.* |= .MARKED_WALL;
                    modified = true;
                }
            }
        } else if missing_empty_count == unmarked_count {
            for x: 0..board.xsize - 1 {
                tile := board_get_pointer(board, x, y);
                if tile.* == .NONE {
                    tile.* |= .MARKED_EMPTY;
                    modified = true;
                }
            }
        }

        if !fuse && modified {
            return true;
        }
    }

    return modified;
}

mark_remaining_monster_adjacent_tiles :: (board: *Board, $fuse := false) -> bool {
    SEARCH_DIRECTIONS :: IVector2.[.{ -1, 0 }, .{ 1, 0 }, .{ 0, -1 }, .{ 0, 1 }];

    modified := false;

    for y: 0..board.ysize - 1 {
        for x: 0..board.xsize - 1 {
            tile := board_get(board, x, y);
            if tile & .CLUE_MONSTER {
                // See if we find a marked empty tile around it (clues are also considered marked empty)...
                marked_empty_x     := -1;
                marked_empty_y     := -1;
                marked_empty_count := 0;
                for SEARCH_DIRECTIONS {
                    test_x := x + it.x;
                    test_y := y + it.y;

                    if !board_in_bounds(board, test_x, test_y) {
                        continue;
                    }

                    test_tile := board_get(board, test_x, test_y);
                    if test_tile & .MARKED_EMPTY || tile_is_clue(test_tile) {
                        marked_empty_x = test_x;
                        marked_empty_y = test_y;
                        marked_empty_count += 1;
                    }
                }

                // If there's multiple tiles marked empty, the board is unsolvable, so we don't
                // bother making this deduction. A later check will catch and report this.
                if marked_empty_count > 1 {
                    continue;
                }

                if marked_empty_count {
                    // If we did, all the other tiles are walls!
                    for SEARCH_DIRECTIONS {
                        test_x := x + it.x;
                        test_y := y + it.y;

                        if test_x == marked_empty_x && test_y == marked_empty_y {
                            continue;
                        }

                        if !board_in_bounds(board, test_x, test_y) {
                            continue;
                        }

                        maybe_wall_tile := board_get_pointer(board, test_x, test_y);

                        // In theory, the board may be completely incorrect, so we also check if
                        // there's a clue in the tile we are about to write to.
                        if !tile_is_marked(maybe_wall_tile.*) && !tile_is_clue(maybe_wall_tile.*) {
                            maybe_wall_tile.* |= .MARKED_WALL;
                            modified = true;
                        }
                    }

                    if !fuse && modified {
                        return true;
                    }
                } else {
                    // Otherwise, see if there's three walls (explicit or implicit).
                    wall_count := 0;
                    for SEARCH_DIRECTIONS {
                        test_x := x + it.x;
                        test_y := y + it.y;

                        if !board_in_bounds(board, test_x, test_y) {
                            wall_count += 1;
                            continue;
                        }

                        test_tile := board_get(board, test_x, test_y);
                        if test_tile & .MARKED_WALL {
                            wall_count += 1;
                        }
                    }

                    if wall_count == 3 {
                        // If so, mark the remaining unoccupied tile empty!
                        for SEARCH_DIRECTIONS {
                            test_x := x + it.x;
                            test_y := y + it.y;
                            if board_in_bounds(board, test_x, test_y) {
                                maybe_empty_tile := board_get_pointer(board, test_x, test_y);
                                if maybe_empty_tile.* == .NONE {
                                    maybe_empty_tile.* |= .MARKED_EMPTY;
                                    modified = true;
                                    if !fuse {
                                        return true;
                                    }
                                }
                            }
                        }
                    }
                }

            }
        }
    }

    return modified;
}

mark_remaining_pool_wall :: (board: *Board, $fuse := false) -> bool {
    if board.xsize < 2 || board.ysize < 2 {
        return false;
    }

    modified := false;

    for y: 0..board.ysize - 2 {
        for x: 0..board.xsize - 2 {
            t00 := board_get_pointer(board, x    , y);
            t10 := board_get_pointer(board, x + 1, y);
            t01 := board_get_pointer(board, x    , y + 1);
            t11 := board_get_pointer(board, x + 1, y + 1);

            c00 := tile_is_clue(t00.*);
            c10 := tile_is_clue(t10.*);
            c01 := tile_is_clue(t01.*);
            c11 := tile_is_clue(t11.*);

            w00 := t00.* & .MARKED_WALL;
            w10 := t10.* & .MARKED_WALL;
            w01 := t01.* & .MARKED_WALL;
            w11 := t11.* & .MARKED_WALL;

            if w00 || w10 || w01 || w11 {
                continue;
            }

            r00 := t00.* & .MARKED_TREASURE_ROOM;
            r10 := t10.* & .MARKED_TREASURE_ROOM;
            r01 := t01.* & .MARKED_TREASURE_ROOM;
            r11 := t11.* & .MARKED_TREASURE_ROOM;

            if r00 || r10 || r01 || r11 {
                continue;
            }

            could_be_treasure_room := false;
            DMIN: s32: -2;
            DMAX: s32:  2;
            for dy: DMIN..DMAX {
                for dx: DMIN..DMAX {
                    test_x := x + dx;
                    test_y := y + dy;

                    if board_in_bounds(board, test_x, test_y) {
                        test_tile := board_get(board, test_x, test_y);
                        if test_tile & .CLUE_TREASURE {
                            could_be_treasure_room = true;
                        }
                    }
                }
            }

            if could_be_treasure_room {
                continue;
            }

            e00 := t00.* & .MARKED_EMPTY || c00;
            e10 := t10.* & .MARKED_EMPTY || c10;
            e01 := t01.* & .MARKED_EMPTY || c01;
            e11 := t11.* & .MARKED_EMPTY || c11;

            empty_count := 0;
            if e00  empty_count += 1;
            if e10  empty_count += 1;
            if e01  empty_count += 1;
            if e11  empty_count += 1;

            if empty_count != 3 {
                continue;
            }

            if !e11 {
                t11.* |= .MARKED_WALL;
                modified = true;
            } else if !e01 {
                t01.* |= .MARKED_WALL;
                modified = true;
            } else if !e10 {
                t10.* |= .MARKED_WALL;
                modified = true;
            } else if !e00 {
                t00.* |= .MARKED_WALL;
                modified = true;
            }

            if !fuse && modified {
                return true;
            }
        }
    }

    return modified;
}

// TODO(jt): Can we make this detect larger dead ends? Or does mark_remaining_pool_wall handle that?
mark_remaining_dead_ends :: (board: *Board, $fuse := false) -> bool {
    SEARCH_DIRECTIONS :: IVector2.[.{ -1, 0 }, .{ 1, 0 }, .{ 0, -1 }, .{ 0, 1 }];

    modified := false;

    for y: 0..board.ysize - 1 {
        for x: 0..board.xsize - 1 {
            tile := board_get_pointer(board, x, y);
            if tile.* == .NONE {
                wall_count := 0;
                for SEARCH_DIRECTIONS {
                    test_x := x + it.x;
                    test_y := y + it.y;

                    if board_in_bounds(board, test_x, test_y) && board_get(board, test_x, test_y) & .MARKED_WALL {
                        wall_count += 1;
                    }
                }

                // NOTE(jt): Not sure if we can get a walled-in segment, but if we do, just fill it
                // in (because there is no monster inside). This means that the following 3x4 map is
                // always unsolvable, because we place a wall in the treasure room exit:
                //
                // #.#
                // ...
                // ...
                // .T.
                //
                if wall_count >= 3 {
                    tile.* |= .MARKED_WALL;
                    modified = true;

                    if !fuse {
                        return true;
                    }
                }
            }
        }
    }

    return modified;
}

mark_remaining_disconnected_subgraphs :: (board: *Board, $fuse := false) -> bool {
    SEARCH_DIRECTIONS :: IVector2.[.{ -1, 0 }, .{ 1, 0 }, .{ 0, -1 }, .{ 0, 1 }];

    stack: [..] IVector2;
    stack.allocator = temp;

    visited: [..] bool;
    visited.allocator = temp;
    array_resize(*visited, board.tiles.count);

    subgraph_count := 0;
    dead_subgraph_starting_tiles: [..] IVector2;
    dead_subgraph_starting_tiles.allocator = temp;

    // Walls disconnect subgraphs. Monsters also disconnect subgraphs in an emergent way, because
    // they have to be in a dead end, surrounded by walls.
    tile_cuts_graphs :: inline (tile: Tile) -> bool {
        if tile & .MARKED_WALL   return true;
        if tile & .CLUE_MONSTER  return true;
        return false;
    }

    get_visit_index :: (x: s32, y: s32) -> s64 #expand {
        return y * board.xsize + x;
    }

    for y: 0..board.ysize - 1 {
        for x: 0..board.xsize - 1 {
            tile := board_get(board, x, y);

            if tile_cuts_graphs(tile) {
                continue;
            }

            if !visited[get_visit_index(x, y)] {
                liveness_signs := 0;

                array_add(*stack, .{ x, y });

                while stack.count > 0 {
                    position := pop(*stack);

                    if visited[get_visit_index(position.x, position.y)] {
                        continue;
                    }
                    visited[get_visit_index(position.x, position.y)] = true;

                    {
                        // Check that there is something (nonzero) reachable that is not just a
                        // graph cutting tile. Note that the graph-cutting check is implicit,
                        // because we never push a graph cutting tile on the stack.
                        maybe_live_tile := board_get(board, position.x, position.y);
                        if maybe_live_tile != .NONE {
                            liveness_signs += 1;
                        }
                    }

                    for SEARCH_DIRECTIONS {
                        visit_x := position.x + it.x;
                        visit_y := position.y + it.y;

                        if board_in_bounds(board, visit_x, visit_y) {
                            if !visited[get_visit_index(visit_x, visit_y)] {
                                visit_tile := board_get(board, visit_x, visit_y);
                                if !tile_cuts_graphs(visit_tile) {
                                    array_add(*stack, .{ visit_x, visit_y });
                                }
                            }
                        }
                    }
                }

                subgraph_count += 1;
                if liveness_signs == 0 {
                    array_add(*dead_subgraph_starting_tiles, .{ x, y });
                }
            }
        }
    }

    assert(stack.count == 0);
    array_view_fill_zero(visited);

    modified := false;

    if subgraph_count > 1 && subgraph_count > dead_subgraph_starting_tiles.count {
        for dead_subgraph_starting_tiles {
            assert(!visited[get_visit_index(it.x, it.y)]);

            array_add(*stack, .{ it.x, it.y });

            while stack.count > 0 {
                position := pop(*stack);

                if visited[get_visit_index(position.x, position.y)] {
                    continue;
                }
                visited[get_visit_index(position.x, position.y)] = true;

                tile := board_get_pointer(board, position.x, position.y);
                tile.* |= .MARKED_WALL;

                for SEARCH_DIRECTIONS {
                    visit_x := position.x + it.x;
                    visit_y := position.y + it.y;

                    if board_in_bounds(board, visit_x, visit_y) {
                        if !visited[get_visit_index(visit_x, visit_y)] {
                            visit_tile := board_get(board, visit_x, visit_y);
                            if !tile_cuts_graphs(visit_tile) {
                                array_add(*stack, .{ visit_x, visit_y });
                            }
                        }
                    }
                }
            }

            modified = true;
            if !fuse {
                return true;
            }
        }
    }

    return modified;
}

mark_some_treasure_room_tiles :: (board: *Board, $fuse := false) -> bool {
    Offset :: struct {
        search: IVector2;
        mark:   IVector2;
    }

    SEARCH_AND_MARK_OFFSETS :: Offset.[
            .{ search = .{ -1,  0 }, mark = .{  1,  0 } },
            .{ search = .{ -1,  0 }, mark = .{  2,  0 } },
            .{ search = .{  1,  0 }, mark = .{ -1,  0 } },
            .{ search = .{  1,  0 }, mark = .{ -2,  0 } },
            .{ search = .{  0, -1 }, mark = .{  0,  1 } },
            .{ search = .{  0, -1 }, mark = .{  0,  2 } },
            .{ search = .{  0,  1 }, mark = .{  0, -1 } },
            .{ search = .{  0,  1 }, mark = .{  0, -2 } },

            .{ search = .{ -2,  0 }, mark = .{  1,  0 } },
            .{ search = .{  2,  0 }, mark = .{ -1,  0 } },
            .{ search = .{  0, -2 }, mark = .{  0,  1 } },
            .{ search = .{  0,  2 }, mark = .{  0, -1 } },
    ];

    modified := false;

    for y: 0..board.ysize - 1 {
        for x: 0..board.xsize - 1 {
            tile := board_get(board, x, y);
            if tile & .CLUE_TREASURE {
                for SEARCH_AND_MARK_OFFSETS {
                    test_x := x + it.search.x;
                    test_y := y + it.search.y;

                    // Anything that is not allowed in a treasure room (out of bounds, wall,
                    // monster, any nontreasure clue) make us attempt the mark, and so does seeing
                    // another treasure mark.
                    attempt_mark := !board_in_bounds(board, test_x, test_y);
                    if !attempt_mark {
                        test_tile := board_get(board, test_x, test_y);
                        attempt_mark = tile_is_clue(test_tile) || test_tile & .MARKED_WALL;
                    }

                    if attempt_mark {
                        mark_x := x + it.mark.x;
                        mark_y := y + it.mark.y;
                        if board_in_bounds(board, mark_x, mark_y) {
                            mark_tile := board_get_pointer(board, mark_x, mark_y);

                            if !tile_is_marked(mark_tile.*) {
                                assert(mark_tile.* == .NONE);
                                if !(mark_tile.* & .MARKED_TREASURE_ROOM) {
                                    mark_tile.* |= (.MARKED_EMPTY | .MARKED_TREASURE_ROOM);
                                    modified = true;
                                    if !fuse {
                                        return true;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    return modified;
}

mark_some_walls_between_treasure_room_and_clue :: (board: *Board, $fuse := false) -> bool {
    Offset :: struct {
        search: IVector2;
        mark:   IVector2;
    }

    SEARCH_AND_MARK_OFFSETS :: Offset.[
            .{ search = .{ -2,  0 }, mark = .{ -1,  0 } },
            .{ search = .{  2,  0 }, mark = .{  1,  0 } },
            .{ search = .{  0, -2 }, mark = .{  0, -1 } },
            .{ search = .{  0,  2 }, mark = .{  0,  1 } },
    ];

    modified := false;

    for y: 0..board.ysize - 1 {
        for x: 0..board.xsize - 1 {
            tile := board_get(board, x, y);
            if tile & (.CLUE_TREASURE | .MARKED_TREASURE_ROOM) {
                for SEARCH_AND_MARK_OFFSETS {
                    test_x := x + it.search.x;
                    test_y := y + it.search.y;

                    if !board_in_bounds(board, test_x, test_y) {
                        continue;
                    }

                    test_tile := board_get(board, test_x, test_y);
                    if test_tile & .CLUE_MONSTER || (tile == .CLUE_TREASURE && test_tile & .CLUE_TREASURE) {
                        mark_x := x + it.mark.x;
                        mark_y := y + it.mark.y;
                        mark_tile := board_get_pointer(board, mark_x, mark_y);

                        if mark_tile.* == .NONE {
                            mark_tile.* |= .MARKED_WALL;
                            modified = true;
                            if !fuse {
                                return true;
                            }
                        }
                    }
                }
            }
        }
    }

    return modified;
}

// TODO(jt): @Correctness #mark_empty_tiles_adjacent_to_bottlenecks This deduction does incorrect
// things somtimes - a single empty tile is a degenerate correct solution, but this deduction pushes
// it into an unsolvable space. We should restrict the applicability somehow. (Maybe by checking
// whether we can find a path to a clue)
mark_empty_tiles_adjacent_to_bottlenecks :: (board: *Board, $fuse := false, capabilities: Deduction_Capabilities) -> bool {
    SEARCH_DIRECTIONS :: IVector2.[.{ -1, 0 }, .{ 1, 0 }, .{ 0, -1 }, .{ 0, 1 }];

    modified := false;

    for y: 0..board.ysize - 1 {
        for x: 0..board.xsize - 1 {
            tile := board_get(board, x, y);

            consider_tile := tile & .MARKED_EMPTY;
            if capabilities & .SECRET {
                // At the time of writing, this is equivalent to tile_is_secret_clue(t), but that
                // may not remain that way, so we spell it out explicitly.
                consider_tile |= tile & .CLUE_TRAP;
                consider_tile |= tile & .CLUE_MIRROR_NE;
                consider_tile |= tile & .CLUE_MIRROR_NW;
                consider_tile |= tile & .CLUE_MIRROR_SW;
                consider_tile |= tile & .CLUE_MIRROR_SE;
            }

            if consider_tile {
                wall_count := 0;
                for SEARCH_DIRECTIONS {
                    test_x := x + it.x;
                    test_y := y + it.y;

                    if !board_in_bounds(board, test_x, test_y) {
                        wall_count += 1;
                        continue;
                    }

                    test_tile := board_get(board, test_x, test_y);
                    if test_tile & .MARKED_WALL {
                        wall_count += 1;
                    }
                }

                if wall_count == 2 {
                    for SEARCH_DIRECTIONS {
                        test_x := x + it.x;
                        test_y := y + it.y;

                        if !board_in_bounds(board, test_x, test_y) {
                            continue;
                        }

                        test_tile := board_get_pointer(board, test_x, test_y);
                        if test_tile.* == .NONE {
                            test_tile.* |= .MARKED_EMPTY;
                            modified = true;
                        }
                    }

                    if !fuse && modified {
                        return true;
                    }
                }
            }
        }
    }

    return modified;
}

#scope_file

// TODO(jt): @Cleanup Copied from Basic and modified. Use generic array_find once #poke_name starts
// working, or the replacement for poke_name is added.
array_find_board :: (array: [] Board, item: Board) -> bool, s64 {
    for array if it == item return true, it_index;
    return false, -1;  // Not found.
}

// TODO(jt): @Cleanup Copied from Basic and modified. Use generic array_add_if_unique once
// #poke_name starts working, or the replacement for poke_name is added.
array_add_if_unique_board :: (array: *[..] Board, item: Board) -> bool, s64 {   // Return true if newly added; also return index.
    // @Compiler: We should not need explicit dereference here, but auto-dereference doesn't work in some cases.
    found, index := array_find_board(array.*, item);
    if found return false, index;

    array_add(array, item);
    return true, array.count-1;
}
