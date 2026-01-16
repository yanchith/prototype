TILE_POSITION_INVALID :: IVector2.{ -1, -1 };

Tile :: enum_flags u16 {
    NONE :: 0;

    CLUE_MONSTER  :: 0x01;
    CLUE_TREASURE :: 0x02;

    CLUE_TRAP     :: 0x04;

    CLUE_CREST_SINGLE :: 0x10;
    CLUE_CREST_DOUBLE :: 0x20;
    CLUE_CREST_TRIPLE :: 0x40;
    CLUE_CREST_ALT    :: 0x80;

    CLUE_MIRROR_NE :: 0x0100;
    CLUE_MIRROR_NW :: 0x0200;
    CLUE_MIRROR_SW :: 0x0400;
    CLUE_MIRROR_SE :: 0x0800;

    MARKED_WALL          :: 0x1000;
    MARKED_EMPTY         :: 0x2000;
    MARKED_TREASURE_ROOM :: 0x4000; // Implies MARKED_EMPTY, but it should also be explicitly set.

    READ_ONLY :: 0x8000;
}

tile_is_valid :: inline (tile: Tile) -> bool {
    if tile & (.CLUE_CREST_SINGLE | .CLUE_CREST_DOUBLE | .CLUE_CREST_TRIPLE) {
        // Crests can combine as follows:
        //
        // - Only one of single/double/triple can ever be present.
        // - A monster or treasure can optionally be present, but not both.
        // - The alternative crest can optionally be present.

        if tile == tile & (.CLUE_MONSTER | .CLUE_CREST_SINGLE | .CLUE_CREST_ALT)   return true;
        if tile == tile & (.CLUE_MONSTER | .CLUE_CREST_DOUBLE | .CLUE_CREST_ALT)   return true;
        if tile == tile & (.CLUE_MONSTER | .CLUE_CREST_TRIPLE | .CLUE_CREST_ALT)   return true;
        if tile == tile & (.CLUE_TREASURE | .CLUE_CREST_SINGLE | .CLUE_CREST_ALT)  return true;
        if tile == tile & (.CLUE_TREASURE | .CLUE_CREST_DOUBLE | .CLUE_CREST_ALT)  return true;
        if tile == tile & (.CLUE_TREASURE | .CLUE_CREST_TRIPLE | .CLUE_CREST_ALT)  return true;

        return false;
    }

    if tile & .CLUE_MONSTER    return tile == .CLUE_MONSTER;
    if tile & .CLUE_TREASURE   return tile == .CLUE_TREASURE;

    if tile & .CLUE_TRAP       return tile == .CLUE_TRAP;

    if tile & .CLUE_MIRROR_NE  return tile == .CLUE_MIRROR_NE;
    if tile & .CLUE_MIRROR_NW  return tile == .CLUE_MIRROR_NW;
    if tile & .CLUE_MIRROR_SW  return tile == .CLUE_MIRROR_SW;
    if tile & .CLUE_MIRROR_SE  return tile == .CLUE_MIRROR_SE;

    if tile & .MARKED_WALL     return tile == tile & (.MARKED_WALL | .READ_ONLY);
    if tile & .MARKED_EMPTY    return tile == tile & (.MARKED_EMPTY | .MARKED_TREASURE_ROOM | .READ_ONLY);

    return tile == .NONE; // An unmarked tile must not be READ_ONLY... but maybe we can relax that?
}

tile_is_clue :: inline (tile: Tile) -> bool {
    if tile & .CLUE_MONSTER       return true;
    if tile & .CLUE_TREASURE      return true;

    if tile & .CLUE_TRAP          return true;

    if tile & .CLUE_CREST_SINGLE  return true;
    if tile & .CLUE_CREST_DOUBLE  return true;
    if tile & .CLUE_CREST_TRIPLE  return true;

    if tile & .CLUE_MIRROR_NE     return true;
    if tile & .CLUE_MIRROR_NW     return true;
    if tile & .CLUE_MIRROR_SW     return true;
    if tile & .CLUE_MIRROR_SE     return true;

    return false;
}

tile_is_secret_clue :: inline (tile: Tile) -> bool {
    if tile & .CLUE_TRAP          return true;

    if tile & .CLUE_CREST_SINGLE  return true;
    if tile & .CLUE_CREST_DOUBLE  return true;
    if tile & .CLUE_CREST_TRIPLE  return true;
    if tile & .CLUE_CREST_ALT     return true;

    if tile & .CLUE_MIRROR_NE     return true;
    if tile & .CLUE_MIRROR_NW     return true;
    if tile & .CLUE_MIRROR_SW     return true;
    if tile & .CLUE_MIRROR_SE     return true;

    return false;
}

tile_is_mirror :: inline (tile: Tile) -> bool {
    if tile & .CLUE_MIRROR_NE  return true;
    if tile & .CLUE_MIRROR_NW  return true;
    if tile & .CLUE_MIRROR_SW  return true;
    if tile & .CLUE_MIRROR_SE  return true;

    return false;
}

tile_is_marked :: inline (tile: Tile) -> bool {
    if tile & .MARKED_WALL           return true;
    if tile & .MARKED_EMPTY          return true;
    if tile & .MARKED_TREASURE_ROOM  return true;

    return false;
}

tile_is_reflected_in_mirrors :: inline (tile: Tile) -> bool {
    if tile & .CLUE_MONSTER      return true;
    if tile & .CLUE_TREASURE     return true;

    if tile & .CLUE_TRAP         return true;

    if tile & .CLUE_CREST_SINGLE return true;
    if tile & .CLUE_CREST_DOUBLE return true;
    if tile & .CLUE_CREST_TRIPLE return true;

    if tile & .CLUE_MIRROR_NE    return true;
    if tile & .CLUE_MIRROR_NW    return true;
    if tile & .CLUE_MIRROR_SW    return true;
    if tile & .CLUE_MIRROR_SE    return true;

    if tile & .MARKED_WALL       return true;

    return false;
}

tile_get_mirror_view_directions :: inline (mirror: Tile) -> IVector2, IVector2 {
    assert(tile_is_mirror(mirror));

    if mirror & .CLUE_MIRROR_NE  return IVECTOR2_POSITIVE_X, IVECTOR2_NEGATIVE_Y;
    if mirror & .CLUE_MIRROR_NW  return IVECTOR2_NEGATIVE_X, IVECTOR2_NEGATIVE_Y;
    if mirror & .CLUE_MIRROR_SW  return IVECTOR2_NEGATIVE_X, IVECTOR2_POSITIVE_Y;
    if mirror & .CLUE_MIRROR_SE  return IVECTOR2_POSITIVE_X, IVECTOR2_POSITIVE_Y;

    return IVECTOR2_ZERO, IVECTOR2_ZERO;
}

tile_reflect_mirror_incoming_view_direction :: inline (mirror: Tile, incoming: IVector2) -> success: bool, reflected: IVector2 {
    direction1, direction2 := tile_get_mirror_view_directions(mirror);

    if -incoming == direction1  return true, direction2;
    if -incoming == direction2  return true, direction1;

    return false, IVECTOR2_ZERO;
}

tile_erase_secret_clue :: (tile: *Tile) {
    was_secret := tile_is_secret_clue(tile.*);

    tile.* &= ~.CLUE_TRAP;

    tile.* &= ~.CLUE_CREST_SINGLE;
    tile.* &= ~.CLUE_CREST_DOUBLE;
    tile.* &= ~.CLUE_CREST_TRIPLE;
    tile.* &= ~.CLUE_CREST_ALT;

    tile.* &= ~.CLUE_MIRROR_NE;
    tile.* &= ~.CLUE_MIRROR_NW;
    tile.* &= ~.CLUE_MIRROR_SW;
    tile.* &= ~.CLUE_MIRROR_SE;

    // Some secret clues can combine with monsters or chests. Only turn the tile to read-only marked
    // empty, if there is nothing left.
    if was_secret && tile.* == .NONE {
        tile.* |= .MARKED_EMPTY;
        tile.* |= .READ_ONLY;
    }
}

