const std = @import("std");

pub const Timer = struct {
    io: std.Io,
    start: ?std.Io.Timestamp = null,
    duration: ?std.Io.Duration = null,

    pub fn begin(self: *Timer) void {
        self.start = std.Io.Clock.now(.awake, self.io);
    }

    pub fn stop(self: *Timer) void {
        if (self.duration != null) return;
        const s = self.start orelse return; // skip, no quit
        self.duration = s.durationTo(std.Io.Clock.now(.awake, self.io));
    }

    pub fn reset(self: *Timer) void {
        self.start = null;
        self.duration = null;
    }
};
