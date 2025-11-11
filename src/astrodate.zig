// Many of the functions in this file are based on the book
// [Meeus, 1998]    Meeus, Jean. (1998).    "Astronomical Algorithms" 2nd ed. Willmann-Bell
// [Lawrence, 2018] Lawrence, J.L. (2018).  "Celestial Calculations". The MIT Press
// [Collier, 2023]  Collier, Peter. (2023). "Movement of the Spheres". Incomprehensible Books

const std = @import("std");
const ang = @import("angle.zig");
const crd = @import("coords.zig");
const Angle = ang.Angle;
const GeoCoord = crd.GeoCoord;
const Longitude = crd.Longitude;

pub const Allocator = std.mem.Allocator;

pub const Year = i16; // Year can be negative, e.g. -1 = 2 BC, 0 = 1 BC, 1 = 1 AD...
pub const Month = u8; // Month is 1-based, i.e. 1 = January, 2 = February, ..., 12 = December
pub const Day = u8;   // Day is 1-based, i.e. 1 = 1st day of the month, ..., 31 = last day of the month

pub const UnixTime = i64; // Unix time is seconds since epoch (Jan 1, 1970); can be negative for dates before epoch

// Brazil main timezone
pub const tzBRT = TimeZone.init(false, -3, 0); // Brazil Standard Time (UTC-3)
// US timezones
pub const tzEST = TimeZone.init(false, -5, 0); // Eastern Standard Time (UTC-5)
pub const tzEDT = TimeZone.init(true, -5, 0);  // Eastern Daylight Time (UTC-4)
pub const tzCST = TimeZone.init(false, -6, 0); // Central Standard Time (UTC-6)
pub const tzCDT = TimeZone.init(true, -6, 0);  // Central Daylight Time (UTC-5)
pub const tzMST = TimeZone.init(false, -7, 0); // Mountain Standard Time (UTC-7)
pub const tzMDT = TimeZone.init(true, -7, 0);  // Mountain Daylight Time (UTC-6)
pub const tzPST = TimeZone.init(false, -8, 0); // Pacific Standard Time (UTC-8)
pub const tzPDT = TimeZone.init(true, -8, 0);  // Pacific Daylight Time (UTC-7)

// Conversion factors
const hrs_to_min = ang.hrs_to_min;
const min_to_sec = ang.min_to_sec;

pub const TimeZone = packed struct(u8) {
    dst: bool = false, // Daylight Saving Time (DST) flag
    offset: i7 = 0,    // Timezone offset in 15-min units (default is UTC)

    pub fn init(dst: bool, hours: i7, minutes: i7) TimeZone {
        // Ensure hours and minutes are within valid ranges
        if (hours < -12 or hours > 14) {
            @panic("Invalid timezone hours");
        }
        if (minutes < -45 or minutes > 45 or @rem(minutes, 15) != 0) {
            @panic("Invalid timezone minutes");
        }
        if (hours < 0 and minutes > 0 or hours > 0 and minutes < 0) {
            @panic("Invalid timezone combination of hours and minutes");
        }
        const offset = @as(i7, hours * 4 + @divTrunc(minutes, 15));
        return TimeZone{ .dst = dst, .offset = offset };
    }

    pub fn getOffsetHours(self: TimeZone) f64 {
        var off: i7 = self.offset;
        if (self.dst) off += 4;
        return @as(f64, @floatFromInt(off)) * 0.25;
    }

    pub fn toString(self: TimeZone, allocator: Allocator) ![]const u8 {
        const sign = if (self.offset < 0) "-" else "+";
        const abs_offset = @abs(self.offset);
        const hours = abs_offset / 4;
        const minutes = (abs_offset % 4) * 15;
        return try std.fmt.allocPrint(allocator, "{s}{d:0>2}:{d:0>2}{s}", .{
            sign,
            @as(u32, @intCast(hours)),
            @as(u32, @intCast(minutes)),
            if (self.dst) " DST" else "",
        });
    }
};