tile_print :: (b: *String_Builder, tile: Tile) {
    if      tile & .CLUE_MONSTER                 print(b, ifx tile & .CLUE_CREST_SINGLE then "m" else "M");
    else if tile & .CLUE_TREASURE                print(b, ifx tile & .CLUE_CREST_SINGLE then "t" else "T");

    else if tile & .CLUE_TRAP                    print(b, "X");

    // The treasure/monster combination with crests is already be handled upstream in the chain.
    else if tile & .CLUE_CREST_SINGLE            print(b, ifx tile & .CLUE_CREST_ALT then "1" else "a");
    else if tile & .CLUE_CREST_DOUBLE            print(b, ifx tile & .CLUE_CREST_ALT then "2" else "b");
    else if tile & .CLUE_CREST_TRIPLE            print(b, ifx tile & .CLUE_CREST_ALT then "3" else "c");

    else if tile & .CLUE_MIRROR_NE               print(b, "Z");
    else if tile & .CLUE_MIRROR_NW               print(b, "C");
    else if tile & .CLUE_MIRROR_SW               print(b, "E");
    else if tile & .CLUE_MIRROR_SE               print(b, "Q");

    else if tile & .MARKED_WALL                  print(b, ifx tile & .READ_ONLY then "@" else "#");

    else if tile & .MARKED_TREASURE_ROOM         print(b, "o"); // TODO(jt): @Cleanup We shouldn't be parsing this!
    else if tile & .MARKED_EMPTY                 print(b, ifx tile & .READ_ONLY then ";" else ",");
    else                                         print(b, ".");
}

tile_parse :: (c: u8) -> success: bool, tile: Tile {
    t: Tile;

    if c == {
        case #char "M"; t = .CLUE_MONSTER;
        case #char "m"; t = .CLUE_MONSTER | .CLUE_CREST_SINGLE;
        case #char "T"; t = .CLUE_TREASURE;
        case #char "t"; t = .CLUE_TREASURE | .CLUE_CREST_SINGLE;

        case #char "X"; t = .CLUE_TRAP;

        case #char "a"; t = .CLUE_CREST_SINGLE;
        case #char "b"; t = .CLUE_CREST_DOUBLE;
        case #char "c"; t = .CLUE_CREST_TRIPLE;
        case #char "1"; t = .CLUE_CREST_SINGLE | .CLUE_CREST_ALT;
        case #char "2"; t = .CLUE_CREST_DOUBLE | .CLUE_CREST_ALT;
        case #char "3"; t = .CLUE_CREST_TRIPLE | .CLUE_CREST_ALT;

        case #char "Z"; t = .CLUE_MIRROR_NE;
        case #char "C"; t = .CLUE_MIRROR_NW;
        case #char "E"; t = .CLUE_MIRROR_SW;
        case #char "Q"; t = .CLUE_MIRROR_SE;

        case #char "#"; t = .MARKED_WALL;
        case #char "@"; t = .MARKED_WALL | .READ_ONLY;
        case #char "."; // No-op
        case #char ","; t = .MARKED_EMPTY;
        case #char ";"; t = .MARKED_EMPTY | .READ_ONLY;
        case #char "o"; t = .MARKED_EMPTY | .MARKED_TREASURE_ROOM;
        case;           return false, t;
    }

    return true, t;
}

// TODO(jt): @Cleanup consider making a for expansion over Board that gives (tile, x, y) and
// iterates in memory order and apply that in places.

Board :: struct {
    // TODO(jt): Change to IVector2?
    xsize: s32;
    ysize: s32;

    // Tiles and constraints are resizable arrays, so that we can resize the board, but otherwise we
    // effectively only use them as array views.
    xconstraints: [..] s32;
    yconstraints: [..] s32;

    tiles: [..] Tile;
}

operator == :: (a: Board, b: Board) -> bool {
    if a.xsize != b.xsize  return false;
    if a.ysize != b.ysize  return false;
    if !array_equals_s32(a.xconstraints, b.xconstraints)  return false;
    if !array_equals_s32(a.yconstraints, b.yconstraints)  return false;
    if !array_equals_tile(a.tiles, b.tiles)               return false;

    return true;
}

board_init :: (board: *Board, xsize: s32, ysize: s32) {
    board.xsize = xsize;
    board.ysize = ysize;

    // TODO(jt): #malloc @Memory Decide what arena do these array go in. For now this is the context allocator, which is usually malloc.
    array_resize(*board.xconstraints, xsize);
    array_resize(*board.yconstraints, ysize);
    array_resize(*board.tiles, xsize * ysize);
}

// TODO(jt): #array_reset @Cleanup Remove following comment and harmonize with JAI, once it itself
// harmonizes.
//
// IC has notes in the Array and Hash_Table module talking about inconsistent clearing data and
// freeing memory.
//
// Current JAI has array_reset (frees memory), array_reset_keeping_memory (keeps memory), and
// table_reset (keeprs memory).
//
// In ICs comments, he suggest two conventions:
//
// 1) _reset functions always keep memory and _reset_and_free_memory functions also
//    free. In current code, table_reset doesn't free (good), but array_reset does (bad).
//
// 2) _clear functions keep memory and _reset functions free it.
//
// In here, we are following (1) for now, and we have to keep in mind that array_reset does not
// follow this convention.
board_reset :: (board: *Board) {
    // Reset array to make count 0. Resize will re-initialize each array element.
    array_reset_keeping_memory(*board.tiles);
    array_resize(*board.tiles, board.xsize * board.ysize);
}

// TODO(jt): @Cleanup This is a new overload, and there are many places where it could be used.
board_in_bounds :: inline (board: Board, position: IVector2) -> bool {
    return board_in_bounds(board, position.x, position.y);
}

board_in_bounds :: inline (board: Board, x: s32, y: s32) -> bool {
    return x >= 0 && x < board.xsize && y >= 0 && y < board.ysize;
}

// TODO(jt): @Cleanup This is a new overload, and there are many places where it could be used.
board_get :: inline (board: Board, position: IVector2) -> Tile {
    return board_get(board, position.x, position.y);
}

board_get :: inline (board: Board, x: s32, y: s32) -> Tile {
    assert(x >= 0 && x < board.xsize);
    assert(y >= 0 && y < board.ysize);

    index := y * board.xsize + x;
    return board.tiles[index];
}

// TODO(jt): @Cleanup This is a new overload, and there are many places where it could be used.
board_get_pointer :: inline (board: *Board, position: IVector2) -> *Tile {
    return board_get_pointer(board, position.x, position.y);
}

board_get_pointer :: inline (board: *Board, x: s32, y: s32) -> *Tile {
    assert(x >= 0 && x < board.xsize);
    assert(y >= 0 && y < board.ysize);

    index := y * board.xsize + x;
    return *board.tiles[index];
}

board_is_valid :: (board: Board) -> bool {
    for board.tiles {
        if !tile_is_valid(it)  {
            return false;
        }
    }

    return true;
}

board_has_all_required_numeric_constraints :: (board: Board) -> bool {
    for board.xconstraints  if it < 0  return false;
    for board.yconstraints  if it < 0  return false;
    return true;
}

board_copy :: (src: Board) -> Board {
    dst: Board;
    dst.xsize = src.xsize;
    dst.ysize = src.ysize;

    // TODO(jt): #malloc @Memory Decide what arena do these array go in. For now this is the context
    // allocator, which is usually malloc.
    array_copy(*dst.xconstraints, src.xconstraints);
    array_copy(*dst.yconstraints, src.yconstraints);
    array_copy(*dst.tiles, src.tiles);

    return dst;
}

board_parse :: (s: string, unsolve := true, unsolve_except_walls := false) -> result: Board, success: bool {
    board: Board;
    success := board_parse(*board, s, unsolve, unsolve_except_walls);
    return board, success;
}

