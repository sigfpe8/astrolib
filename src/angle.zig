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

pub const AngleError = error{
    InvalidAngleFormat,
    DegreeIsTooBig,
    HourIsTooBig,
    MinuteIsTooBig,
    SecondIsTooBig,
};

pub const Angle = union(enum) {
    deg: f64,   // Decimal degrees
    rad: f64,   // Radians
    hrs: f64,   // Decimal hours

    pub fn fromDegrees(degrees: f64) Angle {
        return Angle{ .deg = degrees };
    }

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

    pub fn fromHMS(hms: HMS) Angle {
        var hours: f64 = @as(f64, @floatFromInt(hms.hour)) + @as(f64, @floatFromInt(hms.min)) * min_to_hrs + hms.sec * sec_to_hrs;
        if (hms.sign == '-') {
            hours = -hours;
        }
        return Angle{ .hrs = hours };
    }

    pub inline fn toDegrees(self: Angle) f64 {
        switch (self) {
            .deg => return self.deg,
            .rad => return self.rad * rad_to_deg,
            .hrs => return self.hrs * hrs_to_deg,
        }
    }

    pub inline fn toRadians(self: Angle) f64 {
        switch (self) {
            .deg => return self.deg * deg_to_rad,
            .rad => return self.rad,
            .hrs => return self.hrs * hrs_to_rad,
        }
    }
    
    pub inline fn toHours(self: Angle) f64 {
        switch (self) {
            .deg => return self.deg * deg_to_hrs,
            .rad => return self.rad * rad_to_hrs,
            .hrs => return self.hrs,
        }
    }

    pub inline fn asDegrees(self: Angle) Angle {
        switch (self) {
            .deg => return self,
            .rad => return Angle.fromDegrees(self.rad * rad_to_deg),
            .hrs => return Angle.fromDegrees(self.hrs * hrs_to_deg),
        }
    }

    pub inline fn asRadians(self: Angle) Angle {
        switch (self) {
            .deg => return Angle.fromRadians(self.deg * deg_to_rad),
            .rad => return self,
            .hrs => return Angle.fromRadians(self.hrs * hrs_to_rad),
        }
    }
    
    pub inline fn asHours(self: Angle) Angle {
        switch (self) {
            .deg => return Angle.fromHours(self.deg * deg_to_hrs),
            .rad => return Angle.fromHours(self.rad * rad_to_hrs),
            .hrs => return self,
        }
    }

    pub fn sin(self: Angle) f64 {
        return std.math.sin(self.toRadians());
    }

    pub fn asin(ang: f64) Angle {
        return Angle.fromRadians(std.math.asin(ang));
    }

    pub fn cos(self: Angle) f64 {
        return std.math.cos(self.toRadians());
    }

    pub fn acos(ang: f64) Angle {
        return Angle.fromRadians(std.math.acos(ang));
    }

    pub fn tan(self: Angle) f64 {
        return std.math.tan(self.toRadians());
    }

    pub fn atan(ang: f64) Angle {
        return Angle.fromRadians(std.math.atan(ang));
    }

    pub fn atan2(y: f64, x: f64) Angle {
        return Angle.fromRadians(std.math.atan2(y, x)).reduce360();
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
        return try self.toHMS().toString(allocator);
    }

    pub fn toDMSString(self: Angle, allocator: Allocator) ![]const u8 {
        return try self.toDMS().toString(allocator);
    }
};

// The following types (HMS and DMS) represent angles for human readability, not
// for computation. They are useful for displaying angles in a more traditional format.
// We leave the seconds as a float so that we might display its decimal part in the
// future. For now we just round it up to an integer.
pub const HMS = struct {
    sign:  u8,  // '+' or '-'
    hour: u32,  // nʰ  (1 hour = 15 degrees)
    min:  u32,  // nᵐ
    sec:  f64,  // nˢ

    pub fn toString(self: HMS, allocator: Allocator) ![]const u8 {
        // Round up seconds if necessary
        var hi: u32 = self.hour;
        var mi: u32 =  self.min;
        var si: u32 = @intFromFloat(@round(self.sec));
        if (si >= 60) {
            si = 0;
            mi += 1;
            if (mi >= 60) {
                mi = 0;
                hi += 1;
            }
        }
        return try std.fmt.allocPrint(allocator,
                "{s}{d:0>2}ʰ{d:0>2}ᵐ{d:0>2}ˢ",
                .{if (self.sign == '-') "-" else "",
                        hi, mi, si});
    }

    // Gets HMS from a string
    //    HHhMMmSSs  or
    //    HHʰMMᵐSSˢ  
    //  0 <= HH < 24, 0 <= MM < 60, 0 <= SS < 60
    pub fn fromString(str: []const u8) !HMS {
        var i: usize = 0;
        var sign: u8 = '+';

        // Parse optional sign
        if (str[i] == '+') {
            i += 1;
        } else if (str[i] == '-') {
            sign = '-';
            i += 1;
        }

        var hour: u32 = undefined;
        var min:  u32 = undefined;
        var len: usize = undefined;
        var chr: u21 = undefined;

        // Parse Hour (HHh)
        len, hour, chr = try parseVal(str[i..]);
        i += len;
        if (hour >= 24) {
            return AngleError.HourIsTooBig;
        }
        if (chr != 'h' and chr != 'ʰ') {
            return AngleError.InvalidAngleFormat;
        }

        // Parse Minute (MMm)
        len, min, chr = try parseVal(str[i..]);
        i += len;
        if (min >= 60) {
            return AngleError.MinuteIsTooBig;
        }
        if (chr != 'm' and chr != 'ᵐ') {
            return AngleError.InvalidAngleFormat;
        }

        // Parse Second (SS[.DDD...]s)
        const b = i; // Remember where it begins
        var tmp: usize = undefined;

        len, tmp, chr = try parseVal(str[i..]);
        i += len;
        if (tmp >= 60) {
            return AngleError.SecondIsTooBig;
        }
        var sec: f64 = @floatFromInt(tmp);
        if (chr == '.') {
           len, tmp, chr = try parseVal(str[i..]);
           i += len - (std.unicode.utf8CodepointSequenceLength(chr) catch 1); 
           sec = try std.fmt.parseFloat(f64, str[b..i]);
        }
        if (chr != 's' and chr != 'ˢ') {
            return AngleError.InvalidAngleFormat;
        }

        return .{
            .sign = sign,
            .hour = hour,
            .min = min,
            .sec = sec,
        };
    } 
};

