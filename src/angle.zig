// Various forms of dealing with angles in astronomy.
const std = @import("std");

pub const Allocator = std.mem.Allocator;

const pi:     f64 = std.math.pi;
const two_pi: f64 = pi * 2.0;

// Conversion factors
pub const deg_to_rad: f64 = pi / 180.0;     // 1 degree = π/180 radians
pub const deg_to_hrs: f64 = 1.0 / 15.0;     // 1 degree = 1/15 hours
pub const deg_to_min: f64 = 60.0;           // 1 degree = 60 minutes
pub const deg_to_sec: f64 = 3600.0;         // 1 degree = 3600 seconds

pub const rad_to_deg: f64 = 180.0 / pi;     // 1 radian = 180/π degrees
pub const rad_to_hrs: f64 = 12.0 / pi;      // 1 radian = 12/π hours

pub const hrs_to_deg: f64 = 15.0;           // 1 hour = 15 degrees
pub const hrs_to_rad: f64 = pi / 12.0;      // 1 hour = π/12 radians
pub const hrs_to_min: f64 = 60.0;           // 1 hour = 60 minutes
pub const hrs_to_sec: f64 = 3600.0;         // 1 hour = 3600 seconds

pub const min_to_sec: f64 = 60.0;           // 1 minute = 60 seconds
pub const min_to_hrs: f64 = 1.0 / 60.0;     // 1 minute = 1/60 hours
pub const min_to_deg: f64 = 1.0 / 60.0;     // 1 arcminute = 1/60 degrees

pub const sec_to_hrs: f64 = 1.0 / 3600.0;   // 1 second = 1/3600 hours
pub const sec_to_min: f64 = 1.0 / 60.0;     // 1 second = 1/60 minutes
pub const sec_to_deg: f64 = 1.0 / 3600.0;   // 1 arcsecond = 1/3600 degrees