board_parse :: (b: *Board, _s: string, unsolve := true, unsolve_except_walls := false) -> bool {
    // TODO(jt): @Correctness Handle end of input.
    // TODO(jt): @Correctness Do not crash on incorrectly set level size.

    s := _s;

    xsize: s64;
    ysize: s64;
    success: bool;

    s = eat_spaces_and_newlines(s);
    xsize, success, s = string_to_int(s);
    if !success  return false;

    s = eat_spaces_and_newlines(s);
    ysize, success, s = string_to_int(s);
    if !success  return false;

    s = eat_spaces_and_newlines(s);
    compute_constraints := false;
    supress_constraints := false;

    if s[0] == #char "*" {
        compute_constraints = true;
        s = advance(s, 1);
    } else if s[0] == #char "!" {
        supress_constraints = true;
        s = advance(s, 1);
    }

    do_parse_constraints := !compute_constraints && !supress_constraints;

    if do_parse_constraints {
        if xsize > 9 || ysize > 9 {
            return false;
        }
    }

    // TODO(jt): Parse xsize and ysize as s32 instead of casting.
    board_init(b, cast(s32, xsize), cast(s32, ysize));

    if do_parse_constraints {
        s = eat_spaces_and_newlines(s);
        for x: 0..b.xsize - 1 {
            if s[0] == {
                case #char "0"; b.xconstraints[x] = 0;
                case #char "1"; b.xconstraints[x] = 1;
                case #char "2"; b.xconstraints[x] = 2;
                case #char "3"; b.xconstraints[x] = 3;
                case #char "4"; b.xconstraints[x] = 4;
                case #char "5"; b.xconstraints[x] = 5;
                case #char "6"; b.xconstraints[x] = 6;
                case #char "7"; b.xconstraints[x] = 7;
                case #char "8"; b.xconstraints[x] = 8;
                case #char "9"; b.xconstraints[x] = 9;
                case;           return false;
            }

            s = advance(s, 1);
        }
    }

    s = eat_spaces_and_newlines(s);
    for y: 0..b.ysize - 1 {
        if do_parse_constraints {
            s = eat_spaces_and_newlines(s);
            if s[0] == {
                case #char "0"; b.yconstraints[y] = 0;
                case #char "1"; b.yconstraints[y] = 1;
                case #char "2"; b.yconstraints[y] = 2;
                case #char "3"; b.yconstraints[y] = 3;
                case #char "4"; b.yconstraints[y] = 4;
                case #char "5"; b.yconstraints[y] = 5;
                case #char "6"; b.yconstraints[y] = 6;
                case #char "7"; b.yconstraints[y] = 7;
                case #char "8"; b.yconstraints[y] = 8;
                case #char "9"; b.yconstraints[y] = 9;
                case;           return false;
            }

            s = advance(s, 1);
        }

        s = eat_spaces_and_newlines(s);
        for x: 0..b.xsize - 1 {
            tile := board_get_pointer(b, x, y);

            success, t := tile_parse(s[0]);
            if !success {
                return false;
            }
            tile.* = t;

            s = advance(s, 1);
        }
    }

    if compute_constraints {
        for x: 0..b.xsize - 1  b.xconstraints[x] = board_count_walls_in_column(b, x);
        for y: 0..b.ysize - 1  b.yconstraints[y] = board_count_walls_in_row(b, y);

    } else if supress_constraints {
        for * b.xconstraints  it.* = -1;
        for * b.yconstraints  it.* = -1;
    }

    if unsolve {
        board_unsolve(b);
    }

    if unsolve_except_walls {
        board_unsolve_except_walls(b);
    }

    return true;
}

board_print :: (b: *String_Builder, board: Board, print_constraints := true) {
    if print_constraints {
        print(b, "  ");
        for board.xconstraints {
            if it < 0 {
                print(b, "!");
            } else {
                print(b, "%", it);
            }
        }
        print(b, "\n");
    }

    for y: 0..board.ysize - 1 {
        if print_constraints {
            if board.yconstraints[y] < 0 {
                print(b, "! ");
            } else {
                print(b, "% ", board.yconstraints[y]);
            }
        }

        for x: 0..board.xsize - 1 {
            tile := board_get(board, x, y);
            tile_print(b, tile);
        }

        print(b, "\n");
    }

    print(b, "\n");
}

board_print :: (board: Board) -> bytes_printed: s64 {
    b: String_Builder;
    b.allocator = temp;

    board_print(*b, board);
    written := write_builder(*b);

    return written;
}

board_unsolve :: (board: *Board) {
    for * board.tiles {
        if !(it.* & .READ_ONLY) {
            it.* &= ~.MARKED_WALL;
            it.* &= ~.MARKED_EMPTY;
            it.* &= ~.MARKED_TREASURE_ROOM;
        }
    }
}

board_unsolve_except_walls :: (board: *Board) {
    for * board.tiles {
        if !(it.* & .READ_ONLY) {
            it.* &= ~.MARKED_EMPTY;
            it.* &= ~.MARKED_TREASURE_ROOM;
        }
    }
}

board_erase_secret_clues :: (board: *Board) {
    for * board.tiles {
        tile_erase_secret_clue(it);
    }
}

board_count_walls_in_row :: (board: Board, row: s32) -> s32 {
    wall_count: s32 = 0;

    for x: 0..board.xsize - 1 {
        tile := board_get(board, x, row);
        if tile & .MARKED_WALL {
            wall_count += 1;
        }
    }

    return wall_count;
}

board_count_walls_in_column :: (board: Board, column: s32) -> s32 {
    wall_count: s32 = 0;

    for y: 0..board.ysize - 1 {
        tile := board_get(board, column, y);
        if tile & .MARKED_WALL {
            wall_count += 1;
        }
    }

    return wall_count;
}

Hint_Flags :: enum_flags u32 {
    NONE :: 0;

    CONSTRAINTS  :: 0x01;
    MONSTERS     :: 0x02;
    DEAD_ENDS    :: 0x04;
    CONNECTIVITY :: 0x08;
    POOLS        :: 0x10;
    TREASURES    :: 0x20;

    TRAPS  :: 0x0100;
    CRESTS :: 0x0200;

    ALL :: Hint_Flags.CONSTRAINTS | .MONSTERS | .DEAD_ENDS | .CONNECTIVITY | .POOLS | .TREASURES | .TRAPS | .CRESTS;
    OG  :: Hint_Flags.CONSTRAINTS | .MONSTERS | .DEAD_ENDS | .CONNECTIVITY | .POOLS | .TREASURES;
}

Board_Check :: enum u32 {
    OPEN       :: 0;
    SOLVED     :: 1;
    UNSOLVABLE :: 2;
}

Board_Check_Flags :: enum_flags u16 {
    NONE :: 0;

    CONSTRAINTS_OPEN  :: 0x01;
    CONNECTIVITY_OPEN :: 0x02;
    MONSTERS_OPEN     :: 0x04;
    TREASURES_OPEN    :: 0x08;
    POOLS_OPEN        :: 0x10;
    TRAPS_OPEN        :: 0x20;
    CRESTS_OPEN       :: 0x40;
    MIRRORS_OPEN      :: 0x80;

    CONSTRAINTS_UNSOLVABLE  :: 0x0100;
    CONNECTIVITY_UNSOLVABLE :: 0x0200;
    MONSTERS_UNSOLVABLE     :: 0x0400;
    TREASURES_UNSOLVABLE    :: 0x0800;
    POOLS_UNSOLVABLE        :: 0x1000;
    TRAPS_UNSOLVABLE        :: 0x2000;
    CRESTS_UNSOLVABLE       :: 0x4000;
    MIRRORS_UNSOLVABLE      :: 0x8000;

    ALL_CONSTRAINTS   :: Board_Check_Flags.CONSTRAINTS_OPEN  | .CONSTRAINTS_UNSOLVABLE;
    ALL_CONNECTIVITY  :: Board_Check_Flags.CONNECTIVITY_OPEN | .CONNECTIVITY_UNSOLVABLE;
    ALL_MONSTERS      :: Board_Check_Flags.MONSTERS_OPEN     | .MONSTERS_UNSOLVABLE;
    ALL_TREASURES     :: Board_Check_Flags.TREASURES_OPEN    | .TREASURES_UNSOLVABLE;
    ALL_POOLS         :: Board_Check_Flags.POOLS_OPEN        | .POOLS_UNSOLVABLE;
    ALL_TRAPS         :: Board_Check_Flags.TRAPS_OPEN        | .TRAPS_UNSOLVABLE;
    ALL_CRESTES       :: Board_Check_Flags.CRESTS_OPEN       | .CRESTS_UNSOLVABLE;
    ALL_MIRRORS       :: Board_Check_Flags.MIRRORS_OPEN      | .MIRRORS_UNSOLVABLE;

    ALL_OPEN       :: Board_Check_Flags.CONSTRAINTS_OPEN | .CONNECTIVITY_OPEN | .MONSTERS_OPEN | .TREASURES_OPEN | .POOLS_OPEN | .TRAPS_OPEN | .CRESTS_OPEN | .MIRRORS_OPEN;
    ALL_UNSOLVABLE :: Board_Check_Flags.CONSTRAINTS_UNSOLVABLE | .CONNECTIVITY_UNSOLVABLE | .MONSTERS_UNSOLVABLE | .TREASURES_UNSOLVABLE | .POOLS_UNSOLVABLE | .TRAPS_UNSOLVABLE | .CRESTS_UNSOLVABLE | .MIRRORS_UNSOLVABLE;
}

