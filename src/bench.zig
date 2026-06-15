//! Tiny reusable micro-benchmark harness.
//!
//! Import and call `run` from any file (including tests):
//!
//!     const bench = @import("bench.zig");
//!
//!     fn work(allocator: std.mem.Allocator) !void {
//!         var m = try Maze.init(allocator, 42, 0, 0, 32, 32);
//!         m.deinit(allocator);
//!     }
//!
//!     const stats = try bench.run(io, .{}, work, .{allocator});
//!     std.log.info("{f}", .{stats});
const std = @import("std");

pub const Options = struct {
    /// Untimed runs to prime allocator/caches/branch predictors.
    warmup: usize = 5,
    /// Timed runs folded into the returned stats.
    iters: usize = 100,
};

pub const Stats = struct {
    iters: usize,
    min_ns: u64,
    max_ns: u64,
    total_ns: u64,

    pub fn meanNs(self: Stats) u64 {
        return if (self.iters == 0) 0 else self.total_ns / self.iters;
    }

    pub fn minMs(self: Stats) f64 {
        return nsToMs(self.min_ns);
    }
    pub fn meanMs(self: Stats) f64 {
        return nsToMs(self.meanNs());
    }
    pub fn maxMs(self: Stats) f64 {
        return nsToMs(self.max_ns);
    }

    pub fn format(self: Stats, w: *std.Io.Writer) !void {
        try w.print("{d} iters | min {d:.4}ms  mean {d:.4}ms  max {d:.4}ms", .{
            self.iters, self.minMs(), self.meanMs(), self.maxMs(),
        });
    }
};

/// Time `@call(func, args)` over `opts.iters` runs (after `opts.warmup`
/// untimed ones) and return min/mean/max.
///
/// `func` should be self-contained: do any allocation AND its cleanup inside,
/// so teardown is part of the measured window only if you want it to be.
/// `func` may return `void`, a value (discarded), or an error union (errors
/// abort the whole bench).
pub fn run(io: std.Io, opts: Options, comptime func: anytype, args: anytype) !Stats {
    var i: usize = 0;
    while (i < opts.warmup) : (i += 1) {
        try call(func, args);
    }

    var stats: Stats = .{
        .iters = opts.iters,
        .min_ns = std.math.maxInt(u64),
        .max_ns = 0,
        .total_ns = 0,
    };

    i = 0;
    while (i < opts.iters) : (i += 1) {
        const t0 = std.Io.Clock.now(.awake, io);
        try call(func, args);
        const t1 = std.Io.Clock.now(.awake, io);

        const ns: u64 = @intCast(t0.durationTo(t1).nanoseconds);
        stats.min_ns = @min(stats.min_ns, ns);
        stats.max_ns = @max(stats.max_ns, ns);
        stats.total_ns += ns;
    }

    return stats;
}

/// Call `func`, propagating errors but discarding any non-error result.
/// Accepts func returning void, a value, or an error union of either.
inline fn call(comptime func: anytype, args: anytype) !void {
    const result = @call(.auto, func, args);
    switch (@typeInfo(@TypeOf(result))) {
        .error_union => _ = try result,
        else => {},
    }
}

fn nsToMs(ns: u64) f64 {
    return @as(f64, @floatFromInt(ns)) / std.time.ns_per_ms;
}
