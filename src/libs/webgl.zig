const std = @import("std");
const sokol = @import("sokol");
const sg = sokol.gfx;
const sglue = sokol.glue;

// ============================================================================
// WebGL Standard Constants (OpenGL ES 2.0 / WebGL 1.0)
// ============================================================================

// Buffer targets
pub const ARRAY_BUFFER: u32 = 0x8892;
pub const ELEMENT_ARRAY_BUFFER: u32 = 0x8893;

// Buffer usage
pub const STREAM_DRAW: u32 = 0x88E0;
pub const STATIC_DRAW: u32 = 0x88E4;
pub const DYNAMIC_DRAW: u32 = 0x88E8;

// Shader types
pub const FRAGMENT_SHADER: u32 = 0x8B30;
pub const VERTEX_SHADER: u32 = 0x8B31;

// Primitives
pub const POINTS: u32 = 0x0000;
pub const LINES: u32 = 0x0001;
pub const LINE_LOOP: u32 = 0x0002;
pub const LINE_STRIP: u32 = 0x0003;
pub const TRIANGLES: u32 = 0x0004;
pub const TRIANGLE_STRIP: u32 = 0x0005;
pub const TRIANGLE_FAN: u32 = 0x0006;

// Data types
pub const BYTE: u32 = 0x1400;
pub const UNSIGNED_BYTE: u32 = 0x1401;
pub const SHORT: u32 = 0x1402;
pub const UNSIGNED_SHORT: u32 = 0x1403;
pub const INT: u32 = 0x1404;
pub const UNSIGNED_INT: u32 = 0x1405;
pub const FLOAT: u32 = 0x1406;

// Clear buffer bits
pub const DEPTH_BUFFER_BIT: u32 = 0x00000100;
pub const STENCIL_BUFFER_BIT: u32 = 0x00000400;
pub const COLOR_BUFFER_BIT: u32 = 0x00004000;

// Capabilities
pub const CULL_FACE: u32 = 0x0B44;
pub const DEPTH_TEST: u32 = 0x0B71;
pub const BLEND: u32 = 0x0BE2;
pub const SCISSOR_TEST: u32 = 0x0C11;

// Blending factors
pub const ZERO: u32 = 0;
pub const ONE: u32 = 1;
pub const SRC_COLOR: u32 = 0x0300;
pub const ONE_MINUS_SRC_COLOR: u32 = 0x0301;
pub const SRC_ALPHA: u32 = 0x0302;
pub const ONE_MINUS_SRC_ALPHA: u32 = 0x0303;
pub const DST_ALPHA: u32 = 0x0304;
pub const ONE_MINUS_DST_ALPHA: u32 = 0x0305;

// Texture targets & parameters
pub const TEXTURE_2D: u32 = 0x0DE1;
pub const TEXTURE_MAG_FILTER: u32 = 0x2800;
pub const TEXTURE_MIN_FILTER: u32 = 0x2801;
pub const TEXTURE_WRAP_S: u32 = 0x2802;
pub const TEXTURE_WRAP_T: u32 = 0x2803;
pub const NEAREST: u32 = 0x2600;
pub const LINEAR: u32 = 0x2601;
pub const RGBA: u32 = 0x1908;
pub const RGB: u32 = 0x1907;

// ============================================================================
// WebGL Resource Handles
// ============================================================================

pub const Buffer = struct { id: u32 = 0 };
pub const Shader = struct { id: u32 = 0 };
pub const Program = struct { id: u32 = 0 };
pub const Texture = struct { id: u32 = 0 };
pub const UniformLocation = struct { id: i32 = -1 };
pub const AttribLocation = i32;

// ============================================================================
// Internal Representation & Capacity Limits
// ============================================================================

const MAX_BUFFERS = 128;
const MAX_SHADERS = 64;
const MAX_PROGRAMS = 32;
const MAX_TEXTURES = 64;
const MAX_PIPELINES = 64;
const MAX_ATTRIBS = 16;
const MAX_UNIFORMS = 16;
const MAX_UNIFORM_BYTES = 1024;

const InternalBuffer = struct {
    sg_buf: sg.Buffer = .{},
    target: u32 = 0,
    usage: u32 = STATIC_DRAW,
    size: usize = 0,
    allocated: bool = false,
};

const InternalShader = struct {
    type: u32 = 0,
    source: []const u8 = "",
    compiled: bool = false,
    allocated: bool = false,
};

const UniformInfo = struct {
    name: [32]u8 = [_]u8{0} ** 32,
    name_len: usize = 0,
    type: sg.UniformType = .INVALID,
    offset: usize = 0,
    size: usize = 0,
    count: u16 = 1,
};

const AttribInfo = struct {
    name: [32]u8 = [_]u8{0} ** 32,
    name_len: usize = 0,
    index: u32 = 0,
};

const InternalProgram = struct {
    vs: ?Shader = null,
    fs: ?Shader = null,
    sg_shader: sg.Shader = .{},
    linked: bool = false,
    allocated: bool = false,
    uniforms: [MAX_UNIFORMS]UniformInfo = [_]UniformInfo{.{}} ** MAX_UNIFORMS,
    uniform_count: usize = 0,
    uniform_total_bytes: usize = 0,
    uniform_storage: [MAX_UNIFORM_BYTES]u8 align(16) = [_]u8{0} ** MAX_UNIFORM_BYTES,
    attrs: [MAX_ATTRIBS]AttribInfo = [_]AttribInfo{.{}} ** MAX_ATTRIBS,
    attr_count: usize = 0,
};