Board_Check_Hint :: struct {
    type:     Type;
    position: IVector2;

    Type :: enum u32 {
        CLUE         :: 0;
        DEAD_END     :: 1;
        POOL         :: 2; // POOL is reported only for top left tile of the pool.
        CONNECTIVITY :: 3;
    }
}

board_check :: (board: Board, hint_flags := Hint_Flags.NONE) -> Board_Check, Board_Check_Flags, [..] Board_Check_Hint {
    assert(board_is_valid(board));

    // Besides just checking whether the board is (or still can be) solved, we also optionally
    // return the list of integer positions that are not satisfied. These are used to visually
    // report failing clues.
    //
    // If asked to report the unsolved positions, the various check_ procedures inhibit their early
    // returns, if any, to report the complete list for the category.
    hints: [..] Board_Check_Hint;
    hints.allocator = context.allocator;

    // If the caller passes temp as the context allocator, we reserve space for all hints ahead of
    // time, in case the future me decides to auto_release_temp inside the checking procedures.
    if hint_flags {
        array_reserve(*hints, board.xsize * board.ysize);
    }

    flags:       Board_Check_Flags;

    if board_check_monsters(board, ifx hint_flags & (.MONSTERS | .DEAD_ENDS) then *hints, hint_flags) == {
        case .OPEN;       flags |= .MONSTERS_OPEN;
        case .UNSOLVABLE; flags |= .MONSTERS_UNSOLVABLE;
    }

    treasure_room_positions_for_pool_detection: [..] IVector2;
    treasure_room_positions_for_pool_detection.allocator = temp;
    if board_check_treasures(board, *treasure_room_positions_for_pool_detection, ifx hint_flags & .TREASURES then *hints) == {
        case .OPEN;       flags |= .TREASURES_OPEN;
        case .UNSOLVABLE; flags |= .TREASURES_UNSOLVABLE;
    }

    if board_check_traps(board, ifx hint_flags & .TRAPS then *hints) == {
        case .OPEN;       flags |= .TRAPS_OPEN;
        case .UNSOLVABLE; flags |= .TRAPS_UNSOLVABLE;
    }

    if board_check_crests(board, ifx hint_flags & .CRESTS then *hints) == {
        case .OPEN;       flags |= .CRESTS_OPEN;
        case .UNSOLVABLE; flags |= .CRESTS_UNSOLVABLE;
    }

    if board_check_mirrors(board) == {
        case .OPEN;       flags |= .MIRRORS_OPEN;
        case .UNSOLVABLE; flags |= .MIRRORS_UNSOLVABLE;
    }

    if board_check_pools(board, treasure_room_positions_for_pool_detection, ifx hint_flags & .POOLS then *hints) == {
        case .OPEN;       flags |= .POOLS_OPEN;
        case .UNSOLVABLE; flags |= .POOLS_UNSOLVABLE;
    }

    if board_check_connectivity(board, ifx hint_flags & .CONNECTIVITY then *hints) == {
        case .OPEN;       flags |= .CONNECTIVITY_OPEN;
        case .UNSOLVABLE; flags |= .CONNECTIVITY_UNSOLVABLE;
    }

    if board_check_constraints(board, ifx hint_flags & .CONSTRAINTS then *hints) == {
        case .OPEN;       flags |= .CONSTRAINTS_OPEN;
        case .UNSOLVABLE; flags |= .CONSTRAINTS_UNSOLVABLE;
    }

    if flags & .ALL_UNSOLVABLE  return .UNSOLVABLE, flags, hints;
    if flags & .ALL_OPEN        return .OPEN,       flags, hints;

    return .SOLVED, flags, hints;
}

board_check_constraints :: (board: Board, hints: *[..] Board_Check_Hint = null) -> Board_Check {
    xconstraints: [..] s32;
    xconstraints.allocator = temp;
    array_resize(*xconstraints, board.xsize);

    yconstraints: [..] s32;
    yconstraints.allocator = temp;
    array_resize(*yconstraints, board.ysize);

    unsolvable := false;

    for y: 0..board.ysize - 1 {
        for x: 0..board.xsize - 1 {
            tile := board_get(board, x, y);

            if tile & .MARKED_WALL {
                xconstraints[x] += 1;
                yconstraints[y] += 1;
            }

            if board.xconstraints[x] >= 0 {
                if xconstraints[x] > board.xconstraints[x] {
                    if !hints {
                        return .UNSOLVABLE;
                    }

                    unsolvable = true;
                }
            }

            if board.yconstraints[y] >= 0 {
                if yconstraints[y] > board.yconstraints[y] {
                    if !hints {
                        return .UNSOLVABLE;
                    }

                    unsolvable = true;
                }
            }
        }
    }

    if hints {
        for 0..board.xsize - 1 {
            // TODO(jt): @Hack Because we know where we display numeric constraints, we know where
            // to add the flashing effect, but this is a little bit fragile.
            if board.xconstraints[it] >= 0 && xconstraints[it] != board.xconstraints[it] {
                array_add(hints, .{ .CLUE, .{ it, -1 } });
            };
        }

        for 0..board.ysize - 1 {
            // TODO(jt): @Hack Because we know where we display numeric constraints, we know where
            // to add the flashing effect, but this is a little bit fragile.
            if board.yconstraints[it] >= 0 && yconstraints[it] != board.yconstraints[it] {
                array_add(hints, .{ .CLUE, .{ -1, it } });
            }
        }
    }

    if unsolvable {
        return .UNSOLVABLE;
    }

    solved := true;

    for x: 0..board.xsize - 1 {
        if board.xconstraints[x] >= 0 && board.xconstraints[x] != xconstraints[x] {
            solved = false;
        }
    }
    for y: 0..board.ysize - 1 {
        if board.yconstraints[y] >= 0 && board.yconstraints[y] != yconstraints[y] {
            solved = false;
        }
    }

    if solved {
        return .SOLVED;
    }

    return .OPEN;
}

board_check_monsters :: (board: Board, hints: *[..] Board_Check_Hint = null, hint_flags: Hint_Flags) -> Board_Check {
    SEARCH_DIRECTIONS :: IVector2.[.{ -1, 0 }, .{ 1, 0 }, .{ 0, -1 }, .{ 0, 1 }];

    count_surrounding_walls :: (board: Board, x: s32, y: s32) -> s64 {
        count := 0;
        for SEARCH_DIRECTIONS {
            test_x := x + it.x;
            test_y := y + it.y;

            if board_in_bounds(board, test_x, test_y) {
                test_tile := board_get(board, test_x, test_y);
                if test_tile & .MARKED_WALL {
                    assert(!tile_is_clue(test_tile));
                    count += 1;
                }
            } else {
                count += 1;
            }
        }

        return count;
    }

    unsolvable := false;
    open       := false;

    for y: 0..board.ysize - 1 {
        for x: 0..board.xsize - 1 {
            tile := board_get(board, x, y);

            if tile & .CLUE_MONSTER {
                wall_count := count_surrounding_walls(board, x, y);
                if wall_count > 3 {
                    // Walled-in monster is always incorrect.
                    if !hints {
                        return .UNSOLVABLE;
                    }

                    if hint_flags & .MONSTERS {
                        array_add(hints, .{ .CLUE, .{ x, y }});
                    }

                    unsolvable = true;
                } else if wall_count < 3 {
                    if !hints {
                        return .OPEN;
                    }

                    if hint_flags & .MONSTERS {
                        array_add(hints, .{ .CLUE, .{ x, y }});
                    }

                    open = true;
                }
            } else if !(tile & .MARKED_WALL) {
                wall_count := count_surrounding_walls(board, x, y);
                if wall_count == 3 {
                    // The following code was commented out. It was correct in most (all?)
                    // nonartificial puzzles, but in the absolute edge cases, such as 2x1 board, it
                    // killed off a branch that still had a chance to become solved (either by
                    // leaving a single empty tile, or by filling the entire board).
                    //
                    // if tile & .MARKED_EMPTY || tile_is_clue(tile) {
                    //     // Dead end without a monster possibility means death.
                    //     if !hint_positions {
                    //         return .UNSOLVABLE;
                    //     }

                    //     array_add(hint_positions, .{ x, y });
                    //     unsolvable = true;
                    // } else {

                    // Dead end without a monster means we can't be finished yet, as it needs to be filled in.
                    if !hints {
                        return .OPEN;
                    }

                    if hint_flags & .DEAD_ENDS {
                        array_add(hints, .{ .DEAD_END, .{ x, y }});
                    }

                    open = true;
                }
            }
        }
    }

    if unsolvable  return .UNSOLVABLE;
    if open        return .OPEN;

    return .SOLVED;
}

