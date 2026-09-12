const std = @import("std");
const sokol = @import("sokol");
const saudio = sokol.audio;
const slog = sokol.log;

pub const SfxType = enum {
    none,
    step,
    attack,
    hit,
    heal,
    tame_success,
    tame_fail,
    breakthrough,
};

var current_sfx: SfxType = .none;
var sfx_phase: f32 = 0.0;
var sfx_progress: usize = 0;
var sfx_total_samples: usize = 0;

pub fn init() void {
    saudio.setup(.{
        .logger = .{ .func = slog.func },
    });
    std.debug.print(">> [Audio]: Procedural Xianxia SFX Engine Initialized!\n", .{});
}

pub fn play(sfx: SfxType) void {
    current_sfx = sfx;
    sfx_phase = 0.0;
    sfx_progress = 0;

    sfx_total_samples = switch (sfx) {
        .step => 2000,
        .attack => 8000,
        .hit => 6000,
        .heal => 16000,
        .tame_success => 24000,
        .tame_fail => 10000,
        .breakthrough => 32000,
        .none => 0,
    };
}

var audio_prng: u32 = 0x1337BEEF;
fn audioRand() f32 {
    audio_prng ^= (audio_prng << 13);
    audio_prng ^= (audio_prng >> 17);
    audio_prng ^= (audio_prng << 5);
    return @as(f32, @floatFromInt(audio_prng & 0xFFFF)) / 65535.0;
}

pub fn update() void {
    if (current_sfx == .none) return;

    const num_frames = saudio.expect();
    if (num_frames <= 0) return;

    var samples: [512]f32 = undefined;
    const to_write = @min(@as(usize, @intCast(num_frames)), samples.len);

    const sample_rate = @as(f32, @floatFromInt(saudio.sampleRate()));

    for (0..to_write) |i| {
        if (sfx_progress >= sfx_total_samples) {
            current_sfx = .none;
            samples[i] = 0.0;
            continue;
        }

        const t = @as(f32, @floatFromInt(sfx_progress)) / @as(f32, @floatFromInt(sfx_total_samples));
        var sample: f32 = 0.0;

        switch (current_sfx) {
            .step => {
                // Tiếng bước chân nhẹ nhàng
                const freq: f32 = 180.0 - t * 80.0;
                sfx_phase += freq / sample_rate;
                const env = 1.0 - t;
                sample = @sin(sfx_phase * std.math.tau) * env * 0.15;
            },
            .attack => {
                // Tiếng kiếm khí / hỏa diễm rít
                const freq: f32 = 800.0 - t * 650.0;
                sfx_phase += freq / sample_rate;
                const env = (1.0 - t) * (1.0 - t);
                const noise = (audioRand() * 2.0 - 1.0) * 0.3;
                sample = (@sin(sfx_phase * std.math.tau) * 0.7 + noise) * env * 0.3;
            },
            .hit => {
                // Tiếng va chạm nặng
                const freq: f32 = 120.0 * (1.0 - t);
                sfx_phase += freq / sample_rate;
                const noise = (audioRand() * 2.0 - 1.0) * 0.5;
                const env = 1.0 - t;
                sample = (@sin(sfx_phase * std.math.tau) * 0.5 + noise) * env * 0.35;
            },
            .heal => {
                // Tiếng hồi xuân thuật ấm áp
                const freq: f32 = 440.0 + @sin(t * 12.0) * 80.0;
                sfx_phase += freq / sample_rate;
                const env = @sin(t * std.math.pi);
                sample = @sin(sfx_phase * std.math.tau) * env * 0.25;
            },
            .tame_success => {
                // Khúc nhạc thu phục thành công (Đô - Mi - Sol - Đố)
                const note_idx = @as(usize, @intFromFloat(t * 4.0));
                const freqs = [_]f32{ 523.25, 659.25, 783.99, 1046.50 };
                const freq = freqs[@min(note_idx, 3)];
                sfx_phase += freq / sample_rate;
                const sub_t = @mod(t * 4.0, 1.0);
                const env = 1.0 - sub_t * 0.7;
                sample = @sin(sfx_phase * std.math.tau) * env * 0.3;
            },
            .tame_fail => {
                // Tiếng kháng cự thất bại
                const freq: f32 = 180.0 + (audioRand() * 40.0);
                sfx_phase += freq / sample_rate;
                const env = 1.0 - t;
                sample = @sin(sfx_phase * std.math.tau) * env * 0.25;
            },
            .breakthrough => {
                // Khúc nhạc đột phá đại cảnh giới
                const freq: f32 = 300.0 + t * 900.0;
                sfx_phase += freq / sample_rate;
                const env = @sin(t * std.math.pi);
                sample = (@sin(sfx_phase * std.math.tau) + 0.5 * @sin(sfx_phase * 2.0 * std.math.tau)) * env * 0.3;
            },
            .none => {},
        }

        samples[i] = sample;
        sfx_progress += 1;
    }

    _ = saudio.push(&samples[0], @intCast(to_write));
}

pub fn cleanup() void {
    saudio.shutdown();
}
