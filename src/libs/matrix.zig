const std = @import("std");

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    pub fn scale(v: Vec3, s: f32) Vec3 {
        return .{ .x = v.x * s, .y = v.y * s, .z = v.z * s };
    }

    pub fn dot(a: Vec3, b: Vec3) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }

    pub fn length(v: Vec3) f32 {
        return @sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    }

    pub fn normalize(v: Vec3) Vec3 {
        const len = v.length();
        if (len > 0.00001) {
            const inv = 1.0 / len;
            return .{ .x = v.x * inv, .y = v.y * inv, .z = v.z * inv };
        }
        return .{ .x = 0.0, .y = 0.0, .z = 0.0 };
    }
};

pub const Vec4 = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub fn init(x: f32, y: f32, z: f32, w: f32) Vec4 {
        return .{ .x = x, .y = y, .z = z, .w = w };
    }
};

/// Ma trận 4x4 theo chuẩn Column-Major cho WebGL / OpenGL
pub const Mat4 = struct {
    data: [16]f32 = [_]f32{
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    },

    pub fn identity() Mat4 {
        return .{};
    }

    pub fn zero() Mat4 {
        return .{ .data = [_]f32{0} ** 16 };
    }

    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        var res = Mat4.zero();
        var col: usize = 0;
        while (col < 4) : (col += 1) {
            var row: usize = 0;
            while (row < 4) : (row += 1) {
                var sum: f32 = 0.0;
                var k: usize = 0;
                while (k < 4) : (k += 1) {
                    sum += a.data[k * 4 + row] * b.data[col * 4 + k];
                }
                res.data[col * 4 + row] = sum;
            }
        }
        return res;
    }

    pub fn translation(x: f32, y: f32, z: f32) Mat4 {
        var m = Mat4.identity();
        m.data[12] = x;
        m.data[13] = y;
        m.data[14] = z;
        return m;
    }

    pub fn scaling(x: f32, y: f32, z: f32) Mat4 {
        var m = Mat4.identity();
        m.data[0] = x;
        m.data[5] = y;
        m.data[10] = z;
        return m;
    }

    pub fn rotationX(rad: f32) Mat4 {
        var m = Mat4.identity();
        const c = @cos(rad);
        const s = @sin(rad);
        m.data[5] = c;
        m.data[6] = s;
        m.data[9] = -s;
        m.data[10] = c;
        return m;
    }

    pub fn rotationY(rad: f32) Mat4 {
        var m = Mat4.identity();
        const c = @cos(rad);
        const s = @sin(rad);
        m.data[0] = c;
        m.data[2] = -s;
        m.data[8] = s;
        m.data[10] = c;
        return m;
    }

    pub fn rotationZ(rad: f32) Mat4 {
        var m = Mat4.identity();
        const c = @cos(rad);
        const s = @sin(rad);
        m.data[0] = c;
        m.data[1] = s;
        m.data[4] = -s;
        m.data[5] = c;
        return m;
    }

    pub fn lookAt(eye: Vec3, target: Vec3, up: Vec3) Mat4 {
        const forward = Vec3.sub(target, eye).normalize();
        const right = Vec3.cross(forward, up).normalize();
        const true_up = Vec3.cross(right, forward);

        var m = Mat4.identity();
        // Cột 0
        m.data[0] = right.x;
        m.data[1] = true_up.x;
        m.data[2] = -forward.x;
        m.data[3] = 0.0;
        // Cột 1
        m.data[4] = right.y;
        m.data[5] = true_up.y;
        m.data[6] = -forward.y;
        m.data[7] = 0.0;
        // Cột 2
        m.data[8] = right.z;
        m.data[9] = true_up.z;
        m.data[10] = -forward.z;
        m.data[11] = 0.0;
        // Cột 3
        m.data[12] = -Vec3.dot(right, eye);
        m.data[13] = -Vec3.dot(true_up, eye);
        m.data[14] = Vec3.dot(forward, eye);
        m.data[15] = 1.0;

        return m;
    }

    pub fn perspective(fov_y_rad: f32, aspect: f32, near: f32, far: f32) Mat4 {
        var m = Mat4.zero();
        const f = 1.0 / @tan(fov_y_rad * 0.5);

        m.data[0] = f / aspect;
        m.data[5] = f;
        m.data[10] = (far + near) / (near - far);
        m.data[11] = -1.0;
        m.data[14] = (2.0 * far * near) / (near - far);
        return m;
    }

    /// Ánh xạ Viewport NDC để hiển thị camera 3D chuẩn xác trong vùng cửa sổ con
    pub fn viewportMapping(ndc_center_x: f32, ndc_center_y: f32, ndc_half_w: f32, ndc_half_h: f32) Mat4 {
        var m = Mat4.identity();
        m.data[0] = ndc_half_w;
        m.data[5] = ndc_half_h;
        m.data[10] = 1.0;
        m.data[12] = ndc_center_x;
        m.data[13] = ndc_center_y;
        m.data[15] = 1.0;
        return m;
    }

    pub fn transformVec4(m: Mat4, v: Vec4) Vec4 {
        return .{
            .x = m.data[0] * v.x + m.data[4] * v.y + m.data[8] * v.z + m.data[12] * v.w,
            .y = m.data[1] * v.x + m.data[5] * v.y + m.data[9] * v.z + m.data[13] * v.w,
            .z = m.data[2] * v.x + m.data[6] * v.y + m.data[10] * v.z + m.data[14] * v.w,
            .w = m.data[3] * v.x + m.data[7] * v.y + m.data[11] * v.z + m.data[15] * v.w,
        };
    }

    pub fn transformPoint(m: Mat4, p: Vec3) Vec3 {
        const v = m.transformVec4(.{ .x = p.x, .y = p.y, .z = p.z, .w = 1.0 });
        if (@abs(v.w) > 0.00001) {
            const inv = 1.0 / v.w;
            return .{ .x = v.x * inv, .y = v.y * inv, .z = v.z * inv };
        }
        return .{ .x = v.x, .y = v.y, .z = v.z };
    }

    pub fn inverse(m: Mat4) ?Mat4 {
        const s = m.data;
        var inv: [16]f32 = undefined;

        inv[0] = s[5] * s[10] * s[15] - s[5] * s[11] * s[14] - s[9] * s[6] * s[15] + s[9] * s[7] * s[14] + s[13] * s[6] * s[11] - s[13] * s[7] * s[10];
        inv[4] = -s[4] * s[10] * s[15] + s[4] * s[11] * s[14] + s[8] * s[6] * s[15] - s[8] * s[7] * s[14] - s[12] * s[6] * s[11] + s[12] * s[7] * s[10];
        inv[8] = s[4] * s[9] * s[15] - s[4] * s[11] * s[13] - s[8] * s[5] * s[15] + s[8] * s[7] * s[13] + s[12] * s[5] * s[11] - s[12] * s[7] * s[9];
        inv[12] = -s[4] * s[9] * s[14] + s[4] * s[10] * s[13] + s[8] * s[5] * s[14] - s[8] * s[6] * s[13] - s[12] * s[5] * s[10] + s[12] * s[6] * s[9];

        inv[1] = -s[1] * s[10] * s[15] + s[1] * s[11] * s[14] + s[9] * s[2] * s[15] - s[9] * s[3] * s[14] - s[13] * s[2] * s[11] + s[13] * s[3] * s[10];
        inv[5] = s[0] * s[10] * s[15] - s[0] * s[11] * s[14] - s[8] * s[2] * s[15] + s[8] * s[3] * s[14] + s[12] * s[2] * s[11] - s[12] * s[3] * s[10];
        inv[9] = -s[0] * s[9] * s[15] + s[0] * s[11] * s[13] + s[8] * s[1] * s[15] - s[8] * s[3] * s[13] - s[12] * s[1] * s[11] + s[12] * s[3] * s[9];
        inv[13] = s[0] * s[9] * s[14] - s[0] * s[10] * s[13] - s[8] * s[1] * s[14] + s[8] * s[2] * s[13] + s[12] * s[1] * s[10] - s[12] * s[2] * s[9];

        inv[2] = s[1] * s[6] * s[15] - s[1] * s[7] * s[14] - s[5] * s[2] * s[15] + s[5] * s[3] * s[14] + s[13] * s[2] * s[7] - s[13] * s[3] * s[6];
        inv[6] = -s[0] * s[6] * s[15] + s[0] * s[7] * s[14] + s[4] * s[2] * s[15] - s[4] * s[3] * s[14] - s[12] * s[2] * s[7] + s[12] * s[3] * s[6];
        inv[10] = s[0] * s[5] * s[15] - s[0] * s[7] * s[13] - s[4] * s[1] * s[15] + s[4] * s[3] * s[13] + s[12] * s[1] * s[7] - s[12] * s[3] * s[5];
        inv[14] = -s[0] * s[5] * s[14] + s[0] * s[6] * s[13] + s[4] * s[1] * s[14] - s[4] * s[2] * s[13] - s[12] * s[1] * s[6] + s[12] * s[2] * s[5];

        inv[3] = -s[1] * s[6] * s[11] + s[1] * s[7] * s[10] + s[5] * s[2] * s[11] - s[5] * s[3] * s[10] - s[9] * s[2] * s[7] + s[9] * s[3] * s[6];
        inv[7] = s[0] * s[6] * s[11] - s[0] * s[7] * s[10] - s[4] * s[2] * s[11] + s[4] * s[3] * s[10] + s[8] * s[2] * s[7] - s[8] * s[3] * s[6];
        inv[11] = -s[0] * s[5] * s[11] + s[0] * s[7] * s[9] + s[4] * s[1] * s[11] - s[4] * s[3] * s[9] - s[8] * s[1] * s[7] + s[8] * s[3] * s[5];
        inv[15] = s[0] * s[5] * s[10] - s[0] * s[6] * s[9] - s[4] * s[1] * s[10] + s[4] * s[2] * s[9] + s[8] * s[1] * s[6] - s[8] * s[2] * s[5];

        var det = s[0] * inv[0] + s[1] * inv[4] + s[2] * inv[8] + s[3] * inv[12];
        if (@abs(det) < 0.000001) return null;

        det = 1.0 / det;
        var res = Mat4.zero();
        for (0..16) |i| {
            res.data[i] = inv[i] * det;
        }
        return res;
    }

    /// Bắn tia 3D từ tọa độ NDC (-1..1) qua ma trận nghịch đảo View-Projection
    pub fn unprojectRay(ndc_x: f32, ndc_y: f32, inv_vp: Mat4) struct { origin: Vec3, dir: Vec3 } {
        const p_near = inv_vp.transformPoint(.{ .x = ndc_x, .y = ndc_y, .z = -1.0 });
        const p_far = inv_vp.transformPoint(.{ .x = ndc_x, .y = ndc_y, .z = 1.0 });
        const dir = Vec3.sub(p_far, p_near).normalize();
        return .{ .origin = p_near, .dir = dir };
    }

    /// Cắt tia với mặt phẳng nằm ngang Y = plane_y (mặt sàn lôi đài)
    pub fn intersectPlaneY(ray_orig: Vec3, ray_dir: Vec3, plane_y: f32) ?Vec3 {
        if (@abs(ray_dir.y) < 0.00001) return null;
        const t = (plane_y - ray_orig.y) / ray_dir.y;
        if (t < 0.0) return null;
        return Vec3.add(ray_orig, Vec3.scale(ray_dir, t));
    }
};