const VertexAttrib = struct {
    enabled: bool = false,
    buffer: Buffer = .{},
    size: i32 = 4,
    type_: u32 = FLOAT,
    normalized: bool = false,
    stride: i32 = 0,
    offset: usize = 0,
};

const CachedPipeline = struct {
    program_id: u32 = 0,
    primitive_type: sg.PrimitiveType = .DEFAULT,
    attrib_mask: u32 = 0,
    attrib_strides: [MAX_ATTRIBS]i32 = [_]i32{0} ** MAX_ATTRIBS,
    attrib_offsets: [MAX_ATTRIBS]usize = [_]usize{0} ** MAX_ATTRIBS,
    attrib_formats: [MAX_ATTRIBS]sg.VertexFormat = [_]sg.VertexFormat{.INVALID} ** MAX_ATTRIBS,
    blend_enabled: bool = false,
    depth_enabled: bool = false,
    sg_pip: sg.Pipeline = .{},
    valid: bool = false,
};

// ============================================================================
// WebGL Context & State Machine
// ============================================================================

pub const WebGLRenderingContext = struct {
    buffers: [MAX_BUFFERS]InternalBuffer = [_]InternalBuffer{.{}} ** MAX_BUFFERS,
    shaders: [MAX_SHADERS]InternalShader = [_]InternalShader{.{}} ** MAX_SHADERS,
    programs: [MAX_PROGRAMS]InternalProgram = [_]InternalProgram{.{}} ** MAX_PROGRAMS,
    pipelines: [MAX_PIPELINES]CachedPipeline = [_]CachedPipeline{.{}} ** MAX_PIPELINES,
    pipeline_count: usize = 0,

    bound_array_buffer: ?Buffer = null,
    bound_element_buffer: ?Buffer = null,
    active_program: ?Program = null,

    attribs: [MAX_ATTRIBS]VertexAttrib = [_]VertexAttrib{.{}} ** MAX_ATTRIBS,

    // State
    clear_color: [4]f32 = .{ 0.0, 0.0, 0.0, 1.0 },
    viewport_rect: [4]i32 = .{ 0, 0, 640, 480 },
    blend_enabled: bool = false,
    depth_enabled: bool = false,
    blend_src: u32 = ONE,
    blend_dst: u32 = ZERO,

    // Pass management
    pass_action: sg.PassAction = .{},
    in_pass: bool = false,

    pub fn init() WebGLRenderingContext {
        var ctx = WebGLRenderingContext{};
        ctx.pass_action.colors[0] = .{
            .load_action = .CLEAR,
            .clear_value = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 },
        };
        return ctx;
    }

    // ------------------------------------------------------------------------
    // Buffer Operations
    // ------------------------------------------------------------------------

    pub fn createBuffer(self: *WebGLRenderingContext) Buffer {
        for (1..MAX_BUFFERS) |i| {
            if (!self.buffers[i].allocated) {
                self.buffers[i] = .{
                    .allocated = true,
                    .sg_buf = .{},
                    .target = 0,
                    .usage = STATIC_DRAW,
                    .size = 0,
                };
                return .{ .id = @intCast(i) };
            }
        }
        return .{ .id = 0 };
    }

    pub fn deleteBuffer(self: *WebGLRenderingContext, buf: Buffer) void {
        if (buf.id == 0 or buf.id >= MAX_BUFFERS) return;
        const b = &self.buffers[buf.id];
        if (b.allocated) {
            if (b.sg_buf.id != 0) {
                sg.destroyBuffer(b.sg_buf);
            }
            self.buffers[buf.id] = .{};
        }
    }

    pub fn bindBuffer(self: *WebGLRenderingContext, target: u32, buf: ?Buffer) void {
        switch (target) {
            ARRAY_BUFFER => self.bound_array_buffer = buf,
            ELEMENT_ARRAY_BUFFER => self.bound_element_buffer = buf,
            else => {},
        }
    }

    pub fn bufferData(self: *WebGLRenderingContext, target: u32, data_bytes: []const u8, usage: u32) void {
        const active_buf = switch (target) {
            ARRAY_BUFFER => self.bound_array_buffer,
            ELEMENT_ARRAY_BUFFER => self.bound_element_buffer,
            else => return,
        };
        if (active_buf == null or active_buf.?.id == 0 or active_buf.?.id >= MAX_BUFFERS) return;
        var b = &self.buffers[active_buf.?.id];

        b.target = target;
        b.usage = usage;
        b.size = data_bytes.len;

        var buf_usage: sg.BufferUsage = .{};
        if (target == ELEMENT_ARRAY_BUFFER) {
            buf_usage.index_buffer = true;
        } else {
            buf_usage.vertex_buffer = true;
        }

        if (usage == DYNAMIC_DRAW) {
            buf_usage.dynamic_update = true;
        } else if (usage == STREAM_DRAW) {
            buf_usage.stream_update = true;
        } else {
            buf_usage.immutable = true;
        }

        if (b.sg_buf.id != 0) {
            sg.destroyBuffer(b.sg_buf);
            b.sg_buf = .{};
        }

        b.sg_buf = sg.makeBuffer(.{
            .data = .{
                .ptr = data_bytes.ptr,
                .size = data_bytes.len,
            },
            .usage = buf_usage,
        });
    }

    pub fn bufferDataSlice(self: *WebGLRenderingContext, target: u32, comptime T: type, slice: []const T, usage: u32) void {
        const bytes = std.mem.sliceAsBytes(slice);
        self.bufferData(target, bytes, usage);
    }

    // ------------------------------------------------------------------------
    // Shader & Program Operations
    // ------------------------------------------------------------------------

    pub fn createShader(self: *WebGLRenderingContext, shader_type: u32) ?Shader {
        for (1..MAX_SHADERS) |i| {
            if (!self.shaders[i].allocated) {
                self.shaders[i] = .{
                    .allocated = true,
                    .type = shader_type,
                    .source = "",
                    .compiled = false,
                };
                return .{ .id = @intCast(i) };
            }
        }
        return null;
    }

    pub fn shaderSource(self: *WebGLRenderingContext, shd: Shader, source: []const u8) void {
        if (shd.id == 0 or shd.id >= MAX_SHADERS) return;
        self.shaders[shd.id].source = source;
    }

    pub fn compileShader(self: *WebGLRenderingContext, shd: Shader) void {
        if (shd.id == 0 or shd.id >= MAX_SHADERS) return;
        self.shaders[shd.id].compiled = true;
    }

    pub fn createProgram(self: *WebGLRenderingContext) ?Program {
        for (1..MAX_PROGRAMS) |i| {
            if (!self.programs[i].allocated) {
                self.programs[i] = .{
                    .allocated = true,
                    .linked = false,
                };
                return .{ .id = @intCast(i) };
            }
        }
        return null;
    }

    pub fn attachShader(self: *WebGLRenderingContext, prog: Program, shd: Shader) void {
        if (prog.id == 0 or prog.id >= MAX_PROGRAMS) return;
        if (shd.id == 0 or shd.id >= MAX_SHADERS) return;
        const shd_obj = &self.shaders[shd.id];
        if (shd_obj.type == VERTEX_SHADER) {
            self.programs[prog.id].vs = shd;
        } else if (shd_obj.type == FRAGMENT_SHADER) {
            self.programs[prog.id].fs = shd;
        }
    }

    pub fn linkProgram(self: *WebGLRenderingContext, prog: Program) void {
        if (prog.id == 0 or prog.id >= MAX_PROGRAMS) return;
        var p = &self.programs[prog.id];
        if (p.vs == null or p.fs == null) return;

        const vs_src = self.shaders[p.vs.?.id].source;
        const fs_src = self.shaders[p.fs.?.id].source;

        var shd_desc: sg.ShaderDesc = .{};
        shd_desc.vertex_func.source = vs_src.ptr;
        shd_desc.fragment_func.source = fs_src.ptr;

        // Parse attributes and uniforms automatically from GLSL source!
        p.attr_count = parseAttributes(vs_src, &p.attrs);
        p.uniform_count = parseUniforms(vs_src, fs_src, &p.uniforms, &p.uniform_total_bytes);

        // Register attributes to sokol
        for (0..p.attr_count) |i| {
            shd_desc.attrs[i].glsl_name = @ptrCast(&p.attrs[i].name);
        }

        // Register uniforms to sokol (uniform block 0)
        if (p.uniform_count > 0) {
            shd_desc.uniform_blocks[0].stage = .VERTEX;
            shd_desc.uniform_blocks[0].size = @intCast(p.uniform_total_bytes);
            shd_desc.uniform_blocks[0].layout = .STD140;
            for (0..p.uniform_count) |i| {
                shd_desc.uniform_blocks[0].glsl_uniforms[i] = .{
                    .type = p.uniforms[i].type,
                    .array_count = p.uniforms[i].count,
                    .glsl_name = @ptrCast(&p.uniforms[i].name),
                };
            }
        }

        p.sg_shader = sg.makeShader(shd_desc);
        p.linked = (p.sg_shader.id != 0);
    }

    pub fn useProgram(self: *WebGLRenderingContext, prog: ?Program) void {
        self.active_program = prog;
    }

    pub fn getAttribLocation(self: *WebGLRenderingContext, prog: Program, name: []const u8) AttribLocation {
        if (prog.id == 0 or prog.id >= MAX_PROGRAMS) return -1;
        const p = &self.programs[prog.id];
        for (0..p.attr_count) |i| {
            const attr_name = p.attrs[i].name[0..p.attrs[i].name_len];
            if (std.mem.eql(u8, attr_name, name)) {
                return @intCast(p.attrs[i].index);
            }
        }
        return -1;
    }

    pub fn getUniformLocation(self: *WebGLRenderingContext, prog: Program, name: []const u8) UniformLocation {
        if (prog.id == 0 or prog.id >= MAX_PROGRAMS) return .{ .id = -1 };
        const p = &self.programs[prog.id];
        for (0..p.uniform_count) |i| {
            const uni_name = p.uniforms[i].name[0..p.uniforms[i].name_len];
            if (std.mem.eql(u8, uni_name, name)) {
                return .{ .id = @intCast(i) };
            }
        }
        return .{ .id = -1 };
    }

    // ------------------------------------------------------------------------
    // Vertex Attributes Configuration
    // ------------------------------------------------------------------------

    pub fn enableVertexAttribArray(self: *WebGLRenderingContext, index: u32) void {
        if (index < MAX_ATTRIBS) {
            self.attribs[index].enabled = true;
        }
    }

    pub fn disableVertexAttribArray(self: *WebGLRenderingContext, index: u32) void {
        if (index < MAX_ATTRIBS) {
            self.attribs[index].enabled = false;
        }
    }

    pub fn vertexAttribPointer(
        self: *WebGLRenderingContext,
        index: u32,
        size: i32,
        type_: u32,
        normalized: bool,
        stride: i32,
        offset: usize,
    ) void {
        if (index >= MAX_ATTRIBS) return;
        self.attribs[index].buffer = self.bound_array_buffer orelse .{};
        self.attribs[index].size = size;
        self.attribs[index].type_ = type_;
        self.attribs[index].normalized = normalized;
        self.attribs[index].stride = stride;
        self.attribs[index].offset = offset;
    }

    // ------------------------------------------------------------------------
    // Uniform Setters
    // ------------------------------------------------------------------------

    fn writeUniformBytes(self: *WebGLRenderingContext, loc: UniformLocation, bytes: []const u8) void {
        if (loc.id < 0) return;
        const prog_id = (self.active_program orelse return).id;
        if (prog_id == 0 or prog_id >= MAX_PROGRAMS) return;
        var p = &self.programs[prog_id];
        const idx: usize = @intCast(loc.id);
        if (idx >= p.uniform_count) return;

        const offset = p.uniforms[idx].offset;
        const copy_len = @min(bytes.len, p.uniforms[idx].size);
        if (offset + copy_len <= MAX_UNIFORM_BYTES) {
            @memcpy(p.uniform_storage[offset .. offset + copy_len], bytes[0..copy_len]);
        }
    }

    pub fn uniform1f(self: *WebGLRenderingContext, loc: UniformLocation, x: f32) void {
        const val = [1]f32{x};
        self.writeUniformBytes(loc, std.mem.sliceAsBytes(&val));
    }

    pub fn uniform2f(self: *WebGLRenderingContext, loc: UniformLocation, x: f32, y: f32) void {
        const val = [2]f32{ x, y };
        self.writeUniformBytes(loc, std.mem.sliceAsBytes(&val));
    }

    pub fn uniform3f(self: *WebGLRenderingContext, loc: UniformLocation, x: f32, y: f32, z: f32) void {
        const val = [3]f32{ x, y, z };
        self.writeUniformBytes(loc, std.mem.sliceAsBytes(&val));
    }

    pub fn uniform4f(self: *WebGLRenderingContext, loc: UniformLocation, x: f32, y: f32, z: f32, w: f32) void {
        const val = [4]f32{ x, y, z, w };
        self.writeUniformBytes(loc, std.mem.sliceAsBytes(&val));
    }

    pub fn uniform1i(self: *WebGLRenderingContext, loc: UniformLocation, x: i32) void {
        const val = [1]i32{x};
        self.writeUniformBytes(loc, std.mem.sliceAsBytes(&val));
    }

    pub fn uniformMatrix4fv(self: *WebGLRenderingContext, loc: UniformLocation, transpose: bool, value: []const f32) void {
        _ = transpose;
        self.writeUniformBytes(loc, std.mem.sliceAsBytes(value));
    }

    // ------------------------------------------------------------------------
    // Viewport, Clear, & State Setters
    // ------------------------------------------------------------------------

    pub fn viewport(self: *WebGLRenderingContext, x: i32, y: i32, width: i32, height: i32) void {
        self.viewport_rect = .{ x, y, width, height };
    }

    pub fn clearColor(self: *WebGLRenderingContext, r: f32, g: f32, b: f32, a: f32) void {
        self.clear_color = .{ r, g, b, a };
        self.pass_action.colors[0].clear_value = .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn enable(self: *WebGLRenderingContext, cap: u32) void {
        if (cap == BLEND) self.blend_enabled = true;
        if (cap == DEPTH_TEST) self.depth_enabled = true;
    }

    pub fn disable(self: *WebGLRenderingContext, cap: u32) void {
        if (cap == BLEND) self.blend_enabled = false;
        if (cap == DEPTH_TEST) self.depth_enabled = false;
    }

    pub fn blendFunc(self: *WebGLRenderingContext, sfactor: u32, dfactor: u32) void {
        self.blend_src = sfactor;
        self.blend_dst = dfactor;
    }

    pub fn clear(self: *WebGLRenderingContext, mask: u32) void {
        if ((mask & COLOR_BUFFER_BIT) != 0) {
            self.pass_action.colors[0].load_action = .CLEAR;
        } else {
            self.pass_action.colors[0].load_action = .DONTCARE;
        }
    }

    fn ensurePass(self: *WebGLRenderingContext) void {
        if (!self.in_pass) {
            sg.beginPass(.{
                .action = self.pass_action,
                .swapchain = sglue.swapchain(),
            });
            self.in_pass = true;
        }
    }

    pub fn present(self: *WebGLRenderingContext) void {
        if (self.in_pass) {
            sg.endPass();
            sg.commit();
            self.in_pass = false;
            // After presenting, clear action can reset
            self.pass_action.colors[0].load_action = .CLEAR;
        }
    }

    // ------------------------------------------------------------------------
    // Draw Calls & Pipeline Management
    // ------------------------------------------------------------------------

    fn getOrCreatePipeline(self: *WebGLRenderingContext, primitive_type: sg.PrimitiveType) ?sg.Pipeline {
        const prog_id = (self.active_program orelse return null).id;
        if (prog_id == 0 or prog_id >= MAX_PROGRAMS) return null;
        const p = &self.programs[prog_id];
        if (!p.linked) return null;

        var attrib_mask: u32 = 0;
        var formats: [MAX_ATTRIBS]sg.VertexFormat = [_]sg.VertexFormat{.INVALID} ** MAX_ATTRIBS;
        var strides: [MAX_ATTRIBS]i32 = [_]i32{0} ** MAX_ATTRIBS;
        var offsets: [MAX_ATTRIBS]usize = [_]usize{0} ** MAX_ATTRIBS;

        for (0..p.attr_count) |i| {
            const loc = p.attrs[i].index;
            if (loc < MAX_ATTRIBS and self.attribs[loc].enabled) {
                attrib_mask |= (@as(u32, 1) << @intCast(loc));
                formats[loc] = toSokolVertexFormat(self.attribs[loc].size, self.attribs[loc].type_, self.attribs[loc].normalized);
                strides[loc] = self.attribs[loc].stride;
                offsets[loc] = self.attribs[loc].offset;
            }
        }

        // Search cache
        for (0..self.pipeline_count) |i| {
            const entry = &self.pipelines[i];
            if (entry.valid and
                entry.program_id == prog_id and
                entry.primitive_type == primitive_type and
                entry.blend_enabled == self.blend_enabled and
                entry.depth_enabled == self.depth_enabled and
                entry.attrib_mask == attrib_mask)
            {
                var match = true;
                for (0..MAX_ATTRIBS) |a| {
                    if (entry.attrib_formats[a] != formats[a] or
                        entry.attrib_strides[a] != strides[a] or
                        entry.attrib_offsets[a] != offsets[a])
                    {
                        match = false;
                        break;
                    }
                }
                if (match) return entry.sg_pip;
            }
        }

        // Cache miss: Create pipeline
        var pip_desc: sg.PipelineDesc = .{};
        pip_desc.shader = p.sg_shader;
        pip_desc.primitive_type = primitive_type;

        for (0..p.attr_count) |i| {
            const loc = p.attrs[i].index;
            if (loc < MAX_ATTRIBS and self.attribs[loc].enabled) {
                pip_desc.layout.attrs[loc].format = formats[loc];
                pip_desc.layout.attrs[loc].offset = @intCast(offsets[loc]);
                pip_desc.layout.attrs[loc].buffer_index = 0;
                if (strides[loc] > 0) {
                    pip_desc.layout.buffers[0].stride = strides[loc];
                }
            }
        }

        if (self.blend_enabled) {
            pip_desc.colors[0].blend.enabled = true;
            pip_desc.colors[0].blend.src_factor_rgb = toSokolBlendFactor(self.blend_src);
            pip_desc.colors[0].blend.dst_factor_rgb = toSokolBlendFactor(self.blend_dst);
            pip_desc.colors[0].blend.src_factor_alpha = .ONE;
            pip_desc.colors[0].blend.dst_factor_alpha = .ONE_MINUS_SRC_ALPHA;
        }

        if (self.depth_enabled) {
            pip_desc.depth.write_enabled = true;
            pip_desc.depth.compare = .LESS_EQUAL;
        }

        const pip = sg.makePipeline(pip_desc);
        if (pip.id == 0) return null;

        if (self.pipeline_count < MAX_PIPELINES) {
            self.pipelines[self.pipeline_count] = .{
                .program_id = prog_id,
                .primitive_type = primitive_type,
                .attrib_mask = attrib_mask,
                .attrib_formats = formats,
                .attrib_strides = strides,
                .attrib_offsets = offsets,
                .blend_enabled = self.blend_enabled,
                .depth_enabled = self.depth_enabled,
                .sg_pip = pip,
                .valid = true,
            };
            self.pipeline_count += 1;
        }

        return pip;
    }

    pub fn drawArrays(self: *WebGLRenderingContext, mode: u32, first: i32, count: i32) void {
        if (count <= 0) return;
        const prog_id = (self.active_program orelse return).id;
        const p = &self.programs[prog_id];

        const prim = toSokolPrimitive(mode);
        const pip = self.getOrCreatePipeline(prim) orelse return;

        self.ensurePass();

        sg.applyPipeline(pip);

        // Bind vertex buffers
        var bindings: sg.Bindings = .{};
        // Use the buffer bound to the first enabled attribute, or currently bound ARRAY_BUFFER
        var bound_vbo = self.bound_array_buffer;
        for (0..MAX_ATTRIBS) |a| {
            if (self.attribs[a].enabled and self.attribs[a].buffer.id != 0) {
                bound_vbo = self.attribs[a].buffer;
                break;
            }
        }

        if (bound_vbo) |b| {
            if (b.id != 0 and b.id < MAX_BUFFERS) {
                bindings.vertex_buffers[0] = self.buffers[b.id].sg_buf;
            }
        }
        sg.applyBindings(bindings);

        // Apply uniforms if present
        if (p.uniform_count > 0 and p.uniform_total_bytes > 0) {
            sg.applyUniforms(0, .{
                .ptr = &p.uniform_storage,
                .size = p.uniform_total_bytes,
            });
        }

        sg.draw(@intCast(@max(0, first)), @intCast(count), 1);
    }

    pub fn drawElements(self: *WebGLRenderingContext, mode: u32, count: i32, type_: u32, offset: usize) void {
        _ = type_;
        if (count <= 0) return;
        const prog_id = (self.active_program orelse return).id;
        const p = &self.programs[prog_id];

        const prim = toSokolPrimitive(mode);
        const pip = self.getOrCreatePipeline(prim) orelse return;

        self.ensurePass();

        sg.applyPipeline(pip);

        var bindings: sg.Bindings = .{};
        if (self.bound_array_buffer) |b| {
            if (b.id != 0 and b.id < MAX_BUFFERS) {
                bindings.vertex_buffers[0] = self.buffers[b.id].sg_buf;
            }
        }
        if (self.bound_element_buffer) |eb| {
            if (eb.id != 0 and eb.id < MAX_BUFFERS) {
                bindings.index_buffer = self.buffers[eb.id].sg_buf;
            }
        }
        sg.applyBindings(bindings);

        if (p.uniform_count > 0 and p.uniform_total_bytes > 0) {
            sg.applyUniforms(0, .{
                .ptr = &p.uniform_storage,
                .size = p.uniform_total_bytes,
            });
        }

        const base_element: u32 = @intCast(offset / 2); // assuming 16-bit indices
        sg.draw(base_element, @intCast(count), 1);
    }
};

