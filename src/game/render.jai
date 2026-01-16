// TODO(jt): This API is a work-in-progress. The style is kind of elegant and lightweight, but
// delegates streaming to the platform layer, which may not be the correct choice. Maybe we do want
// a renderer API later.

Render_Lists :: struct {
    rects: [..] Render_Rect;
}

Render_Rect :: struct {
    rect: Rect;
    texture_rect: Rect;
    texture_name: string; // Pass in empty string to have just a color shader and ignore texture.
    color := Vector4.{ 1, 1, 1, 1 };
}

Font_Kind :: enum u32 {
    SHADOW :: 0;
    LIGHT  :: 1;
    DARK   :: 2;
}

draw_rect :: (render_lists: *Render_Lists, rect: Rect, color: Vector4) {
    array_add(*render_lists.rects, .{ rect = rect, texture_rect = .{ 0, 0, 0, 0 }, texture_name = "", color = color });
}

draw_rect :: (render_lists: *Render_Lists, rect: Rect, texture_rect: Rect, texture_name: string, color := Vector4.{ 1, 1, 1, 1 }) {
    array_add(*render_lists.rects, .{ rect = rect, texture_rect = texture_rect, texture_name = texture_name, color = color });
}

draw_text :: (render_lists: *Render_Lists, position: Vector2, text: string, scale := 1.0, font_kind := Font_Kind.LIGHT, color := Vector4.{ 1, 1, 1, 1 }) {
    font_size := scale * ivector_to_vector(TINY_DUNGEON_FONT_TILE_SIZE);

    cursor_x := 0;
    cursor_y := 0;

    for c: text {
        horizontal_index: s32 = -1;
        vertical_index:   s32 = 2 * cast(s32, font_kind);
        if c >= #char "a" && c <= #char "z" {
            horizontal_index = c - #char "a";
        } else if c >= #char "A" && c <= #char "Z" {
            horizontal_index = c - #char "A";
        } else if c >= #char "0" && c <= #char "9" {
            horizontal_index = 26 + c - #char "0";
        } else {
            if c == {
                // The font file is currently organized by the US keyboard layout: !@#$%^&*()-+=:;,"<>.?/\[]_|
                //
                // TODO(jt): @Cleanup Organize by ASCII, so that we can make this code more compact?
                case #char "!";  horizontal_index = 0;
                case #char "@";  horizontal_index = 1;
                case #char "#";  horizontal_index = 2;
                case DOLLAR;     horizontal_index = 3;
                case #char "%";  horizontal_index = 4;
                case #char "^";  horizontal_index = 5;
                case #char "&";  horizontal_index = 6;
                case #char "*";  horizontal_index = 7;
                case #char "(";  horizontal_index = 8;
                case #char ")";  horizontal_index = 9;
                case #char "-";  horizontal_index = 10;
                case #char "+";  horizontal_index = 11;
                case #char "=";  horizontal_index = 12;
                case #char ":";  horizontal_index = 13;
                case #char ";";  horizontal_index = 14;
                case #char ",";  horizontal_index = 15;
                case #char "\""; horizontal_index = 16;
                case #char "<";  horizontal_index = 17;
                case #char ">";  horizontal_index = 18;
                case #char ".";  horizontal_index = 19;
                case #char "?";  horizontal_index = 20;
                case #char "/";  horizontal_index = 21;
                case #char "\\"; horizontal_index = 22;
                case #char "[";  horizontal_index = 23;
                case #char "]";  horizontal_index = 24;
                case #char "\n"; {
                    cursor_x = 0;
                    cursor_y += 1;
                }
            }

            if horizontal_index != -1 {
                vertical_index += 1;
            }
        }

        if horizontal_index >= 0 {
            rect := Rect.{
                position.x + font_size.x * cursor_x,
                position.y + font_size.y * cursor_y,
                font_size.x,
                font_size.y,
            };
            font_rect := make_tile_rect(horizontal_index, vertical_index, TINY_DUNGEON_FONT_TILE_SIZE);
            draw_rect(render_lists, rect, font_rect, TEX_ORYX_TINY_DUNGEON_FONT, color);
        }

        if c != #char "\n" {
            cursor_x += 1;
        }
    }
}

draw_error_text :: (render_lists: *Render_Lists, position: Vector2, text: string, scale := 1.0) {
    draw_text(render_lists, position, text, color = .{ 1.0, 0.2, 0.2, 1.0 }, scale = scale);
}

// Because "$" breaks my Emacs...
DOLLAR :: "$";
