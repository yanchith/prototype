const SIZE_OF_RECT_INSTANCE = 48;
const SIZE_OF_RECT_INSTANCE_IN_FIELDS = 12;

// TODO(jt): @Memory This creates a pessimistically large buffer for instances both on the
// CPU side and the GPU side. We could make it smaller and flush and draw each time it fills up.
const MAX_RECT_INSTANCES = 1024;

async function rendererInitialize(canvas) {
    if (!navigator.gpu) {
        return { initialized: false };
    }

    let adapter;
    try {
        adapter = await navigator.gpu.requestAdapter();
    } catch (e) {
        return { initialized: false };
    }

    if (!adapter) {
        return { initialized: false };
    }

    let device;
    try {
        device = await adapter.requestDevice();
    } catch (e) {
        return { initialized: false }
    }

    const surface = canvas.getContext("webgpu");
    if (!surface) {
        return { initialized: false };
    }

    surface.configure({
        device,
        format: navigator.gpu.getPreferredCanvasFormat(),
    });

    const nearestSampler = device.createSampler({
        addressModeU: "clamp-to-edge",
        addressModeV: "clamp-to-edge",
        addressModeW: "clamp-to-edge",
        magFilter: "nearest",
        minFilter: "nearest",
        mipmapFilter: "nearest",
        lodMinClamp: 0,
        lodMaxClamp: 32,
        compare: undefined,
        maxAnisotropy: 1,
    });

    const rectInstanceBuffer = device.createBuffer({
        size: MAX_RECT_INSTANCES * SIZE_OF_RECT_INSTANCE,
        usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
    });

    const screenUniformBuffer = device.createBuffer({
        size: 16, // width: f32, height: f32, pad: u32, pad: u32
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });

    const screenUniformBindGroupLayout = device.createBindGroupLayout({
        entries: [{
            binding: 0,
            visibility: GPUShaderStage.FRAGMENT | GPUShaderStage.VERTEX,
            buffer: { type: "uniform", hasDynamicOffset: false, minBindingSize: 0 }, // TODO(jt): @Speed Provide minBindingSize.
        }],
    });

    const screenUniformBindGroup = device.createBindGroup({
        layout: screenUniformBindGroupLayout,
        entries: [{
            binding: 0,
            resource: screenUniformBuffer,
        }],
    });

    const textureUniformBindGroupLayout = device.createBindGroupLayout({
        entries: [
            {
                binding: 0,
                visibility: GPUShaderStage.FRAGMENT | GPUShaderStage.VERTEX,
                sampler: { type: "non-filtering" },
            },
            {
                binding: 1,
                visibility: GPUShaderStage.FRAGMENT | GPUShaderStage.VERTEX,
                texture: {
                    sampleType: "float",
                    viewDimension: "2d",
                    multisampled: false,
                },
            },
        ],
    });

    const pipelineLayout = device.createPipelineLayout({
        bindGroupLayouts: [
            screenUniformBindGroupLayout,
            textureUniformBindGroupLayout,
        ],
    });

    // TODO(jt): Instead of downloading the shaders, package them into this file.
    const shaderResponse = await window.fetch("renderer.wgsl");
    const shaderSource   = await shaderResponse.text();
    const shaderModule   = device.createShaderModule({ code: shaderSource });

    const renderPipeline = device.createRenderPipeline({
        layout: pipelineLayout,
        vertex: {
            module: shaderModule,
            buffers: [{
                arrayStride: SIZE_OF_RECT_INSTANCE,
                stepMode: "instance",
                attributes: [
                    { format: "float32x4", offset: 0,  shaderLocation: 0 }, // a_rect
                    { format: "float32x4", offset: 16, shaderLocation: 1 }, // a_texture_rect
                    { format: "float32x4", offset: 32, shaderLocation: 2 }, // a_color
                ],
            }],
        },
        primitive: {
            topology: "triangle-list",
            stripIndexFormat: undefined,
            frontFace: "ccw",
            cullMode: "none",

            unclippedDepth: false,
        },
        depthStencil: undefined,
        multisample: undefined,
        fragment: {
            module: shaderModule,
            targets: [{
                format: navigator.gpu.getPreferredCanvasFormat(),
                // TODO(jt): @Correctness Or do we use pre-multiplied alpha instead? Note that this
                // is the blending that Simp uses, so we'd have to ditch it first.
                blend: {
                    color: { operation: "add", srcFactor: "src-alpha", dstFactor: "one-minus-src-alpha" },
                    alpha: { operation: "add", srcFactor: "src-alpha", dstFactor: "one-minus-src-alpha" },
                },
                writeMask: GPUColorWrite.ALL,
            }],
        },
    });

    return {
        initialized: true,

        device,
        surface,
        nearestSampler,

        textureUniformBindGroupLayout,

        rectInstanceBuffer,
        screenUniformBuffer,
        screenUniformBindGroup,

        renderPipeline,

        textureBindGroups: new Map(),
    };
}