board_check_treasures :: (board: Board, treasure_room_positions_for_pool_detection: *[..] IVector2, hints: *[..] Board_Check_Hint = null) -> Board_Check {
    CANDIDATE_ROOM_CENTER_POSITION_OFFSETS :: IVector2.[
            .{ -1, -1 }, .{  0, -1 }, .{  1, -1 },
            .{ -1,  0 }, .{  0,  0 }, .{  1,  0 },
            .{ -1,  1 }, .{  0,  1 }, .{  1,  1 },
    ];

    SEARCH_DIRECTIONS_FOR_ROOM :: IVector2.[
            .{ -1, -1 }, .{  0, -1 }, .{  1, -1 },
            .{ -1,  0 },              .{  1,  0 },
            .{ -1,  1 }, .{  0,  1 }, .{  1,  1 },
    ];

    SEARCH_DIRECTIONS_FOR_EXIT :: IVector2.[
            .{ -1, -2 }, .{  0, -2 }, .{  1, -2 }, // Top
            .{ -1,  2 }, .{  0,  2 }, .{  1,  2 }, // Bottom
            .{ -2, -1 }, .{ -2,  0 }, .{ -2,  1 }, // Left
            .{  2, -1 }, .{  2,  0 }, .{  2,  1 }, // Right
    ];

    is_center :: (board: Board, center_x: s32, center_y: s32, treasure_x: s32, treasure_y: s32) -> is: bool, could_be: bool {
        for SEARCH_DIRECTIONS_FOR_ROOM {
            test_x := center_x + it.x;
            test_y := center_y + it.y;

            // Don't count our own treasure.
            if test_x == treasure_x && test_y == treasure_y {
                continue;
            }

            // No walls allowed, even implicit walls.
            if !board_in_bounds(board, test_x, test_y) {
                return false, false;
            }

            tile := board_get(board, test_x, test_y);

            // No walls allowed.
            if tile & .MARKED_WALL {
                return false, false;
            }

            // Actually, no clues allowed either.
            if tile_is_clue(tile) {
                return false, false;
            }
        }

        exit_count := 0;
        for SEARCH_DIRECTIONS_FOR_EXIT {
            test_x := center_x + it.x;
            test_y := center_y + it.y;

            if !board_in_bounds(board, test_x, test_y) {
                continue;
            }

            tile := board_get(board, test_x, test_y);

            // We don't allow walls or any clues to be present in the exit (not even traps or mirrors)
            if !tile_is_clue(tile) && !(tile & .MARKED_WALL) {
                exit_count += 1;
            }
        }

        if exit_count == 0 {
            return false, false;
        } else if exit_count == 1 {
            return true, true;
        } else {
            return false, true;
        }
    }

    unsolvable := false;

    treasure_count := 0;
    treasure_room_count := 0;
    for y: 0..board.ysize - 1 {
        for x: 0..board.xsize - 1 {
            tile := board_get(board, x, y);

            if tile & .CLUE_TREASURE {
                treasure_count += 1;
                treasure_room_unsolvable := true;

                treasure_room_position_count_before := treasure_room_positions_for_pool_detection.count;

                for CANDIDATE_ROOM_CENTER_POSITION_OFFSETS {
                    center_x := x + it.x;
                    center_y := y + it.y;

                    is, could_be := is_center(board, center_x, center_y, x, y);
                    if is {
                        treasure_room_count += 1;
                        treasure_room_unsolvable = false;
                        my_array_add_if_unique(treasure_room_positions_for_pool_detection, IVector2.{ center_x, center_y });
                        for SEARCH_DIRECTIONS_FOR_ROOM {
                            room_x := center_x + it.x;
                            room_y := center_y + it.y;
                            my_array_add_if_unique(treasure_room_positions_for_pool_detection, .{ room_x, room_y });
                        }
                    } else if could_be {
                        treasure_room_unsolvable = false;

                        if hints {
                            array_add(hints, .{ .CLUE, .{ x, y } });
                        }
                    }
                }

                // If we didn't find a fully formed treasure room, we can still deterministically
                // guess where we won't be doing pool checks for sure.
                if treasure_room_positions_for_pool_detection.count == treasure_room_position_count_before {
                    my_array_add_if_unique(treasure_room_positions_for_pool_detection, .{ x, y });
                    for SEARCH_DIRECTIONS_FOR_ROOM {
                        pseudoroom_x := x + it.x;
                        pseudoroom_y := y + it.y;

                        my_array_add_if_unique(treasure_room_positions_for_pool_detection, .{ pseudoroom_x, pseudoroom_y });
                    }
                }

                if treasure_room_unsolvable {
                    if hints {
                        array_add(hints, .{ .CLUE, .{ x, y } });
                    }

                    unsolvable = true;
                }
            }
        }
    }

    if unsolvable {
        return .UNSOLVABLE;
    } else if treasure_count == treasure_room_count {
        return .SOLVED;
    } else {
        return .OPEN;
    }
}

board_check_traps :: (board: Board, hints: *[..] Board_Check_Hint) -> Board_Check {
    HORIZONTAL_SEARCH_DIRECTIONS :: IVector2.[.{ -1,  0 }, .{ 1, 0 }];
    VERTICAL_SEARCH_DIRECTIONS   :: IVector2.[.{  0, -1 }, .{ 0, 1 }];

    unsolvable := false;
    open       := false;

    for y: 0..board.ysize - 1 {
        for x: 0..board.xsize - 1 {
            tile := board_get(board, x, y);
            if tile & .CLUE_TRAP {
                horizontal_wall_count := 0;
                horizontal_marked_empty_count := 0;
                horizontal_not_wall_count := 0;
                for HORIZONTAL_SEARCH_DIRECTIONS {
                    test_x := x + it.x;
                    test_y := y + it.y;

                    if !board_in_bounds(board, test_x, test_y) {
                        horizontal_wall_count += 1;
                        continue;
                    }

                    test_tile := board_get(board, test_x, test_y);

                    if test_tile & .MARKED_WALL {
                        horizontal_wall_count += 1;
                    } else if test_tile & (.MARKED_EMPTY | .MARKED_TREASURE_ROOM) {
                        horizontal_not_wall_count += 1;
                        horizontal_marked_empty_count += 1;
                    } else {
                        horizontal_not_wall_count += 1;
                    }
                }

                vertical_wall_count := 0;
                vertical_marked_empty_count := 0;
                vertical_not_wall_count := 0;
                for VERTICAL_SEARCH_DIRECTIONS {
                    test_x := x + it.x;
                    test_y := y + it.y;

                    if !board_in_bounds(board, test_x, test_y) {
                        vertical_wall_count += 1;
                        continue;
                    }

                    test_tile := board_get(board, test_x, test_y);

                    if test_tile & .MARKED_WALL {
                        vertical_wall_count += 1;
                    } else if test_tile & (.MARKED_EMPTY | .MARKED_TREASURE_ROOM) {
                        vertical_not_wall_count += 1;
                        vertical_marked_empty_count += 1;
                    } else {
                        vertical_not_wall_count += 1;
                    }
                }

                assert(horizontal_wall_count + horizontal_not_wall_count <= 2);
                assert(vertical_wall_count + vertical_not_wall_count <= 2);

                // Note that we do not require MARKED_EMPTY in board_check to return SOLVED, because
                // the game can call this too, and the players don't have to fill in
                // MARKED_EMPTY. However, if we do see MARKED_EMPTY, we can use it to disqualify a
                // solution.

                if horizontal_wall_count > 0 && vertical_wall_count > 0 {
                    if !hints {
                        return .UNSOLVABLE;
                    }

                    array_add(hints, .{ .CLUE, .{ x, y }});
                    unsolvable = true;
                    continue;
                }

                if horizontal_marked_empty_count > 0 && vertical_marked_empty_count > 0 {
                    if !hints {
                        return .UNSOLVABLE;
                    }

                    array_add(hints, .{ .CLUE, .{ x, y }});
                    unsolvable = true;
                    continue;
                }

                tile_solved := false;
                if horizontal_not_wall_count == 2 && vertical_wall_count == 2 {
                    tile_solved = true;
                }

                if vertical_not_wall_count == 2 && horizontal_wall_count == 2 {
                    tile_solved = true;
                }

                if !tile_solved {
                    if !hints {
                        return .OPEN;
                    }

                    array_add(hints, .{ .CLUE, .{ x, y }});
                    open = true;
                    continue;
                }
            }
        }
    }

    if unsolvable  return .UNSOLVABLE;
    if open        return .OPEN;

    return .SOLVED;
}