pub const AstroDate = struct {
    const Self = @This();

    // Date
    year:  Year,    // -1 = 2 BC, 0 = 1 BC, 1 = 1 AD...
    month: Month,   // 1 = Jan, 2 = Feb, ..., 12 = Dec
    day:   Day,     // Day number (1...31)

    // Time of day, default to midnight UTC (00:00:00)
    hour:  u8 = 0,  // Hour number (0...23)
    min:   u8 = 0,  // Minute number (0...59)
    sec:   u8 = 0,  // Second number (0...59)
    tz:    TimeZone = .{},  // Encoded timezone, defaults to UTC

    pub fn fromDateAndHours(year: Year, month: Month, day: Day, hours: f64, tz: TimeZone) AstroDate {
        const hf = hours;

        std.debug.assert(hours >= 0 and hours < 24);

        const hour = @trunc(hf);
        const min = @trunc((hf - hour) * hrs_to_min);
        const sec = @round(((hf - hour) * hrs_to_min - min) * min_to_sec);
        var hi: u8 = @intFromFloat(hour);
        var mi: u8 =  @intFromFloat(min);
        var si: u8 = @intFromFloat(sec);
        if (si >= 60) {
            si = 0;
            mi += 1;
            if (mi >= 60) {
                mi = 0;
                hi += 1;
            }
        }

        return AstroDate{
            .year = year,
            .month = month,
            .day = day,
            .hour = hi,
            .min = mi,
            .sec = si,
            .tz = tz
        };
    }

    // The day following
    //   1582 October  4 Thursday (Julian Calendar) was 
    //   1582 October 15 Friday   (Gregorian Calendar)

    // Return true if the given date is in the Julian Calendar
    // (i.e. before 1582 October 5)
    pub fn inJulianCalendar(self: Self) bool {
        return (self.year < 1582 or
               (self.year == 1582 and ((self.month < 10) or
                                       (self.month == 10 and self.day < 5))));
    }

    // Return true if the given date is in the Gregorian Calendar
    // (i.e. after 1582 October 14)
    pub fn inGregorianCalendar(self: Self) bool {
        return (self.year > 1582 or
               (self.year == 1582 and ((self.month > 10) or
                                       (self.month == 10 and self.day > 14))));
    }

    /// Create AstroDate from Julian Day Number
    pub fn fromJD(jd: f64) AstroDate {
        const z: f64 = @trunc(jd + 0.5);
        var f: f64 = jd + 0.5 - z;  // Fractional part of JD
        const a: f64 = if (z < 2299161) z else blk: {
                    const alpha: f64 = @trunc((z - 1867216.25) / 36524.25);
                    const beta: f64 = z + 1 + alpha - @trunc(alpha / 4);
                    break :blk beta; 
                };
        const b = a + 1524;
        const c = @trunc((b - 122.1) / 365.25);
        const d = @trunc(365.25 * c);
        const e = @trunc((b - d) / 30.6001);
        const day: Day = @intFromFloat(b - d - @trunc(30.6001 * e));
        const month: Month = @intFromFloat(if (e < 14) e - 1 else e - 13);
        const year: Year = @intFromFloat(if (month > 2) c - 4716 else c - 4715);

        f = f * 24;
        const hour: u8 = @truncate(@as(u64,@intFromFloat(@trunc(f))));
        f = (f - @as(f64, @floatFromInt(hour))) * 60;
        const min: u8 = @truncate(@as(u64,@intFromFloat(@trunc(f))));
        f = (f - @as(f64, @floatFromInt(min))) * 60;
        const sec: u8 = @truncate(@as(u64,@intFromFloat(@trunc(f))));

        return AstroDate{ .year = year, .month = month, .day = day,
                        .hour = hour, .min = min, .sec = sec, .tz = .{} };
    }


    // Return the Julian Day Number (JD) of the given date
    // JD 0.0 = 4713 B.C. (-4712) January 1 at noon
    // [1] p 59-61
    pub fn toJD(self: Self) f64 {
        var yr: f64 = @floatFromInt(self.year);
        var mo: f64 = @floatFromInt(self.month);
        const dy: f64 = @as(f64,@floatFromInt(self.day))
            + @as(f64,@floatFromInt(self.hour)) / 24
            + @as(f64,@floatFromInt(self.min)) / 1440
            + @as(f64,@floatFromInt(self.sec)) / 86400;

        if (self.month <= 2) {
            yr -= 1;
            mo += 12;
        }

        var B: f64 = 0;

        // Gregorian Calendar?
        if (self.inGregorianCalendar()) {
            const A: f64 = @trunc(yr / 100);  // Century
            B = 2 - A + @trunc(A / 4);
        }

        return @trunc(365.25 * (yr + 4716))
            + @trunc(30.6001 * (mo + 1))
            + dy
            + B
            - 1524.5;
    }

    // 0 = Sunday, 1 = Monday, 2 = Tuesday, 3 = Wednesday, 4 = Thursday, 5 = Friday, 6 = Saturday
    pub fn dayOfWeek(self: Self) u32 {
        const jd: u32 = @intFromFloat(self.toJD() + 1.5);
        return @rem(jd,7);
    }

    pub fn daysIntoYear(self: Self) u32 {
        // There's the ugly formula in Lawrence [2018] p 44, and there's
        // the table based approach used by Unix. Here we just sum the days in the months.
        // Later I'll try the Unix approach.
        var days: u32 = 0;
        var month: Month = 1;
        while (month < self.month) {
            days += daysInMonth(self.year, month);
            month += 1;
        }
        days += @as(u32,@intCast(self.day));
        return days;
    }

    // Return "YYYY-MM-DD" for YYYY > 0 (i.e. AD)
    //        "YYYY-MM-DD BC" for YYYY <= 0
    pub fn toDateString(self: Self, allocator: Allocator) ![]const u8 {
        if (self.year > 0) {
            return try std.fmt.allocPrint(allocator, "{d:0>4}-{d:0>2}-{d:0>2}", .{
                @as(u32, @intCast(self.year)),
                @as(u32, self.month),
                @as(u32, self.day),
            });
        }

        return try std.fmt.allocPrint(allocator, "{d:0>4}-{d:0>2}-{d:0>2} BC", .{
            @as(u32, @intCast(-self.year + 1)),
            @as(u32, self.month),
            @as(u32, self.day),
        });
    }

    // Return "HH:MM:SS"
    pub fn toTimeString(self: Self, allocator: Allocator) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "{d:0>2}:{d:0>2}:{d:0>2}", .{
            @as(u32, self.hour),
            @as(u32, self.min),
            @as(u32, self.sec)
        });
    }

    // Return "YYYY-MM-DD HH:MM:SS" for YYYY > 0 (i.e. AD)
    //        "YYYY-MM-DD BC HH:MM:SS" for YYYY <= 0
    pub fn toDateTimeString(self: Self, allocator: Allocator) ![]const u8 {
        const date_str = try self.toDateString(allocator);
        defer allocator.free(date_str);
        const time_str = try self.toTimeString(allocator);
        defer allocator.free(time_str);
        return try std.fmt.allocPrint(allocator, "{s} {s}", .{date_str, time_str});
    }

    pub fn toString(self: Self, allocator: Allocator) ![]const u8 {
        const date_str = try self.toDateString(allocator);
        defer allocator.free(date_str);
        const time_str = try self.toTimeString(allocator);
        defer allocator.free(time_str);
        const tz_str = try self.tz.toString(allocator);
        defer allocator.free(tz_str);
        // Format: "YYYY-MM-DD HH:MM:SS TZ"
        return try std.fmt.allocPrint(allocator, "{s} {s} ({s})", .{
            date_str,
            time_str,
            tz_str
        });
    }

    /// Return same date at noon (12:00:00)
    pub fn noon(self: Self) Self {
        // Return a new AstroDate with the same date but time set to noon (12:00:00)
        return .{ .year = self.year, .month = self.month, .day = self.day,
                  .hour = 12, .min = 0, .sec = 0, .tz = self.tz };
    }

    /// Return same date at midnight (00:00:00)
    pub fn midnight(self: Self) Self {
        // Return a new AstroDate with the same date but time set to midnight (00:00:00)
        return .{ .year = self.year, .month = self.month, .day = self.day,
                  .hour = 0, .min = 0, .sec = 0, .tz = self.tz };
    }

    /// Create AstroDate from Unix time
    pub fn fromUnixTime(ts: UnixTime) AstroDate {
        if (ts >= 0) {  // >= 0 means after epoch (Jan 1, 1970)
            var ndays = @divTrunc(ts, std.time.s_per_day)+1;   // Number of days since epoch, including this day
            const secs_today = @rem(ts, std.time.s_per_day);   // Seconds since midnight

            var tmp = secs_today;
            const hour: u8 = @truncate(@as(u64,@bitCast(@divTrunc(tmp, std.time.s_per_hour))));
            tmp = @rem(tmp, std.time.s_per_hour);
            const min:  u8 = @truncate(@as(u64,@bitCast(@divTrunc(tmp, std.time.s_per_min))));
            const sec:  u8 = @truncate(@as(u64,@bitCast(@rem(tmp, std.time.s_per_min))));

            var year: Year = 1970;
            var month: Month = 1;

            var days_in_year: u32 = if (isLeapYear(year)) 366 else 365;
            while (ndays > days_in_year) {
                ndays -= days_in_year;
                year += 1;
                days_in_year = if (isLeapYear(year)) 366 else 365;
            }

            var days_in_month = daysInMonth(year, month);
            while (ndays > days_in_month) {
                ndays -= days_in_month;
                month += 1;
                days_in_month = daysInMonth(year, month);
            }

            const day: Day = @truncate(@as(u64,@bitCast(ndays)));

            return AstroDate{ .year = year, .month = month, .day = day,
                            .hour = hour, .min = min, .sec = sec };
        } else {    // Before epoch (Jan 1, 1970)
            const tsp = @as(UnixTime, -ts)-1; // Positive timestamp for calculations
            var ndays = @divTrunc(tsp, std.time.s_per_day);   // Number of days since epoch, including this day
            const secs_today = @rem(tsp, std.time.s_per_day);   // Seconds since midnight

            var tmp = std.time.s_per_day - 1 - secs_today;
            const hour: u8 = @truncate(@as(u64,@bitCast(@divTrunc(tmp, std.time.s_per_hour))));
            tmp = @rem(tmp, std.time.s_per_hour);
            const min:  u8 = @truncate(@as(u64,@bitCast(@divTrunc(tmp, std.time.s_per_min))));
            const sec:  u8 = @truncate(@as(u64,@bitCast(@rem(tmp, std.time.s_per_min))));

            var year: Year = 1969;
            var month: Month = 12;

            var days_in_year: u32 = if (isLeapYear(year)) 366 else 365;
            while (ndays >= days_in_year) {
                ndays -= days_in_year;
                year -= 1;
                days_in_year = if (isLeapYear(year)) 366 else 365;
            }

            var days_in_month = daysInMonth(year, month);
            while (ndays >= days_in_month) {
                ndays -= days_in_month;
                month -= 1;
                days_in_month = daysInMonth(year, month);
            }

            const day: Day = @truncate(@as(u64,@bitCast(days_in_month - ndays)));

            return AstroDate{ .year = year, .month = month, .day = day,
                            .hour = hour, .min = min, .sec = sec };
        }
    }

    /// Convert AstroDate to Unix time (seconds since epoch)
    pub fn toUnixTime(self: AstroDate) UnixTime {
        var ndays: i64 = 0;
        var year: Year = undefined;

        if (self.year >= 1970) {
            year = 1970;
            // Count days from 1970 to the given year
            while (year < self.year) {
                ndays += if (isLeapYear(year)) 366 else 365;
                year += 1;
            }

            // Count days in the months of the given year before current month
            var month: Month = 1;
            while (month < self.month) {
                ndays += daysInMonth(self.year, month);
                month += 1;
            }

            // Add the days in the current month
            ndays += @as(i64, @intCast(self.day - 1));

            const hour = @as(i64, @intCast(self.hour));
            const min = @as(i64, @intCast(self.min));
            const sec = @as(i64, @intCast(self.sec));

            // Convert to seconds
            return @as(UnixTime, ndays * std.time.s_per_day + 
                    hour * std.time.s_per_hour +
                    min * std.time.s_per_min +
                    sec);
        } else {
            // For years before 1970, we need to count backwards
            year = 1969;
            while (year > self.year) {
                ndays -= if (isLeapYear(year)) 366 else 365;
                year -= 1;
            }

            // Count days in the months of the given year after current month
            var month: Month = 12;
            while (month > self.month) {
                ndays -= daysInMonth(year, month);
                month -= 1;
            }

            // Add the days in the rest of the current month
            ndays -= daysInMonth(year, month) - self.day;

            const hour = 23 - @as(i64, self.hour);
            const min  = 59 - @as(i64, self.min);
            const sec  = 60 - @as(i64, self.sec);

            // Convert to seconds
            return @as(UnixTime, ndays * std.time.s_per_day -
                    hour * std.time.s_per_hour -
                    min * std.time.s_per_min -
                    sec);
        }
    }

    pub fn adPreviousDay(self: AstroDate) AstroDate {
        var y = self.year;
        var m = self.month;
        var d = self.day;

        d -= 1;
        if (d == 0) {
            m -= 1;
            if (m == 0) {
                m = 12;
                y -= 1;
            }
            d = daysInMonth(y, m);
        }

        return AstroDate{.year=y, .month=m, .day=d,
                         .hour=self.hour, .min=self.min, .sec=self.sec, .tz=self.tz};
    }

    pub fn adNextDay(self: AstroDate) AstroDate {
        var y = self.year;
        var m = self.month;
        var d = self.day;

        const dim = daysInMonth(y, m);
        d += 1;
        if (d > dim) {
            m += 1;
            if (m > 12) {
                m = 1;
                y += 1;
            }
        }

        return AstroDate{.year=y, .month=m, .day=d,
                         .hour=self.hour, .min=self.min, .sec=self.sec, .tz=self.tz};
    }
};

