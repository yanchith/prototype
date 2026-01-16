struct ScreenUniforms {
     width:  f32,
     height: f32,
     _pad0:  u32,
     _pad1:  u32,
}

@group(0) @binding(0) var<uniform> u_screen:  ScreenUniforms;
@group(1) @binding(0) var          u_sampler: sampler;
@group(1) @binding(1) var          u_texture: texture_2d<f32>;

struct VertexOut {
    @builtin(position) position:  vec4f,
    @location(0)       tex_coord: vec2f,
    @location(1)       color:     vec4f,
}

@vertex
fn vs_main(@builtin(vertex_index) vertex_index:   u32,
           @location(0)           a_rect:         vec4f,
           @location(1)           a_texture_rect: vec4f,
           @location(2)           a_color:        vec4f) -> VertexOut
{
    // Remap the pixel based coordinates to normalized NDC (for destination) and UV (for source)
    // coordinates. Destination Y is already pre-flipped on the CPU for us.
    let dst_p0x = 2.0 * a_rect.x / u_screen.width - 1.0;
    let dst_p0y = 2.0 * a_rect.y / u_screen.height - 1.0;
    let dst_p1x = 2.0 * a_rect.z / u_screen.width - 1.0;
    let dst_p1y = 2.0 * a_rect.w / u_screen.height - 1.0;

    let src_size = vec2f(textureDimensions(u_texture));
    let src_p0x  = a_texture_rect.x / src_size.x;
    let src_p0y  = a_texture_rect.y / src_size.y;
    let src_p1x  = a_texture_rect.z / src_size.x;
    let src_p1y  = a_texture_rect.w / src_size.y;

    var output: VertexOut;

    // Produce a quad (two CCW triangles) with tex coords in WebGPU NDC space.
    // (https://gpuweb.github.io/gpuweb/#coordinate-systems).
    //
    // 3----2
    // |    |
    // |    |
    // 0----1
    //
    // Texture coordinates use WebGPU texture coordinate system, where [0, 0] is
    // the first texel in image memory.
    switch (vertex_index % 6) {
    // 0, 1, 2
    case 0: {
        output.position  = vec4f(dst_p0x, dst_p0y, 0, 1);
        output.tex_coord = vec2f(src_p0x, src_p0y);
    }
    case 1: {
        output.position  = vec4f(dst_p1x, dst_p0y, 0, 1);
        output.tex_coord = vec2f(src_p1x, src_p0y);
    }
    case 2: {
        output.position  = vec4f(dst_p1x, dst_p1y, 0, 1);
        output.tex_coord = vec2f(src_p1x, src_p1y);
    }

    // 2, 3, 0
    case 3: {
        output.position  = vec4f(dst_p1x, dst_p1y, 0, 1);
        output.tex_coord = vec2f(src_p1x, src_p1y);
    }
    case 4: {
        output.position  = vec4f(dst_p0x, dst_p1y, 0, 1);
        output.tex_coord = vec2f(src_p0x, src_p1y);
    }
    case 5: {
        output.position  = vec4f(dst_p0x, dst_p0y, 0, 1);
        output.tex_coord = vec2f(src_p0x, src_p0y);
    }
    default: {}
    }

    output.color = a_color;

    return output;
}

@fragment
fn fs_main(vs_output: VertexOut) -> @location(0) vec4f
{
    let texture_color = textureSample(u_texture, u_sampler, vs_output.tex_coord);
    return vs_output.color * texture_color;
}