// Global default instance for WebGL state
pub var default_context: WebGLRenderingContext = WebGLRenderingContext.init();

// Top-level WebGL functions operating on default_context
pub fn createBuffer() Buffer { return default_context.createBuffer(); }
pub fn deleteBuffer(buf: Buffer) void { default_context.deleteBuffer(buf); }
pub fn bindBuffer(target: u32, buf: ?Buffer) void { default_context.bindBuffer(target, buf); }
pub fn bufferData(target: u32, data_bytes: []const u8, usage: u32) void { default_context.bufferData(target, data_bytes, usage); }
pub fn bufferDataSlice(target: u32, comptime T: type, slice: []const T, usage: u32) void { default_context.bufferDataSlice(target, T, slice, usage); }

pub fn createShader(shader_type: u32) ?Shader { return default_context.createShader(shader_type); }
pub fn shaderSource(shd: Shader, source: []const u8) void { default_context.shaderSource(shd, source); }
pub fn compileShader(shd: Shader) void { default_context.compileShader(shd); }
pub fn createProgram() ?Program { return default_context.createProgram(); }
pub fn attachShader(prog: Program, shd: Shader) void { default_context.attachShader(prog, shd); }
pub fn linkProgram(prog: Program) void { default_context.linkProgram(prog); }
pub fn useProgram(prog: ?Program) void { default_context.useProgram(prog); }
pub fn getAttribLocation(prog: Program, name: []const u8) AttribLocation { return default_context.getAttribLocation(prog, name); }
pub fn getUniformLocation(prog: Program, name: []const u8) UniformLocation { return default_context.getUniformLocation(prog, name); }