// Return true if the given year is a leap year
pub fn isLeapYear(year: Year) bool {
  // Julian Calendar?
  // Note that 1582 itself is not a leap year
  if (year <= 1582) {
    return @rem(year,4) == 0;
  }
  // Gregorian Calendar
  return (@rem(year,4) == 0 and (@rem(year,100) != 0 or @rem(year,400) == 0));
}

// Return the number of days in the given month
const daysPerMonth = [_]u32{
    31, // January
    28, // February
    31, // March
    30, // April
    31, // May
    30, // June
    31, // July
    31, // August
    30, // September
    31, // October
    30, // November
    31, // December
};

pub fn daysInMonth(year: Year, month: Month) u32 {
    if (month == 2) {
        return if (isLeapYear(year)) 29 else 28;
    }
    return daysPerMonth[month - 1]; 
}

pub fn now() AstroDate {
    const ts: UnixTime = std.time.timestamp();
    return AstroDate.fromUnixTime(ts);
}

pub fn dateFromDaysAndYear(days: u32, year: Year) AstroDate {
    var month: Month = 1;
    var day_of_month: u32 = days;
    var dim: u32 = daysInMonth(year, month);
    while (day_of_month > dim) {
        day_of_month -= dim;
        month += 1;
        dim = daysInMonth(year, month);
    }
    return AstroDate{ .year = year, .month = month, .day = @truncate(day_of_month),
                      .hour = 0, .min = 0, .sec = 0 };
}