pub const DMS = struct {
    sign: u8,   // '+' or '-'
    deg: u32,   // °  Degrees
    min: u32,   // '  Arc minutes
    sec: f64,   // "  Arc seconds

    pub fn toString(self: DMS, allocator: Allocator) ![]const u8 {
        // Round up seconds if necessary
        var di: u32 = self.deg;
        var mi: u32 =  self.min;
        var si: u32 = @intFromFloat(@round(self.sec));
        if (si >= 60) {
            si = 0;
            mi += 1;
            if (mi >= 60) {
                mi = 0;
                di += 1;
            }
        }
    
        return try std.fmt.allocPrint(allocator,
                "{s}{d}°{d:0>2}′{d:0>2}″",
                .{if (self.sign == '-') "-" else "",
                        di, mi, si});
    }

    // Gets DMS from a string
    //    DD°MM'SS"  or
    //    DD°MM′SS″
    //  0 <= DD < 360, 0 <= MM < 60, 0 <= SS < 60
    pub fn fromString(str: []const u8) !DMS {
        var i: usize = 0;
        var sign: u8 = '+';

        // Parse optional sign
        if (str[i] == '+') {
            i += 1;
        } else if (str[i] == '-') {
            sign = '-';
            i += 1;
        }

        var deg: u32 = undefined;
        var min: u32 = undefined;
        var len: usize = undefined;
        var chr: u21 = undefined;

        // Parse Degree (DD°)
        len, deg, chr = try parseVal(str[i..]);
        i += len;
        if (deg >= 360) {
            return AngleError.DegreeIsTooBig;
        }
        if (chr != '°') {
            return AngleError.InvalidAngleFormat;
        }

        // Parse Minute (MM')
        len, min, chr = try parseVal(str[i..]);
        i += len;
        if (min >= 60) {
            return AngleError.MinuteIsTooBig;
        }
        if (chr != '\'' and chr != '′') {
            return AngleError.InvalidAngleFormat;
        }

        // Parse Second (SS[.DDD...]")
        const b = i; // Remember where it begins
        var tmp: usize = undefined;

        len, tmp, chr = try parseVal(str[i..]);
        i += len;
        if (tmp >= 60) {
            return AngleError.SecondIsTooBig;
        }
        var sec: f64 = @floatFromInt(tmp);
        if (chr == '.') {
           len, tmp, chr = try parseVal(str[i..]);
           i += len - (std.unicode.utf8CodepointSequenceLength(chr) catch 1); 
           sec = try std.fmt.parseFloat(f64, str[b..i]);
        }
        if (chr != '"' and chr != '″') {
            return AngleError.InvalidAngleFormat;
        }

        return .{
            .sign = sign,
            .deg = deg,
            .min = min,
            .sec = sec,
        };
    } 
};

/// Helper function to HMS/DMS.toString()
/// Parses an unsigned integer and the character that follows it.
pub fn parseVal(str: []const u8) !struct {
        usize,   // The length of the parsed part (including the following char)
        u32,     // The parsed value
        u21      // The Unicode code point of the following char
    } {
    const end = str.len;
    var len: usize = 0;
    
    while (len < end) : (len += 1) {
        if (!std.ascii.isDigit(str[len])) {
            break;
        }
    }
    if (len == 0) {    // Must have at least 1 digit
        return AngleError.InvalidAngleFormat;
    }
    const val = try std.fmt.parseUnsigned(u32, str[0..len], 10);

    var chr: u21 = 0;
    var n: usize = 0;
    if (len < end) {
        n = try std.unicode.utf8ByteSequenceLength(str[len]);
        if (len + n > end) {
            return AngleError.InvalidAngleFormat;
        }
        const utf8 = str[len..len+n];
        chr = switch (n) {
            1 => str[len],
            2 => try std.unicode.utf8Decode2(utf8[0..2].*),
            3 => try std.unicode.utf8Decode3(utf8[0..3].*),
            4 => try std.unicode.utf8Decode4(utf8[0..4].*),
            else => 0,
        };
    } else {
        return AngleError.InvalidAngleFormat;
    }

    return .{ len+n, val, chr };
}