pub fn enableVertexAttribArray(index: u32) void { default_context.enableVertexAttribArray(index); }
pub fn disableVertexAttribArray(index: u32) void { default_context.disableVertexAttribArray(index); }
pub fn vertexAttribPointer(index: u32, size: i32, type_: u32, normalized: bool, stride: i32, offset: usize) void {
    default_context.vertexAttribPointer(index, size, type_, normalized, stride, offset);
}

pub fn uniform1f(loc: UniformLocation, x: f32) void { default_context.uniform1f(loc, x); }
pub fn uniform2f(loc: UniformLocation, x: f32, y: f32) void { default_context.uniform2f(loc, x, y); }
pub fn uniform3f(loc: UniformLocation, x: f32, y: f32, z: f32) void { default_context.uniform3f(loc, x, y, z); }
pub fn uniform4f(loc: UniformLocation, x: f32, y: f32, z: f32, w: f32) void { default_context.uniform4f(loc, x, y, z, w); }
pub fn uniform1i(loc: UniformLocation, x: i32) void { default_context.uniform1i(loc, x); }
pub fn uniformMatrix4fv(loc: UniformLocation, transpose: bool, value: []const f32) void { default_context.uniformMatrix4fv(loc, transpose, value); }

pub fn viewport(x: i32, y: i32, width: i32, height: i32) void { default_context.viewport(x, y, width, height); }
pub fn clearColor(r: f32, g: f32, b: f32, a: f32) void { default_context.clearColor(r, g, b, a); }
pub fn clear(mask: u32) void { default_context.clear(mask); }
pub fn enable(cap: u32) void { default_context.enable(cap); }
pub fn disable(cap: u32) void { default_context.disable(cap); }
pub fn blendFunc(sfactor: u32, dfactor: u32) void { default_context.blendFunc(sfactor, dfactor); }