board_check_crests :: (board: Board, hints: *[..] Board_Check_Hint) -> Board_Check {
    single_crests: [..] IVector2;
    single_crests.allocator = temp;
    double_crests: [..] IVector2;
    double_crests.allocator = temp;
    triple_crests: [..] IVector2;
    triple_crests.allocator = temp;

    alt_single_crests:  [..] IVector2;
    alt_single_crests.allocator = temp;
    alt_double_crests:  [..] IVector2;
    alt_double_crests.allocator = temp;
    alt_triple_crests:  [..] IVector2;
    alt_triple_crests.allocator = temp;

    for y: 0..board.ysize - 1 {
        for x: 0..board.xsize - 1 {
            tile := board_get(board, x, y);
            if      tile & .CLUE_CREST_SINGLE then array_add(ifx tile & .CLUE_CREST_ALT then *alt_single_crests else *single_crests, .{ x, y });
            else if tile & .CLUE_CREST_DOUBLE then array_add(ifx tile & .CLUE_CREST_ALT then *alt_double_crests else *double_crests, .{ x, y });
            else if tile & .CLUE_CREST_TRIPLE then array_add(ifx tile & .CLUE_CREST_ALT then *alt_triple_crests else *triple_crests, .{ x, y });
        }
    }

    if single_crests.count != 0 && single_crests.count != 2 return .UNSOLVABLE;
    if double_crests.count != 0 && double_crests.count != 2 return .UNSOLVABLE;
    if triple_crests.count != 0 && triple_crests.count != 2 return .UNSOLVABLE;

    if alt_single_crests.count != 0 && alt_single_crests.count != 2 return .UNSOLVABLE;
    if alt_double_crests.count != 0 && alt_double_crests.count != 2 return .UNSOLVABLE;
    if alt_triple_crests.count != 0 && alt_triple_crests.count != 2 return .UNSOLVABLE;

    find_paths :: (board: Board, a: IVector2, b: IVector2, expected_path_count: s64) -> Board_Check, [..] IVector2 /* Temporary_Storage */ {
        position_to_index :: (position: IVector2) -> s64 #expand {
            return position.y * board.xsize + position.x;
        }

        SEARCH_DIRECTIONS :: IVector2.[.{ -1, 0 }, .{ 1, 0 }, .{ 0, -1 }, .{ 0, 1 }];

        assert(expected_path_count <= 2, "Currently, we can only verify up to 2 paths");

        //
        // find_path Finds a path between 'start' and any of target_positions. It can not pass
        // through MARKED_WALL tiles, nor any of the blocker_positions.
        //
        find_path :: (board: Board, start: IVector2, target_positions: [] IVector2, blocker_positions: [] IVector2) -> [..] IVector2 /* Temporary_Storage */ {
            position_to_index :: (position: IVector2) -> s64 #expand {
                return position.y * board.xsize + position.x;
            }

            ivector2_compare :: inline (a: IVector2, b: IVector2) -> bool {
                return a == b;
            }

            ivector2_hash :: inline (a: IVector2) -> u32 {
                hash := Hash.get_hash(a.x);
                hash =  Hash.get_hash(a.y, hash);

                return hash;
            }

            // TODO(jt): @Speed @Memory This could have been an array? The sparseness of the table
            // doesn't really help us much here, as our path may actually be the entire grid, in
            // which case the table will cost more to store, and the lookup is slower too, and also
            // we have to give it the compare and hash functions and whatnot.
            moves: Table(IVector2, IVector2, ivector2_hash, ivector2_compare);
            moves.allocator = temp;

            visited: [..] bool;
            visited.allocator = temp;
            array_resize(*visited, board.tiles.count);

            targets: [..] bool;
            targets.allocator = temp;
            array_resize(*targets, board.tiles.count);

            for target_positions {
                targets[position_to_index(it)] = true;
            }

            blockers: [..] bool;
            blockers.allocator = temp;
            array_resize(*blockers, board.tiles.count);

            for blocker_positions {
                blockers[position_to_index(it)] = true;
            }

            Search_Step :: struct {
                position_from: IVector2;
                position_to:   IVector2;
            }

            stack: [..] Search_Step;
            stack.allocator = temp;

            array_add(*stack, .{ TILE_POSITION_INVALID, start });

            end := TILE_POSITION_INVALID;

            while stack.count {
                step     := pop(*stack);
                position := step.position_to;

                if visited[position_to_index(position)] {
                    continue;
                }

                visited[position_to_index(position)] = true;

                if step.position_from != TILE_POSITION_INVALID {
                    assert(!table_contains(*moves, step.position_to));
                    table_add(*moves, step.position_to, step.position_from);
                }

                if targets[position_to_index(position)] {
                    assert(end == TILE_POSITION_INVALID);
                    end = position;
                    break;
                }

                for SEARCH_DIRECTIONS {
                    test_position := position + it;
                    if !board_in_bounds(board, test_position.x, test_position.y) {
                        continue;
                    }

                    if blockers[position_to_index(test_position)] {
                        continue;
                    }

                    tile := board_get(board, test_position.x, test_position.y);
                    if tile & .MARKED_WALL {
                        continue;
                    }

                    if visited[position_to_index(test_position)] {
                        continue;
                    }

                    array_add(*stack, .{ position, test_position });
                }
            }

            path: [..] IVector2;
            path.allocator = temp;

            if end == TILE_POSITION_INVALID {
                return path;
            }

            //
            // Reconstruct the path from the side table. Note that it will be reversed, so we
            // reverse it back.  Maybe the reversal is not necessary, but it makes thinking about
            // stuff simpler later.
            //
            node_from := end;
            array_add(*path, end);
            {
                found, node_to := table_find(*moves, node_from);
                while found {
                    array_add(*path, node_to);
                    node_from = node_to;

                    found, node_to = table_find(*moves, node_from);
                }
            }

            // Reverse, because we'll be slicing off the the end at the callsite.
            array_view_reverse(path);

            return path;
        }

        path_count := 0;
        paths_are_intersecting := false;

        main_path := find_path(board, a, .[b], .[]);
        if main_path.count {
            path_count += 1;
        }

        if path_count == 0 {
            if path_count < expected_path_count  return .UNSOLVABLE, main_path;
            if path_count > expected_path_count  return .OPEN, main_path;

            return .SOLVED, main_path;
        }

        path_mask: [..] bool;
        path_mask.allocator = temp;
        array_resize(*path_mask, board.tiles.count);

        solidified_path_mask: [..] bool;
        solidified_path_mask.allocator = temp;
        array_resize(*solidified_path_mask, board.tiles.count);

        path_parts: [..] IVector2;
        path_parts.allocator = temp;

        solidified_path_parts: [..] IVector2;
        solidified_path_parts.allocator = temp;

        process_queue: [..] IVector2;
        process_queue.allocator = temp;

        processed_count := 0;

        for main_path {
            path_mask[position_to_index(it)] = true;
        }

        array_add(*path_parts, ..main_path);
        array_add(*process_queue, ..main_path);
        array_add(*process_queue, TILE_POSITION_INVALID); // Separator

        while processed_count < process_queue.count {
            curr_path_position := process_queue[processed_count];
            next_path_position := ifx processed_count + 1 < process_queue.count then process_queue[processed_count + 1] else TILE_POSITION_INVALID;

            processed_count += 1;

            // We seed search positions from current position, and avoid both solidified parts of
            // the path and the tile directly ahead of us on the path (next_path_position).
            //
            // TILE_POSITION_INVALID separators are inserted between paths, telling is that there is no valid
            // next_path_position to check against when seeding.
            //
            // Furthermore, the end tile of each found path shouldn't be checked anyway. The end of
            // the main path is just B, and any path from B couldn't lead anywhere valid, since B
            // would already be solidified when we'd seed from it. The ends of the loopback paths
            // shouldn't be checked, because they will either be checked as tiles on the main path,
            // or tiles on a loopback path.
            //
            // Because of this, if next_path_position is TILE_POSITION_INVALID, we know we are at the end of a
            // path, and should skip the check. (We obviously skip the check if curr_path_position
            // is TILE_POSITION_INVALID).
            if curr_path_position == TILE_POSITION_INVALID || next_path_position == TILE_POSITION_INVALID {
                continue;
            }


            // TODO(jt): @Memory Clear and reuse?
            seeds: [..] IVector2;
            seeds.allocator = temp;

            for SEARCH_DIRECTIONS {
                test_position := curr_path_position + it;
                if !board_in_bounds(board, test_position.x, test_position.y) {
                    continue;
                }

                if solidified_path_mask[position_to_index(test_position)] {
                    continue;
                }

                if next_path_position != TILE_POSITION_INVALID && test_position == next_path_position {
                    continue;
                }

                tile := board_get(board, test_position.x, test_position.y);
                if tile & .MARKED_WALL {
                    continue;
                }

                array_add(*seeds, test_position);
            }

            array_add(*solidified_path_parts, curr_path_position);
            solidified_path_mask[position_to_index(curr_path_position)] = true;

            for seed_position: seeds {
                path := find_path(board, seed_position, path_parts, solidified_path_parts);

                if path.count {
                    path_count += 1;

                    if path_count > expected_path_count {
                        return .OPEN, path_parts;
                    }

                    // If we were not seeded from A, this path can't be disjunct from the previous paths.
                    paths_are_intersecting |= curr_path_position != a;

                    for path {
                        // If we reach a tile visited by previous paths and it isn't the finish
                        // tile, this path is not disjunct from the previous paths.
                        paths_are_intersecting |= path_mask[position_to_index(it)] && it != b;
                        path_mask[position_to_index(it)] = true;
                    }

                    array_add(*path_parts, ..path);
                    array_add(*process_queue, ..path);
                    array_add(*process_queue, TILE_POSITION_INVALID); // Separator
                }

            }
        }

        if path_count < expected_path_count {
            return .UNSOLVABLE, path_parts;
        }

        if paths_are_intersecting {
            return .OPEN, path_parts;
        }

        return .SOLVED, path_parts;
    }

    fill_hints :: (dest: *[..] Board_Check_Hint, source: [] IVector2) {
        assert(dest != null, "Do not call fill_hints unless destination exists");
        for source {
            array_add(dest, .{ .CLUE, it });
        }
    }

    unsolvable := false;
    open       := false;

    Crest_Check :: struct {
        crests:              [] IVector2;
        expected_path_count: s64;

        path_parts_to_fill: *[..] IVector2;
    }

    single_crest_path_parts: [..] IVector2;
    single_crest_path_parts.allocator = temp;
    double_crest_path_parts: [..] IVector2;
    double_crest_path_parts.allocator = temp;
    triple_crest_path_parts: [..] IVector2;
    triple_crest_path_parts.allocator = temp;
    alt_single_crest_path_parts: [..] IVector2;
    alt_single_crest_path_parts.allocator = temp;
    alt_double_crest_path_parts: [..] IVector2;
    alt_double_crest_path_parts.allocator = temp;
    alt_triple_crest_path_parts: [..] IVector2;
    alt_triple_crest_path_parts.allocator = temp;

    //
    // For now, the crest checks are done in two passes:
    //
    // The primary pass checks, whether the number of disjunct simple paths between crests doesn't
    // exceed expected count. Crests that pass this check contribute their paths for checking done
    // in the secondary pass.
    //
    // The secondary pass checks for intersections between paths of various crest types. Each pair
    // of crests is checked against all other paths from all other pairs of crests that passed the
    // primary check. This "primary check" limitation is here, becuase if a crest pair wouldn't pass
    // the primary check, the pair's paths would be incomplete (because the complete list of paths
    // is O(2^n)).
    //
    // TODO(jt): For crests failing their primary check, find the tiles to contribute to the
    // secondary pass with a floodfill instead. We don't need the exact structure of all the
    // (possible many) paths. We just need to know the tiles they occupy.
    //
    path_parts_separate: [6] *[..] IVector2 = .[
        *single_crest_path_parts,
        *double_crest_path_parts,
        *triple_crest_path_parts,
        *alt_single_crest_path_parts,
        *alt_double_crest_path_parts,
        *alt_triple_crest_path_parts,
    ];

    crest_checks := Crest_Check.[
        Crest_Check.{ single_crests, 1, *single_crest_path_parts },
        Crest_Check.{ double_crests, 2, *double_crest_path_parts },
        Crest_Check.{ triple_crests, 3, *triple_crest_path_parts },
        Crest_Check.{ alt_single_crests, 1, *alt_single_crest_path_parts },
        Crest_Check.{ alt_double_crests, 2, *alt_double_crest_path_parts },
        Crest_Check.{ alt_triple_crests, 3, *alt_triple_crest_path_parts },
    ];

    //
    // Primary check pass
    //
    for crest_checks {
        if it.crests.count {
            check, path_parts := find_paths(board, it.crests[0], it.crests[1], it.expected_path_count);
            if check == {
                case .SOLVED; {
                    array_add(it.path_parts_to_fill, ..path_parts);
                }
                case .OPEN; {
                    if hints {
                        open = true;
                        fill_hints(hints, it.crests);
                    } else {
                        return check;
                    }
                }
                case .UNSOLVABLE; {
                    if hints {
                        unsolvable = true;
                        fill_hints(hints, it.crests);
                    } else {
                        return check;
                    }
                }
            }
        }
    }

    //
    // Secondary check pass
    //
    for self_index: 0..5 {
        self_path := path_parts_separate[self_index];

        all_paths_except_self: [..] IVector2;
        all_paths_except_self.allocator = temp;
        for other_index: 0..5 {
            if self_index == other_index {
                continue;
            }

            other_path := path_parts_separate[other_index];
            array_add(*all_paths_except_self, ..other_path.*);
        }

        for self_path.* {
            if array_view_find(all_paths_except_self, it) {
                open = true;

                if hints {
                    fill_hints(hints, crest_checks[self_index].crests);
                }

                break;
            }
        }
    }

    if unsolvable  return .UNSOLVABLE;
    if open        return .OPEN;

    return .SOLVED;
}