pub fn nextDay(year: Year, month: Month, day: Day) struct { Year, Month, Day } {
    var d: Day = day + 1;
    var m: Month = month;
    var y: Year = year;
    const dim: u8 = @truncate(daysInMonth(year, month));
    if (d > dim) {
        d = 1;
        m += 1;
        if (m > 12) {
            m = 1;
            y += 1;
        }
    }
    return .{ y, m, d };
}

pub fn previousDay(year: Year, month: Month, day: Day) struct { Year, Month, Day } {
    var d: Day = day - 1;
    var m: Month = month;
    var y: Year = year;
    if (d == 0) {
        m -= 1;
        if (m == 0) {
            m = 12;
            y -= 1;
        }
        d = @truncate(daysInMonth(y, m));
    }
    return .{ y, m, d };
}

// Return the date of Easter Sunday for the given year
// [1] p 67
pub fn easterDate(year: usize) AstroDate {
    // Works only for years after 1582 (Gregorian Calendar)
    const a = @rem(year, 19);
    const b = @divTrunc(year, 100);
    const c = @rem(year, 100);
    const d = @divTrunc(b, 4);
    const e = @rem(b, 4);
    const f = @divTrunc((b + 8), 25);
    const g = @divTrunc((b - f + 1), 3);
    const h = @rem(19 * a + b - d - g + 15, 30);
    const i = @divTrunc(c, 4);
    const k = @rem(c, 4);
    const l = @rem(32 + 2 * e + 2 * i - h - k, 7);
    const m = @divTrunc(a + 11 * h + 22 * l, 451);
    const x = h + l - 7 * m + 114;
    const month: Month = @truncate(@divTrunc(x, 31));
    const day: Day = @truncate(@rem(x, 31) + 1);
    return .{.year = @as(u15,@truncate(year)),
             .month  = month,
             .day    = day};
}