pub fn drawArrays(mode: u32, first: i32, count: i32) void { default_context.drawArrays(mode, first, count); }
pub fn drawElements(mode: u32, count: i32, type_: u32, offset: usize) void { default_context.drawElements(mode, count, type_, offset); }
pub fn present() void { default_context.present(); }


// ============================================================================
// Helper Mapping Functions: WebGL -> Sokol
// ============================================================================

fn toSokolPrimitive(mode: u32) sg.PrimitiveType {
    return switch (mode) {
        POINTS => .POINTS,
        LINES => .LINES,
        LINE_STRIP => .LINE_STRIP,
        TRIANGLES => .TRIANGLES,
        TRIANGLE_STRIP => .TRIANGLE_STRIP,
        else => .TRIANGLES,
    };
}

fn toSokolVertexFormat(size: i32, type_: u32, normalized: bool) sg.VertexFormat {
    _ = normalized;
    if (type_ == FLOAT) {
        return switch (size) {
            1 => .FLOAT,
            2 => .FLOAT2,
            3 => .FLOAT3,
            4 => .FLOAT4,
            else => .FLOAT4,
        };
    } else if (type_ == UNSIGNED_BYTE) {
        return switch (size) {
            4 => .UBYTE4N,
            else => .UBYTE4,
        };
    }
    return .FLOAT4;
}