function rendererUploadTextureRgbaUnorm(renderer, name, data /* Uint8Array? */, width, height) {
    assert(renderer && renderer.initialized);

    const device = renderer.device;
    const queue  = renderer.device.queue;

    const texture = device.createTexture({
        size: {
            width,
            height,
            depthOrArrayLayers: 1,
        },
        mipLevelCount: 1,
        sampleCount: 1,
        dimension: "2d",
        format: "rgba8unorm",
        usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.TEXTURE_BINDING ,
        viewFormats: [],
    });

    queue.writeTexture(
        {
            texture,
            mipLevel: 0,
            origin: { x: 0, y: 0, z: 0 },
            aspect: "all",
        },
        data,
        {
            offset: 0,
            bytesPerRow: width * 4,
            rowsPerImage: height,
        },
        {
            width,
            height,
            depthOrArrayLayers: 1,
        },
    );


    const textureBindGroup = device.createBindGroup({
        layout: renderer.textureUniformBindGroupLayout,
        entries: [
            {
                binding: 0,
                resource: renderer.nearestSampler,
            },
            {
                binding: 1,
                resource: texture,
            },
        ],
    });

    renderer.textureBindGroups.set(name, textureBindGroup);
}

function rendererDraw(renderer, rectInstanceArrayBuffer, rectTextureNames) {
    assert(renderer && renderer.initialized);

    assert(rectInstanceArrayBuffer instanceof Float32Array, "Rect instance buffer must be a Float32Array");
    assert(typeof rectInstanceArrayBuffer.__length != "undefined", "Use rendererFloat32ArrayCreate to make the rect instance buffer");

    {
        const instanceCount = rectInstanceArrayBuffer.__length / SIZE_OF_RECT_INSTANCE_IN_FIELDS;
        const textureCount  = rectTextureNames.length;

        if (instanceCount > textureCount) {
            rectInstanceArrayBuffer.__length = textureCount * SIZE_OF_RECT_INSTANCE_IN_FIELDS;
            logError(`Had more instances than textures (${instanceCount} > ${textureCount}). Clamping`);
        }

        if (textureCount > instanceCount) {
            rectTextureNames.length = instanceCount;
            logError(`Had more textures than instances (${textureCount} > ${instanceCount}). Clamping`);
        }

        assert(
            rectInstanceArrayBuffer.__length == rectTextureNames.length * SIZE_OF_RECT_INSTANCE_IN_FIELDS,
            `${rectInstanceArrayBuffer.__length} == ${rectTextureNames.length * SIZE_OF_RECT_INSTANCE_IN_FIELDS}`,
        );
    }

    const device  = renderer.device;
    const queue   = renderer.device.queue;
    const surface = renderer.surface;

    const surfaceWidth = surface.canvas.width;
    const surfaceHeight = surface.canvas.height;

    queue.writeBuffer(renderer.screenUniformBuffer, 0, new Float32Array([surfaceWidth, surfaceHeight, 0, 0]));
    queue.writeBuffer(renderer.rectInstanceBuffer, 0, rectInstanceArrayBuffer, 0, rectInstanceArrayBuffer.__length);

    const encoder = device.createCommandEncoder();

    const renderPass = encoder.beginRenderPass({
        colorAttachments: [{
            // TODO(jt): Create texture view explicitly to do sRGB stuff and whatnot.
            view: surface.getCurrentTexture(),

            clearValue: [0, 0, 0, 1],
            loadOp:     "clear",
            storeOp:    "store",
        }],
    });

    renderPass.setPipeline(renderer.renderPipeline);
    renderPass.setBindGroup(0, renderer.screenUniformBindGroup);

    // TODO(jt): @Speed Currently, we have to encode many drawcalls into the render pass, because we
    // switch the texture. However, we can atlas everything into a single texture. Once we do, this
    // code should detect the longest possible run with the same texture to batch with instancing.

    let offset = 0;
    for (const textureName of rectTextureNames) {
        const textureBindGroup = renderer.textureBindGroups.get(textureName);
        if (textureBindGroup) {
            renderPass.setVertexBuffer(0, renderer.rectInstanceBuffer, offset);
            renderPass.setBindGroup(1, textureBindGroup, []);
            renderPass.draw(6, 1);
        }

        offset += SIZE_OF_RECT_INSTANCE;
    }

    renderPass.end();

    const commandBuffer = encoder.finish();

    queue.submit([commandBuffer]);
}

function rendererFloat32ArrayCreate(size) {
    const f32 = new Float32Array(size);
    f32.__length = 0;

    return f32;
}

function rendererFloat32ArrayClear(f32) {
    f32.__length = 0;
}

function rendererFloat32ArrayPushRect(f32, p0x, p0y, p1x, p1y, texP0x, texP0y, texP1x, texP1y, r, g, b, a) {
    assert(typeof f32.__length != "undefined", "Use rendererFloat32ArrayCreate to make your array");

    const oldSize = f32.__length;
    const newSize = oldSize + SIZE_OF_RECT_INSTANCE_IN_FIELDS;

    // Let's not overflow the array.
    if (newSize > f32.length) {
        return;
    }

    f32.__length = newSize;

    f32[oldSize + 0] = p0x;
    f32[oldSize + 1] = p0y;
    f32[oldSize + 2] = p1x;
    f32[oldSize + 3] = p1y;

    f32[oldSize + 4] = texP0x;
    f32[oldSize + 5] = texP0y;
    f32[oldSize + 6] = texP1x;
    f32[oldSize + 7] = texP1y;

    f32[oldSize + 8]  = r;
    f32[oldSize + 9]  = g;
    f32[oldSize + 10] = b;
    f32[oldSize + 11] = a;
}