/// Calculate the number of days between two AstroDate instances
pub fn daysBetweenDates(date1: AstroDate, date2: AstroDate) i64 {
    const jd1: i64 = @intFromFloat(date1.noon().toJD());
    const jd2: i64 = @intFromFloat(date2.noon().toJD());
    return jd2 - jd1;
}

/// Convert hours, minutes, seconds to decimal hours
 pub fn hmsToDec(hour: u8, min: u8, sec: u8) f64 {
    return @as(f64, @floatFromInt(hour)) + 
           (@as(f64, @floatFromInt(min)) * 60 + @as(f64, @floatFromInt(sec))) / 3600;

}

/// Convert decimal hours to AstroDate (hours, minutes, seconds)
pub fn decToHMS(dec: f64) AstroDate {
    var h: u8 = @intFromFloat(@trunc(dec));
    const hf: f64 = @floatFromInt(h);
    var m: u8 = @intFromFloat(@trunc((dec - hf) * 60));
    const mf: f64 = @floatFromInt(m);
    var s: u8 = @intFromFloat(@round(((dec - hf) * 60 - mf) * 60));
    if (s >= 60) {
        s = 0;
        m += 1;
    }
    if (m >= 60) {
        m = 0;
        h += 1;
    }
    return AstroDate{ .year = 1, .month = 1, .day = 1, .hour = h, .min = m, .sec = s };
}