fn toSokolBlendFactor(factor: u32) sg.BlendFactor {
    return switch (factor) {
        ZERO => .ZERO,
        ONE => .ONE,
        SRC_COLOR => .SRC_COLOR,
        ONE_MINUS_SRC_COLOR => .ONE_MINUS_SRC_COLOR,
        SRC_ALPHA => .SRC_ALPHA,
        ONE_MINUS_SRC_ALPHA => .ONE_MINUS_SRC_ALPHA,
        DST_ALPHA => .DST_ALPHA,
        ONE_MINUS_DST_ALPHA => .ONE_MINUS_DST_ALPHA,
        else => .ONE,
    };
}

// ============================================================================
// Automatic GLSL Attribute & Uniform Parser (Reflection)
// ============================================================================

fn isWhitespace(ch: u8) bool {
    return ch == ' ' or ch == '\t' or ch == '\r' or ch == '\n';
}

fn isIdentChar(ch: u8) bool {
    return (ch >= 'a' and ch <= 'z') or
        (ch >= 'A' and ch <= 'Z') or
        (ch >= '0' and ch <= '9') or
        ch == '_';
}

fn parseAttributes(vs_source: []const u8, out_attrs: *[MAX_ATTRIBS]AttribInfo) usize {
    var count: usize = 0;
    var i: usize = 0;
    const len = vs_source.len;

    while (i < len and count < MAX_ATTRIBS) {
        // Skip whitespace
        while (i < len and isWhitespace(vs_source[i])) : (i += 1) {}
        if (i >= len) break;

        // Skip comments
        if (i + 1 < len and vs_source[i] == '/' and vs_source[i + 1] == '/') {
            while (i < len and vs_source[i] != '\n') : (i += 1) {}
            continue;
        }

        // Match keyword "attribute" or "in"
        var is_attr = false;
        if (i + 9 <= len and std.mem.eql(u8, vs_source[i .. i + 9], "attribute") and isWhitespace(vs_source[i + 9])) {
            is_attr = true;
            i += 9;
        } else if (i + 2 <= len and std.mem.eql(u8, vs_source[i .. i + 2], "in") and isWhitespace(vs_source[i + 2])) {
            is_attr = true;
            i += 2;
        }

        if (is_attr) {
            // Skip whitespace to type
            while (i < len and isWhitespace(vs_source[i])) : (i += 1) {}
            // Skip type token
            while (i < len and isIdentChar(vs_source[i])) : (i += 1) {}
            // Skip whitespace to name
            while (i < len and isWhitespace(vs_source[i])) : (i += 1) {}

            // Read name
            const start = i;
            while (i < len and isIdentChar(vs_source[i])) : (i += 1) {}
            const name_token = vs_source[start..i];

            if (name_token.len > 0 and name_token.len < 32) {
                out_attrs[count] = .{};
                @memcpy(out_attrs[count].name[0..name_token.len], name_token);
                out_attrs[count].name[name_token.len] = 0;
                out_attrs[count].name_len = name_token.len;
                out_attrs[count].index = @intCast(count);
                count += 1;
            }
        } else {
            // Advance to next token
            while (i < len and !isWhitespace(vs_source[i])) : (i += 1) {}
        }
    }
    return count;
}