board_check_mirrors :: (board: Board) -> Board_Check {
    position_to_index :: (x: s32, y: s32) -> s64 #expand {
        return y * board.xsize + x;
    }

    search_mirrors :: (board: Board, visited_mirrors: [] bool, position: IVector2, _direction: IVector2) -> loop: bool, hit: Tile, route_marked_empty: bool {
        // TODO(jt): @Cleanup Find if we can use just the one macro.. maybe do backticks or
        // something. I don't know enough about this language!
        position_to_index :: (x: s32, y: s32) -> s64 #expand {
            return y * board.xsize + x;
        }

        direction := _direction;

        hit: Tile;
        loop := false;
        route_marked_empty := true;

        test_position := position + direction;

        while board_in_bounds(board, test_position.x, test_position.y) {
            test_tile := board_get(board, test_position.x, test_position.y);
            if tile_is_reflected_in_mirrors(test_tile) {
                if tile_is_mirror(test_tile) {
                    success, reflected := tile_reflect_mirror_incoming_view_direction(test_tile, direction);
                    if success {
                        if visited_mirrors[position_to_index(test_position.x, test_position.y)] {
                            // We have finished the whole loop around all the mirrors.
                            loop = true;
                            break;
                        }

                        visited_mirrors[position_to_index(test_position.x, test_position.y)] = true;
                        direction = reflected;
                    } else {
                        hit = test_tile;
                        break;
                    }
                } else {
                    hit = test_tile;
                    break;
                }
            }

            if !(test_tile & (.MARKED_EMPTY | .MARKED_TREASURE_ROOM)) {
                route_marked_empty = false;
            }

            test_position.x += direction.x;
            test_position.y += direction.y;
        }

        if !board_in_bounds(board, test_position.x, test_position.y) {
            assert(hit == .NONE);
            hit = .MARKED_WALL;
        }

        return loop, hit, route_marked_empty;
    }

    visited_mirrors: [..] bool;
    visited_mirrors.allocator = temp;
    array_resize(*visited_mirrors, board.tiles.count);

    for y: 0..board.ysize - 1 {
        for x: 0..board.xsize - 1 {
            tile := board_get(board, x, y);
            if tile_is_mirror(tile) {
                if visited_mirrors[position_to_index(x, y)] {
                    continue;
                }
                visited_mirrors[position_to_index(x, y)] = true;

                line_points: [..] IVector2;
                line_points.allocator = temp;
                array_add(*line_points, .{ x, y });

                direction1, direction2 := tile_get_mirror_view_directions(tile);

                loop1, hit1, route_marked_empty1 := search_mirrors(board, visited_mirrors, .{ x, y }, direction1);
                loop2, hit2, route_marked_empty2 := search_mirrors(board, visited_mirrors, .{ x, y }, direction2);
                if loop1 || loop2 {
                    assert(loop1);
                    assert(loop2);
                } else if hit1 != hit2 {
                    if route_marked_empty1 && route_marked_empty2 {
                        return .UNSOLVABLE;
                    }

                    return .OPEN;
                }
            }
        }
    }

    return .SOLVED;
}