/// Convert LCT (Local Civil Time) to UT (Universal Time)
pub fn lctToUT(date: AstroDate) AstroDate {
    // LCT = UT + (Longitude in hours) + DST adjustment
    // Longitude: positive for East, negative for West
    // [Lawrence, 2018] p 46
    var y: Year = date.year;
    var m: Month = date.month;
    var d: Day = date.day;
    const lct_dec = hmsToDec(date.hour, date.min, date.sec);
    var ut_dec = lct_dec - date.tz.getOffsetHours();
    if (date.tz.dst) {
        ut_dec -= 1; // Subtract 1 hour for DST
    }
    if (ut_dec < 0) {
        y, m, d = previousDay(y, m, d);
        ut_dec += 24; // Ensure UT is positive
    } else if (ut_dec >= 24) {
        y, m, d = nextDay(y, m, d);
        ut_dec -= 24; // Wrap around if UT exceeds 24 hours
    }
    const date_ut = AstroDate.fromDateAndHours(y, m, d, ut_dec, .{});
    return date_ut;
}

/// Convert UT (Universal Time) to LCT (Local Civil Time)
pub fn utToLCT(date: AstroDate, tz: TimeZone) AstroDate {
    // [Lawrence, 2018] p 46
    var y: Year = date.year;
    var m: Month = date.month;
    var d: Day = date.day;
    const ut_dec = hmsToDec(date.hour, date.min, date.sec);
    var lct_dec = ut_dec + tz.getOffsetHours(); // Takes care of DST as well
    if (lct_dec < 0) {
        y, m, d = previousDay(y, m, d);
        lct_dec += 24; // Ensure LCT is positive
    } else if (lct_dec >= 24) {
        y, m, d = nextDay(y, m, d);
        lct_dec -= 24; // Wrap around if LCT exceeds 24 hours
    }
    const date_lct = AstroDate.fromDateAndHours(y, m, d, lct_dec, tz);
    return date_lct;
}

