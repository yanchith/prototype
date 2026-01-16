EFFECT_ID_INVALID :: -1;

Effect_Frame :: struct {
    rect: Rect;
    color := Vector4.{ 1, 1, 1, 1 };
}

Effect :: struct {
    rect:         Rect;
    texture_name: string;
    frames:       [] Effect_Frame;
    duration:     f32;

    // Optional parameters:
    delay := 0.0;

    repeat       := false;
    repeat_delay := 0.0;
}

Effect_State :: struct {
    using config: Effect; // TODO(jt): @Speed Store config outside?

    id:   s64;
    time: f32;
}

Effects :: struct {
    // TODO(jt): @Correctness Apart from this being a really big number, there is no check for
    // overwriting existing IDs. Not sure how to solve this, but exactly, but fortunately our ID
    // space is quite large.
    next_id: s64;
    // TODO(jt): #malloc @Memory This is malloc. We could also make it fixed array and keep explicit count.
    effect_states: [..] Effect_State;
}


effects_add :: (effects: *Effects, effect: Effect) -> s64 {
    id := effects.next_id;
    effects.next_id += 1;

    // Negative ids are invalid.
    if effects.next_id < 0 {
        effects.next_id = 0;
    }

    array_add(*effects.effect_states, Effect_State.{ effect, id, -effect.delay });

    return id;
}

effects_remove :: (effects: *Effects, id: s64) {
    for effects.effect_states {
        if it.id == id {
            remove;
            break;
        }
    }
}

// TODO(jt): #array_reset @Cleanup Harmonize reset conventions with JAI once it itself harmonizes.
effects_reset :: (effects: *Effects) {
    array_reset_keeping_memory(*effects.effect_states);
}

effects_update_and_render :: (effects: *Effects, dt: f32, viewport: Viewport, render_lists: *Render_Lists) {
    for * effects.effect_states {
        it.time += dt;

        if it.time < 0.0 {
            continue;
        }

        total_duration := it.duration;
        if it.repeat {
            total_duration += it.repeat_delay;
        }

        if it.repeat {
            it.time = fmod_cycling(it.time, total_duration);
        }

        if it.time > total_duration {
            remove;
            continue;
        }

        if it.time < it.duration {
            // TODO(jt): @Speed Precompute reciprocal of duration when adding the effect.
            // TODO(jt): @Speed Precompute float of frame count when adding the effect.
            frame_index := cast(s64, floor(it.time / it.duration * cast(f32, it.frames.count)));
            frame       := it.frames[frame_index];

            rect := viewport_transform_rect(viewport, it.rect);

            array_add(*render_lists.rects, .{ rect, frame.rect, it.texture_name, frame.color });
        }
    }
}