board_check_pools :: (board: Board, treasure_room_positions: [] IVector2, hints: *[..] Board_Check_Hint) -> Board_Check {
    if board.xsize < 2 || board.ysize < 2 {
        return .SOLVED;
    }

    unsolvable := false;
    open       := false;

    for y: 0..board.ysize - 2 {
        for x: 0..board.xsize - 2 {
            for treasure_room_positions {
                // TODO(jt): @Cleanup @Speed Maybe finally use that table!
                if x     == it.x && y     == it.y  continue x;
                if x     == it.x && y + 1 == it.y  continue x;
                if x + 1 == it.x && y     == it.y  continue x;
                if x + 1 == it.x && y + 1 == it.y  continue x;
            }

            t00 := board_get(board, x, y);
            t01 := board_get(board, x    , y + 1);
            t10 := board_get(board, x + 1, y    );
            t11 := board_get(board, x + 1, y + 1);

            e00 := t00 & .MARKED_EMPTY;
            e01 := t01 & .MARKED_EMPTY;
            e10 := t10 & .MARKED_EMPTY;
            e11 := t11 & .MARKED_EMPTY;
            if e00 && e01 && e10 && e11 {
                // The solver (or player) created an explicit pool.
                if !hints {
                    return .UNSOLVABLE;
                }

                unsolvable = true;
                array_add(hints, .{ .POOL, .{ x, y } });
                continue;
            }

            c00 := tile_is_clue(t00);
            c01 := tile_is_clue(t01);
            c10 := tile_is_clue(t10);
            c11 := tile_is_clue(t11);
            if c00 && c01 && c10 && c11 {
                // This puzzle was already designed unsolvable. Note that this false-positives on
                // treasures, but that 4 treasures are illegal for other reasons, so this it is
                // actually fine.
                if !hints {
                    return .UNSOLVABLE;
                }

                unsolvable = true;
                array_add(hints, .{ .POOL, .{ x, y } });
                continue;
            }

            w00 := t00 & .MARKED_WALL;
            w01 := t01 & .MARKED_WALL;
            w10 := t10 & .MARKED_WALL;
            w11 := t11 & .MARKED_WALL;

            if !w00 && !w01 && !w10 && !w11 {
                // we found an implicit pool (four not-walls). The solution is still open, as adding
                // more walls can fix the problem. Another reason for returning open here is that
                // this *can* be inside an yet undetected treasure room. Also note that some of the
                // four tiles can be clues, but at least one of the must not be.
                if !hints {
                    return .OPEN;
                }

                open = true;
                array_add(hints, .{ .POOL, .{ x, y }});
                continue;
            }
        }
    }

    if unsolvable  return .UNSOLVABLE;
    if open        return .OPEN;

    return .SOLVED;
}

board_check_connectivity :: (board: Board, hints: *[..] Board_Check_Hint = null) -> Board_Check {
    position_to_index :: (x: s32, y: s32) -> s64 #expand {
        return y * board.xsize + x;
    }

    SEARCH_DIRECTIONS :: IVector2.[.{ -1, 0 }, .{ 1, 0 }, .{ 0, -1 }, .{ 0, 1 }];

    stack: [..] IVector2;
    stack.allocator = temp;

    visited: [..] bool;
    visited.allocator = temp;
    array_resize(*visited, board.tiles.count);

    Subgraph :: struct {
        starting_tile: IVector2;
        tile_count: s64;
        mark_count: s64;
    }

    subgraphs: [..] Subgraph;
    subgraphs.allocator = temp;

    // We used to count .CLUE_MONSTER as a wall in this procedure, because walls do emerge around
    // mosters. We don't do that anymore, because we need to accurately report which subgraph is the
    // smallest, so that we can flash hints there.

    for y: 0..board.ysize - 1 {
        for x: 0..board.xsize - 1 {
            tile := board_get(board, x, y);

            if tile & .MARKED_WALL {
                continue;
            }

            if !visited[position_to_index(x, y)] {
                tile_count := 0;
                mark_count := 0;
                array_add(*stack, .{ x, y });

                while stack.count {
                    tile_count += 1;
                    position := pop(*stack);

                    if visited[position_to_index(position.x, position.y)] {
                        continue;
                    }

                    visited[position_to_index(position.x, position.y)] = true;

                    tile := board_get(board, position.x, position.y);
                    if tile & (.MARKED_EMPTY | .MARKED_TREASURE_ROOM) || tile_is_clue(tile) {
                        mark_count += 1;
                    }

                    for SEARCH_DIRECTIONS {
                        visit_x := position.x + it.x;
                        visit_y := position.y + it.y;

                        if board_in_bounds(board, visit_x, visit_y) {
                            if !visited[position_to_index(visit_x, visit_y)] {
                                visit_tile := board_get(board, visit_x, visit_y);
                                if !(visit_tile & .MARKED_WALL) {
                                    array_add(*stack, .{ visit_x, visit_y });
                                }
                            }
                        }
                    }
                }

                array_add(*subgraphs, .{ .{ x, y }, tile_count, mark_count });
            }
        }
    }

    if subgraphs.count > 1 {
        marked_subgraph_count := 0;

        largest_subgraph_tile_count: s64 = -1;
        largest_subgraph_index := -1;
        largest_subgraph_count := 0;

        for subgraphs {
            marked_subgraph_count += cast(s64, it.mark_count > 0);

            if it.tile_count == largest_subgraph_tile_count {
                largest_subgraph_count += 1;
            }

            if it.tile_count > largest_subgraph_tile_count {
                largest_subgraph_tile_count = it.tile_count;
                largest_subgraph_index = it_index;
                largest_subgraph_count = 1;
            }
        }

        if hints {
            // TODO(jt): @Hack Because we know where we display numeric constraints, we know where
            // to add the flashing effect, but this is a little bit fragile.
            array_add(hints, .{ .CLUE, .{ -1, -1 } });
        }

        // TODO(jt): @Cleanup The original CONNECTIVITY hints are disabled as an experiment. If we
        // keep them disabled, remove the info gathering code, as well as their rendering code.
        #if false {
            if hints {
                for 0..subgraphs.count - 1 {
                    if largest_subgraph_count == 1 && it == largest_subgraph_index {
                        continue;
                    }

                    array_reset_keeping_memory(*stack);
                    array_view_fill_zero(visited);

                    subgraph := subgraphs[it];

                    array_add(*stack, subgraph.starting_tile);

                    while stack.count {
                        position := pop(*stack);

                        if visited[position_to_index(position.x, position.y)] {
                            continue;
                        }

                        visited[position_to_index(position.x, position.y)] = true;

                        array_add(hints, .{ .CONNECTIVITY, position });

                        for SEARCH_DIRECTIONS {
                            visit_x := position.x + it.x;
                            visit_y := position.y + it.y;

                            if board_in_bounds(board, visit_x, visit_y) {
                                if !visited[position_to_index(visit_x, visit_y)] {
                                    visit_tile := board_get(board, visit_x, visit_y);
                                    if !(visit_tile & .MARKED_WALL) {
                                        array_add(*stack, .{ visit_x, visit_y });
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        if marked_subgraph_count > 1 {
            return .UNSOLVABLE;
        } else {
            return .OPEN;
        }
    } else {
        return .SOLVED; // This also applies to completely walled in boards, but that's okay.
    }
}

#scope_file

// TODO(jt): @Cleanup Use operator== on arrays once it is in the language (or generic array equals).
array_equals_s32 :: (a: [] s32, b: [] s32) -> bool {
    if a.count != b.count {
        return false;
    }

    for 0..a.count - 1 {
        if a[it] != b[it] {
            return false;
        }
    }

    return true;
}

// TODO(jt): @Cleanup Use operator== on arrays once it is in the language (or generic array equals).
array_equals_tile :: (a: [] Tile, b: [] Tile) -> bool {
    if a.count != b.count {
        return false;
    }

    for 0..a.count - 1 {
        if a[it] != b[it] {
            return false;
        }
    }

    return true;
}
