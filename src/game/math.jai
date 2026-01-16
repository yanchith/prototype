//
// Floating point scalars
//

// floor and ceil are defined in Math/cephes.jai.
round :: (x: f32) -> f32 {
    return floor(x + 0.5);
}

move_toward :: (a: f32, b: f32, amount_up: f32, amount_down := -1.0) -> f32 {
    if a > b {
        if amount_down == -1.0 {
            amount_down = amount_up;
        }

        a -= amount_down;
        if a < b  a = b;
    } else {
        a += amount_up;
        if a > b  a = b;
    }

    return a;
}


//
// Floating point vectors
//
//
// TODO(jt): We are currently using the ones from JAI's math, becuase Simp uses them.
//

floor :: (a: Vector2) -> Vector2 {
    return .{ floor(a.x), floor(a.y) };
}

ceil :: (a: Vector2) -> Vector2 {
    return .{ ceil(a.x), ceil(a.y) };
}

//
// Integer vectors
//

IVector2 :: struct {
    x: s32;
    y: s32;

    #overlay (x) component: [2] s32 = ---;
}

IVECTOR2_ZERO :: IVector2.{ 0, 0 };

IVECTOR2_POSITIVE_X :: IVector2.{  1,  0 };
IVECTOR2_NEGATIVE_X :: IVector2.{ -1,  0 };
IVECTOR2_POSITIVE_Y :: IVector2.{  0,  1 };
IVECTOR2_NEGATIVE_Y :: IVector2.{  0, -1 };

operator == :: (a: IVector2, b: IVector2) -> bool {
    return a.x == b.x && a.y == b.y;
}

operator + :: (a: IVector2, b: IVector2) -> IVector2 {
    return .{ a.x + b.x, a.y + b.y };
}

operator - :: (a: IVector2) -> IVector2 {
    return .{ -a.x, -a.y };
}

operator - :: (a: IVector2, b: IVector2) -> IVector2 {
    return .{ a.x - b.x, a.y - b.y };
}

operator * :: (a: IVector2, b: s32) -> IVector2 #symmetric {
    return .{ a.x * b, a.y * b };
}

// Hadamard
operator * :: (a: IVector2, b: IVector2) -> IVector2 {
    return .{ a.x * b.x, a.y * b.y };
}

operator / :: (a: IVector2, b: s32) -> IVector2 {
    return .{ a.x / b, a.y / b };
}

operator / :: (a: IVector2, b: IVector2) -> IVector2 {
    return .{ a.x / b.x, a.y / b.y };
}

min :: (a: IVector2, b: IVector2) -> IVector2 {
    return .{ min(a.x, b.x), min(a.y, b.y) };
}

max :: (a: IVector2, b: IVector2) -> IVector2 {
    return .{ max(a.x, b.x), max(a.y, b.y) };
}

ivector_to_vector :: inline (a: IVector2) -> Vector2 {
    return Vector2.{ cast(f32, a.x), cast(f32, a.y) };
}

//
// Floating point rects
//

Rect :: struct {
    x: f32;
    y: f32;

    // Width and height can be negative, making the rect is flipped. See rect_fixup.
    w: f32;
    h: f32;

    #overlay (x) p0:   Vector2;
    #overlay (w) size: Vector2;;
}

operator + :: (r: Rect, v: Vector2) -> Rect {
    return .{ r.x + v.x, r.y + v.y, r.w, r.h };
}

operator - :: (r: Rect, v: Vector2) -> Rect {
    return .{ r.x - v.x, r.y - v.y, r.w, r.h };
}

rect_min :: inline (r: Rect) -> Vector2 {
    x := r.x + ifx r.w < 0 then r.w else 0;
    y := r.y + ifx r.h < 0 then r.h else 0;

    return .{ x, y };
}

rect_max :: inline (r: Rect) -> Vector2 {
    x := r.x + ifx r.w > 0 then r.w else 0;
    y := r.y + ifx r.h > 0 then r.h else 0;

    return .{ x, y };
}

rect_size :: inline (r: Rect) -> Vector2 {
    return .{ abs(r.w), abs(r.h) };
}

// TODO(jt): Maybe have the opposite and call rect_is_valid or rect_is_canonical?
rect_is_flipped :: inline (r: Rect) -> bool {
    return r.w < 0 || r.h < 0;
}

rect_fixup :: (r: Rect) -> Rect {
    min := rect_min(r);

    result: Rect = ---;
    result.x = min.x;
    result.y = min.y;
    result.w = abs(r.w);
    result.h = abs(r.h);

    return result;
}

rect_contains :: (r: Rect, p: Vector2) -> bool {
    p0 := rect_min(r);
    p1 := rect_max(r);

    x_contains := p.x >= p0.x && p.x < p1.x;
    y_contains := p.y >= p0.y && p.y < p1.y;

    return x_contains && y_contains;
}


rect_inset :: (r: Rect, amount: Vector2) -> Rect {
    result: Rect = ---;

    // This can flip the rect. We do not assert, clamp or fixup here. The caller can do all of those things.
    result.x = r.x + amount.x;
    result.y = r.y + amount.y;
    result.w = r.w - 2 * amount.x;
    result.h = r.h - 2 * amount.y;

    return result;
}


rect_inset_min :: (r: Rect, amount: Vector2) -> Rect {
    result: Rect = ---;

    // This can flip the rect. We do not assert, clamp or fixup here. The caller can do all of those things.
    result.x = r.x + amount.x;
    result.y = r.y + amount.y;
    result.w = r.w - amount.x;
    result.h = r.h - amount.y;

    return result;
}

rect_inset_max :: (r: Rect, amount: Vector2) -> Rect {
    result: Rect = ---;

    // This can flip the rect. We do not assert, clamp or fixup here. The caller can do all of those things.
    result.x = r.x;
    result.y = r.y;
    result.w = r.w - amount.x;
    result.h = r.h - amount.y;

    return result;
}