fn parseUniforms(
    vs_source: []const u8,
    fs_source: []const u8,
    out_uniforms: *[MAX_UNIFORMS]UniformInfo,
    out_total_bytes: *usize,
) usize {
    var count: usize = 0;
    var current_offset: usize = 0;

    const sources = [_][]const u8{ vs_source, fs_source };
    for (sources) |src| {
        var i: usize = 0;
        const len = src.len;

        while (i < len and count < MAX_UNIFORMS) {
            while (i < len and isWhitespace(src[i])) : (i += 1) {}
            if (i >= len) break;

            if (i + 1 < len and src[i] == '/' and src[i + 1] == '/') {
                while (i < len and src[i] != '\n') : (i += 1) {}
                continue;
            }

            if (i + 7 <= len and std.mem.eql(u8, src[i .. i + 7], "uniform") and isWhitespace(src[i + 7])) {
                i += 7;
                while (i < len and isWhitespace(src[i])) : (i += 1) {}

                // Read type
                const type_start = i;
                while (i < len and isIdentChar(src[i])) : (i += 1) {}
                const type_token = src[type_start..i];

                while (i < len and isWhitespace(src[i])) : (i += 1) {}

                // Read name
                const name_start = i;
                while (i < len and isIdentChar(src[i])) : (i += 1) {}
                const name_token = src[name_start..i];

                // Check if duplicate already parsed
                var exists = false;
                for (0..count) |c| {
                    if (std.mem.eql(u8, out_uniforms[c].name[0..out_uniforms[c].name_len], name_token)) {
                        exists = true;
                        break;
                    }
                }

                if (!exists and name_token.len > 0 and name_token.len < 32) {
                    var u_type: sg.UniformType = .INVALID;
                    var u_size: usize = 0;
                    var u_align: usize = 4;

                    if (std.mem.eql(u8, type_token, "float")) {
                        u_type = .FLOAT;
                        u_size = 4;
                        u_align = 4;
                    } else if (std.mem.eql(u8, type_token, "vec2")) {
                        u_type = .FLOAT2;
                        u_size = 8;
                        u_align = 8;
                    } else if (std.mem.eql(u8, type_token, "vec3")) {
                        u_type = .FLOAT3;
                        u_size = 12;
                        u_align = 16;
                    } else if (std.mem.eql(u8, type_token, "vec4")) {
                        u_type = .FLOAT4;
                        u_size = 16;
                        u_align = 16;
                    } else if (std.mem.eql(u8, type_token, "mat4")) {
                        u_type = .MAT4;
                        u_size = 64;
                        u_align = 16;
                    } else if (std.mem.eql(u8, type_token, "int")) {
                        u_type = .INT;
                        u_size = 4;
                        u_align = 4;
                    }

                    if (u_type != .INVALID) {
                        // Align offset
                        current_offset = std.mem.alignForward(usize, current_offset, u_align);

                        out_uniforms[count] = .{
                            .type = u_type,
                            .offset = current_offset,
                            .size = u_size,
                            .count = 1,
                            .name_len = name_token.len,
                        };
                        @memcpy(out_uniforms[count].name[0..name_token.len], name_token);
                        out_uniforms[count].name[name_token.len] = 0;

                        current_offset += u_size;
                        count += 1;
                    }
                }
            } else {
                while (i < len and !isWhitespace(src[i])) : (i += 1) {}
            }
        }
    }

    // Align total uniform block size to 16 bytes (std140 requirement)
    out_total_bytes.* = std.mem.alignForward(usize, current_offset, 16);
    return count;
}