test "Mat4 identity and mul" {
    const a = Mat4.identity();
    const b = Mat4.translation(3.0, 4.0, 5.0);
    const c = Mat4.mul(a, b);
    try std.testing.expectApproxEqAbs(c.data[12], 3.0, 0.0001);
    try std.testing.expectApproxEqAbs(c.data[13], 4.0, 0.0001);
    try std.testing.expectApproxEqAbs(c.data[14], 5.0, 0.0001);
}

test "Mat4 inverse and unproject" {
    const eye = Vec3.init(0.0, 8.0, 8.0);
    const target = Vec3.init(0.0, 0.0, 0.0);
    const up = Vec3.init(0.0, 1.0, 0.0);
    const v = Mat4.lookAt(eye, target, up);
    const p = Mat4.perspective(std.math.degreesToRadians(45.0), 1.333, 0.1, 100.0);
    const vp = Mat4.mul(p, v);

    const inv = Mat4.inverse(vp);
    try std.testing.expect(inv != null);

    const ray = Mat4.unprojectRay(0.0, 0.0, inv.?);
    const hit = Mat4.intersectPlaneY(ray.origin, ray.dir, 0.0);
    try std.testing.expect(hit != null);
    try std.testing.expectApproxEqAbs(hit.?.x, 0.0, 0.01);
    try std.testing.expectApproxEqAbs(hit.?.y, 0.0, 0.01);
}