/// Convert UT to GST (Greenwich Sidereal Time)
pub fn utToGST(date: AstroDate) AstroDate {
    // [Lawrence, 2018] p 47-48
    const jd = date.midnight().toJD();   // Julian Day Number at midnight UTC
    const day0 = AstroDate{ .year = date.year, .month = 1, .day = 0};
    const jd0 = day0.toJD(); // Julian Day Number at the start of the year
    const days = jd - jd0; // Days since the start of the year
    const t = (jd0 - 2_415_020.0) / 36_525.0; // Julian centuries since J2000.0 
    const r = 6.6460656 + t * (2400.051262 + 0.00002581 * t);
    const b = 24 - r + 24 * (@as(f64,@floatFromInt(date.year)) - 1900);
    const t0 = 0.0657098 * days - b;
    const ut = hmsToDec(date.hour, date.min, date.sec); // Convert UTC time to decimal hours
    var gst = t0 + 1.002737909 * ut; // Greenwich Sidereal Time in decimal hours
    if (gst < 0) {
        gst += 24;
    } else if (gst >= 24) {
        gst -= 24;
    }
    const date_gst = AstroDate.fromDateAndHours(date.year, date.month, date.day, gst, .{});
    return date_gst;
}

/// Convert GST (Greenwich Sidereal Time) to LST (Local Sidereal Time)
pub fn gstToUT(date: AstroDate) AstroDate {
    // [Lawrence, 2018] p 48-49
    const jd = date.midnight().toJD();   // Julian Day Number at midnight GST
    const day0 = AstroDate{ .year = date.year, .month = 1, .day = 0};
    const jd0 = day0.toJD(); // Julian Day Number at the start of the year
    const days = jd - jd0; // Days since the start of the year
    const t = (jd0 - 2_415_020.0) / 36_525.0; // Julian centuries since J2000.0 
    const r = 6.6460656 + t * (2400.051262 + 0.00002581 * t);
    const b = 24 - r + 24 * (@as(f64,@floatFromInt(date.year)) - 1900);
    var t0 = 0.0657098 * days - b;
    if (t0 < 0) {
        t0 += 24;
    } else if (t0 >= 24) {
        t0 -= 24;
    }
    // The above steps are the same as in utToGST
    const gst = hmsToDec(date.hour, date.min, date.sec); // Convert GST time to decimal hours
    var a = gst - t0;
    if (a < 0) {
        a += 24;
    }
    const ut = 0.997270 * a; // Universal Time in decimal hours
    const date_ut = AstroDate.fromDateAndHours(date.year, date.month, date.day, ut, .{});
    return date_ut;
}

/// Convert GST to LST (Local Sidereal Time) given the longitude in degrees
pub fn gstToLST(gst: AstroDate, longitude_deg: f64) AstroDate {
    // Longitude: positive for East, negative for West
    // [Lawrence, 2018] p 49
    const gst_dec = hmsToDec(gst.hour, gst.min, gst.sec);
    var lst_dec = gst_dec + longitude_deg / 15.0; // Convert degrees to hours
    if (lst_dec < 0) {
        lst_dec += 24;
    } else if (lst_dec >= 24) {
        lst_dec -= 24;
    }
    const date_lst = AstroDate.fromDateAndHours(gst.year, gst.month, gst.day, lst_dec, .{});
    return date_lst;
}

/// Convert LST (Local Sidereal Time) to GST given the longitude in degrees
pub fn lstToGST(lst: AstroDate, longitude_deg: f64) AstroDate {
    // Longitude: positive for East, negative for West
    // [Lawrence, 2018] p 50
    const lst_dec = hmsToDec(lst.hour, lst.min, lst.sec);
    var gst_dec = lst_dec - longitude_deg / 15.0; // Convert degrees to hours
    if (gst_dec < 0) {
        gst_dec += 24;
    } else if (gst_dec >= 24) {
        gst_dec -= 24;
    }
    const date_gst = AstroDate.fromDateAndHours(lst.year, lst.month, lst.day, gst_dec, .{});
    return date_gst;
}

/// Convert LCT (Local Civil Time) to LST (Local Sidereal Time)
pub fn lctToLST(lct: AstroDate, lon: Longitude) AstroDate {
    const ut = lctToUT(lct);
    const gst = utToGST(ut);
    return gstToLST(gst, lon.toDegrees().deg);
}

/// Convert LST (Local Sidereal Time) to LCT (Local Civil Time)
pub fn lstToLCT(lst: AstroDate, lon: Longitude, tz: TimeZone) AstroDate {
    const gst = lstToGST(lst, lon.toDegrees().deg);
    const ut = gstToUT(gst);
    return utToLCT(ut, tz);
}