test "GLSL parser reflection" {
    const vs =
        \\#version 330
        \\in vec2 position;
        \\in vec4 color;
        \\uniform vec2 u_offset;
        \\void main() {
        \\    gl_Position = vec4(position + u_offset, 0.0, 1.0);
        \\}
    ;
    const fs =
        \\#version 330
        \\uniform vec4 u_color;
        \\out vec4 frag_color;
        \\void main() {
        \\    frag_color = u_color;
        \\}
    ;

    var attrs: [MAX_ATTRIBS]AttribInfo = undefined;
    const attr_count = parseAttributes(vs, &attrs);
    try std.testing.expectEqual(@as(usize, 2), attr_count);
    try std.testing.expectEqualStrings("position", attrs[0].name[0..attrs[0].name_len]);
    try std.testing.expectEqualStrings("color", attrs[1].name[0..attrs[1].name_len]);

    var uniforms: [MAX_UNIFORMS]UniformInfo = undefined;
    var total_bytes: usize = 0;
    const uni_count = parseUniforms(vs, fs, &uniforms, &total_bytes);
    try std.testing.expectEqual(@as(usize, 2), uni_count);
    try std.testing.expectEqualStrings("u_offset", uniforms[0].name[0..uniforms[0].name_len]);
    try std.testing.expectEqualStrings("u_color", uniforms[1].name[0..uniforms[1].name_len]);
}

test "GLSL parser reflection mat4 and float" {
    const vs =
        \\#version 330
        \\attribute vec3 a_pos;
        \\uniform mat4 u_proj;
        \\uniform float u_time;
        \\void main() {
        \\    gl_Position = u_proj * vec4(a_pos, 1.0);
        \\}
    ;
    const fs =
        \\#version 330
        \\void main() {}
    ;

    var attrs: [MAX_ATTRIBS]AttribInfo = undefined;
    const attr_count = parseAttributes(vs, &attrs);
    try std.testing.expectEqual(@as(usize, 1), attr_count);
    try std.testing.expectEqualStrings("a_pos", attrs[0].name[0..attrs[0].name_len]);

    var uniforms: [MAX_UNIFORMS]UniformInfo = undefined;
    var total_bytes: usize = 0;
    const uni_count = parseUniforms(vs, fs, &uniforms, &total_bytes);
    try std.testing.expectEqual(@as(usize, 2), uni_count);
    try std.testing.expectEqualStrings("u_proj", uniforms[0].name[0..uniforms[0].name_len]);
    try std.testing.expectEqual(sg.UniformType.MAT4, uniforms[0].type);
    try std.testing.expectEqual(@as(usize, 64), uniforms[0].size);
    try std.testing.expectEqualStrings("u_time", uniforms[1].name[0..uniforms[1].name_len]);
    try std.testing.expectEqual(sg.UniformType.FLOAT, uniforms[1].type);
}

test "Buffer lifecycle state management" {
    var ctx = WebGLRenderingContext.init();
    const b1 = ctx.createBuffer();
    try std.testing.expect(b1.id > 0);
    ctx.bindBuffer(ARRAY_BUFFER, b1);
    try std.testing.expectEqual(b1.id, ctx.bound_array_buffer.?.id);

    ctx.deleteBuffer(b1);
    try std.testing.expect(!ctx.buffers[b1.id].allocated);
}