pub const Angle = union(enum) {
    deg: f64,   // Decimal degrees
    rad: f64,   // Radians
    hrs: f64,   // Decimal hours

    pub fn fromDegrees(degrees: f64) Angle {
        return Angle{ .deg = degrees };
    }

    // pub fn fromDMS(deg: i64, min: i64, sec: f64) Angle {
    //     return Angle{ .deg = @as(f64, deg) + @as(f64, min) * min_to_deg + sec * sec_to_deg };
    // }

    pub fn fromDMS(dms: DMS) Angle {
        var degrees: f64 = @as(f64, @floatFromInt(dms.deg)) + @as(f64, @floatFromInt(dms.min)) * min_to_deg + dms.sec * sec_to_deg;
        if (dms.sign == '-') {
            degrees = -degrees;
        }
        return Angle{ .deg = degrees };
    }

    pub fn fromRadians(radians: f64) Angle {
        return Angle{ .rad = radians };
    }

    pub fn fromHours(hours: f64) Angle {
        return Angle{ .hrs = hours };
    }

    // pub fn fromHMS(hour: i64, min: i64, sec: f64) Angle {
    //     return Angle{ .hrs = @as(f64, hour) + @as(f64, min) * min_to_hrs + sec * sec_to_hrs };
    // }
    pub fn fromHMS(hms: HMS) Angle {
        var hours: f64 = @as(f64, @floatFromInt(hms.hour)) + @as(f64, @floatFromInt(hms.min)) * min_to_hrs + hms.sec * sec_to_hrs;
        if (hms.sign == '-') {
            hours = -hours;
        }
        return Angle{ .hrs = hours };
    }

    pub fn toDegrees(self: Angle) Angle {
        switch (self) {
            .deg => return self,
            .rad => return Angle.fromDegrees(self.rad * rad_to_deg),
            .hrs => return Angle.fromDegrees(self.hrs * hrs_to_deg),
        }
    }

    pub inline fn toRadians(self: Angle) Angle {
        switch (self) {
            .deg => return Angle.fromRadians(self.deg * deg_to_rad),
            .rad => return self,
            .hrs => return Angle.fromRadians(self.hrs * hrs_to_rad),
        }
    }
    
    pub fn toHours(self: Angle) Angle {
        switch (self) {
            .deg => return Angle.fromHours(self.deg * deg_to_hrs),
            .rad => return Angle.fromHours(self.rad * rad_to_hrs),
            .hrs => return self,
        }
    }

    pub fn sin(self: Angle) f64 {
        return std.math.sin(self.toRadians().rad);
    }

    pub fn asin(ang: f64) Angle {
        return Angle.fromRadians(std.math.asin(ang));
    }

    pub fn cos(self: Angle) f64 {
        return std.math.cos(self.toRadians().rad);
    }

    pub fn acos(ang: f64) Angle {
        return Angle.fromRadians(std.math.acos(ang));
    }

    pub fn tan(self: Angle) f64 {
        return std.math.tan(self.toRadians().rad);
    }

    pub fn atan(ang: f64) Angle {
        return Angle.fromRadians(std.math.atan(ang));
    }

    pub fn atan2(y: f64, x: f64) Angle {
        return Angle.fromRadians(std.math.atan2(y, x));
    }

    pub fn toHMS(self: Angle) HMS {
        var hours: f64 = switch(self) {
            .deg => self.deg * deg_to_hrs,
            .rad => self.rad * rad_to_hrs,
            .hrs => self.hrs,
        };
        var sign: u8 = '+';

        if (hours < 0.0) {
            sign = '-';
            hours = -hours;
        }

        const hour = @trunc(hours);
        const min = @floor((hours - hour) * hrs_to_min);
        const sec = ((hours - hour) * hrs_to_min - min) * min_to_sec;

        return HMS{ .sign = sign,
                    .hour= @as(u32,@intFromFloat(hour)),
                    .min = @as(u32,@intFromFloat(min)),
                    .sec = sec };
    }

    pub fn toDMS(self: Angle) DMS {
        var degrees: f64 = switch(self) {
            .deg => self.deg,
            .rad => self.rad * rad_to_deg,
            .hrs => self.hrs * hrs_to_deg,
        };
        var sign: u8 = '+';

        if (degrees < 0.0) {
            sign = '-';
            degrees = -degrees;
        }

        const deg = @trunc(degrees);
        const min = @floor((degrees - deg) * deg_to_min);
        const sec = ((degrees - deg) * deg_to_min - min) * min_to_sec;

        return DMS{ .sign = sign,
                    .deg = @as(u32,@intFromFloat(deg)),
                    .min = @as(u32,@intFromFloat(min)),
                    .sec = sec };
    }

    /// Reduce angle to the range [0, 360) degrees, [0, 2π) radians, or [0, 24) hours.
    pub fn reduce360(self: Angle) Angle {
        return switch (self) {
            .deg => Angle.fromDegrees(@mod(self.deg, 360.0)),
            .rad => Angle.fromRadians(@mod(self.rad, two_pi)),
            .hrs => Angle.fromHours(@mod(self.hrs, 24.0)),
        };
    }

    /// Reduce angle to the range [-180, 180) degrees, [-π, π) radians, or [-12, 12) hours.
    pub fn reduce180(self: Angle) Angle {
        return switch (self) {
            .deg => Angle.fromDegrees(@mod(self.deg + 180.0, 360.0) - 180.0),
            .rad => Angle.fromRadians(@mod(self.rad + pi, two_pi) - pi),
            .hrs => Angle.fromHours(@mod(self.hrs + 12.0, 24.0) - 12.0),
        };
    }

    pub fn toString(self: Angle, allocator: Allocator) ![]const u8 {
        const str = switch (self) {
            .deg => try std.fmt.allocPrint(allocator, "{d:.4}°", .{self.deg}),
            .rad => try std.fmt.allocPrint(allocator, "{d:.4} rad", .{self.rad}),
            .hrs => try std.fmt.allocPrint(allocator, "{d:.4}ʰ", .{self.hrs}),
        };
        return str;
    }

    pub fn toHMSString(self: Angle, allocator: Allocator) ![]const u8 {
        const hms = self.toHMS();
        return try std.fmt.allocPrint(allocator,
        "{s}{d:0>2}ʰ{d:0>2}ᵐ{d:0>2.0}ˢ",
        .{if (hms.sign == '-') "-" else "", hms.hour, hms.min, hms.sec});
    }

    pub fn toDMSString(self: Angle, allocator: Allocator) ![]const u8 {
        const dms = self.toDMS();
        return try std.fmt.allocPrint(allocator,
        "{s}{d}°{d:0>2}'{d:0>2.0}\"",
        .{if (dms.sign == '-') "-" else "", dms.deg, dms.min, dms.sec});
    }
};

// The following types (HMS and DMS) represent angles for human readability, not
// for computation. They are useful for displaying angles in a more traditional format.
pub const HMS = struct {
    sign:  u8,  // '+' or '-'
    hour: u32,  // nʰ  (1 hour = 15 degrees)
    min:  u32,  // nᵐ
    sec:  f64,  // nˢ
};

pub const DMS = struct {
    sign: u8,   // '+' or '-'
    deg: u32,   // °  Degrees
    min: u32,   // '  Arc minutes
    sec: f64,   // "  Arc seconds
};
