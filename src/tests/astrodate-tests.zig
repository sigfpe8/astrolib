const std = @import("std");
const lib= @import("astrolib");

const ang = lib.ang;
const Angle = ang.Angle;

const ast = lib.ast;
const AstroDate = ast.AstroDate;
const TimeZone = ast.TimeZone;
const UnixTime = ast.UnixTime;
const Year = ast.Year;
const Month = ast.Month;
const Day = ast.Day;
const Allocator = std.mem.Allocator;

const crd = lib.crd;
const GeoCoord = crd.GeoCoord;

const expect = std.testing.expect;
const allocator = std.testing.allocator;
const print = std.debug.print;

test "dayOfWeek" {
    try expect(AstroDate.dayOfWeek(.{.year = 2000, .month = 1,  .day =  1}) == 6);
    try expect(AstroDate.dayOfWeek(.{.year = 1987, .month = 1,  .day = 27}) == 2);
    try expect(AstroDate.dayOfWeek(.{.year = 1987, .month = 6,  .day = 19}) == 5);
    try expect(AstroDate.dayOfWeek(.{.year = 1957, .month = 10, .day =  4}) == 5);
    try expect(AstroDate.dayOfWeek(.{.year = 1954, .month = 6,  .day = 30}) == 3);
    try expect(AstroDate.dayOfWeek(.{.year = 1582, .month = 10, .day = 15}) == 5);
    try expect(AstroDate.dayOfWeek(.{.year = 1582, .month = 10, .day =  4}) == 4);
}

test "isLeapYear" {
    try expect(ast.isLeapYear(0) == true);
    try expect(ast.isLeapYear(4) == true);
    try expect(ast.isLeapYear(10) == false);
    try expect(ast.isLeapYear(1500) == true);
    try expect(ast.isLeapYear(1600) == true);
    try expect(ast.isLeapYear(1700) == false);
    try expect(ast.isLeapYear(1895) == false);
    try expect(ast.isLeapYear(1900) == false);
    try expect(ast.isLeapYear(2000) == true);
    try expect(ast.isLeapYear(2020) == true);
    try expect(ast.isLeapYear(2021) == false);
    try expect(ast.isLeapYear(2024) == true);
}

test "toDateString" {
    const date = AstroDate{.year = 2000, .month = 1, .day = 1, .hours = 12};
    const date_str = try date.toDateString(allocator);
    defer allocator.free(date_str);
    try expect(std.mem.eql(u8, date_str, "2000-01-01"));
}

test "toTimeString" {
    const date = AstroDate.fromDateAndHMS(2000, 1, 1, 12, 30, 30, .{});
    const time_str = try date.toTimeString(allocator);
    defer allocator.free(time_str);
    try expect(std.mem.eql(u8, time_str, "12:30:30"));
}

test "toDateTimeString" {
    const date = AstroDate.fromDateAndHMS(2025, 5, 23, 23, 59, 59, .{});
    const date_time_str = try date.toDateTimeString(allocator);
    defer allocator.free(date_time_str);
    try expect(std.mem.eql(u8, date_time_str, "2025-05-23 23:59:59"));
}

test "easterDate" {
    var date = ast.easterDate(1818);
    try expect(date.year == 1818 and date.month == 3 and date.day == 22);

    date = ast.easterDate(1886);    
    try expect(date.year == 1886 and date.month == 4 and date.day == 25);    

    date = ast.easterDate(1954);
    try expect(date.year == 1954 and date.month == 4 and date.day == 18);
    
    date = ast.easterDate(1961);
    try expect(date.year == 1961 and date.month == 4 and date.day == 2);

    date = ast.easterDate(1991);
    try expect(date.year == 1991 and date.month == 3 and date.day == 31);

    date = ast.easterDate(1992);
    try expect(date.year == 1992 and date.month == 4 and date.day == 19);

    date = ast.easterDate(1993);
    try expect(date.year == 1993 and date.month == 4 and date.day == 11);

    date = ast.easterDate(2000);
    try expect(date.year == 2000 and date.month == 4 and date.day == 23);

    date = ast.easterDate(2025);
    try expect(date.year == 2025 and date.month == 4 and date.day == 20);

    date = ast.easterDate(2026);
    try expect(date.year == 2026 and date.month == 4 and date.day == 5);

    date = ast.easterDate(2038);
    try expect(date.year == 2038 and date.month == 4 and date.day == 25);

    date = ast.easterDate(2285);
    try expect(date.year == 2285 and date.month == 3 and date.day == 22);
}

const TimeTest = struct {
    year: Year,
    month: Month,
    day: Day,
    hour: u32,
    min: u32,
    sec: u32,
    ts: UnixTime,
};

const TimeTests = [_]TimeTest{
    .{ .year =1970, .month =  1, .day =  1, .hour= 0, .min= 0, .sec= 0, .ts=            0 },
    .{ .year =1970, .month =  1, .day =  1, .hour=12, .min=30, .sec=45, .ts=        45045 },
    .{ .year =1970, .month =  1, .day =  1, .hour=23, .min=59, .sec=59, .ts=        86399 },
    .{ .year =1970, .month = 12, .day = 31, .hour=23, .min=59, .sec=59, .ts=     31535999 },
    .{ .year =1971, .month = 12, .day = 31, .hour=23, .min=59, .sec=59, .ts=     63071999 },
    .{ .year =1972, .month =  2, .day = 29, .hour= 0, .min= 0, .sec= 0, .ts=     68169600 },
    .{ .year =1972, .month =  3, .day =  1, .hour= 0, .min= 0, .sec= 0, .ts=     68256000 },
    .{ .year =1980, .month = 12, .day = 31, .hour=23, .min=59, .sec=59, .ts=    347155199 },
    .{ .year =1999, .month = 12, .day = 31, .hour=23, .min=59, .sec=59, .ts=    946684799 },
    .{ .year =2000, .month =  2, .day = 29, .hour=12, .min= 0, .sec= 0, .ts=    951825600 },
    .{ .year =2022, .month = 12, .day = 31, .hour=23, .min=59, .sec=59, .ts=   1672531199 },
    .{ .year =2038, .month = 12, .day = 31, .hour=23, .min=59, .sec=59, .ts=   2177452799 },
    .{ .year =2138, .month = 12, .day = 31, .hour=23, .min=59, .sec=59, .ts=   5333126399 },

    .{ .year = 1969, .month = 12, .day = 31, .hour=23, .min=59, .sec=59, .ts=           -1 },
    .{ .year = 1969, .month = 12, .day = 31, .hour= 0, .min= 0, .sec= 0, .ts=       -86400 },
    .{ .year = 1969, .month = 12, .day =  1, .hour= 0, .min= 0, .sec= 0, .ts=     -2678400 },
    .{ .year = 1969, .month = 11, .day = 30, .hour=12, .min= 0, .sec= 0, .ts=     -2721600 },
    .{ .year = 1969, .month = 11, .day = 30, .hour=11, .min=30, .sec= 0, .ts=     -2723400 },
    .{ .year = 1969, .month = 11, .day = 30, .hour=11, .min=29, .sec=15, .ts=     -2723445 },
    .{ .year = 1968, .month = 12, .day = 15, .hour= 0, .min= 0, .sec= 0, .ts=    -33004800 },
    .{ .year = 1968, .month =  3, .day =  1, .hour= 0, .min= 0, .sec= 0, .ts=    -57974400 },
    .{ .year = 1968, .month =  2, .day = 29, .hour= 0, .min= 0, .sec= 0, .ts=    -58060800 },
    .{ .year = 1968, .month =  2, .day = 28, .hour= 0, .min= 0, .sec= 0, .ts=    -58147200 },
    .{ .year = 1900, .month =  1, .day =  1, .hour= 0, .min= 0, .sec= 0, .ts=  -2208988800 },
};

test "fromUnixTimeT" {
    for (TimeTests) |tst| {
        const date = AstroDate.fromUnixTime(tst.ts);
        const hms = ast.hrsToHMS(date.hours);
        try expect(date.year  == tst.year and
                   date.month == tst.month and
                   date.day   == tst.day and
                   hms.hour   == tst.hour and
                   hms.min    == tst.min and
                   hms.sec    == tst.sec);
    }
}

test "toUnixTime" {
    for (TimeTests) |tst| {
        const date = AstroDate.fromDateAndHMS(tst.year,tst.month,tst.day,tst.hour,tst.min,tst.sec, .{});
        const ts = AstroDate.toUnixTime(date);
        try expect(ts == tst.ts);
    }
}

test "daysBetweenDates" {
    try expect(ast.daysBetweenDates(.{ .year=1970, .month= 1, .day= 1 }, .{ .year=1970, .month= 1, .day= 2 }) == 1);
    try expect(ast.daysBetweenDates(.{ .year=1970, .month= 1, .day= 1 }, .{ .year=1970, .month= 1, .day=31 }) == 30);
    try expect(ast.daysBetweenDates(.{ .year=1970, .month= 1, .day= 1 }, .{ .year=1970, .month=12, .day=31 }) == 364);
    try expect(ast.daysBetweenDates(.{ .year=1972, .month= 2, .day=29 }, .{ .year=1972, .month= 3, .day= 1 }) == 1);
    try expect(ast.daysBetweenDates(.{ .year=2022, .month=12, .day=31 }, .{ .year=2023, .month=12, .day=31 }) == 365);
    try expect(ast.daysBetweenDates(.{ .year=1910, .month=4,  .day=20 }, .{ .year=1986, .month=2, .day=9}) == 27689);
    try expect(ast.daysBetweenDates(.{ .year=1991, .month=7,  .day=11 }, .{ .year=2018, .month=11, .day=26}) == 10000);
}

test "hmsToDec" {
    var h: u8 = 0;
    while (h < 24) : (h += 1) {
        var m: u8 = 0;
        while (m < 60) : (m += 1) {
            var s: u8 = 0;
            while (s < 60) : (s += 1) {
                const hrs = ast.hmsToHrs(.{.hour=h, .min=m, .sec=s});
                const hms = ast.hrsToHMS(hrs);
                try expect(hms.hour == h and
                           hms.min == m and
                           hms.sec == s);
            }
        }
    }
}

test "utToGST" {
    // [Lawrence, 2018] p 47-48
    const utDate = AstroDate.fromDateAndHMS(2010, 2, 7, 23, 30, 0, .{});
    const gstDate = ast.utToGST(utDate);
    const hms = ast.hrsToHMS(gstDate.hours);
    try expect(hms.hour == 8 and hms.min == 41 and hms.sec == 53);
}

test "gstToUT" {
    // [Lawrence, 2018] p 48-49
    const gstDate = AstroDate.fromDateAndHMS(2010, 2, 7, 8, 41, 53, .{});
    const utDate = ast.gstToUT(gstDate);
    const hms = ast.hrsToHMS(utDate.hours);
    try expect(hms.hour == 23 and hms.min == 30 and hms.sec == 0);
}

test "gstToLST" {
    // [Lawrence, 2018] p 50
    // const gstDate = AstroDate{ .year=2010, .month=2, .day=7, .hour=2, .min=3, .sec=41 };
    const gstDate = AstroDate.fromDateAndHMS(2010, 2, 7, 2, 3, 41, .{});
    const lstDate = ast.gstToLST(gstDate, -40.0); // Longitude 40° W
    const hms = ast.hrsToHMS(lstDate.hours);
    try expect(hms.hour == 23 and hms.min == 23 and hms.sec == 41);
}

test "lstToGST" {
    // [Lawrence, 2018] p 50
    // const lstDate = AstroDate{ .year=2010, .month=2, .day=7, .hour=23, .min=23, .sec=41 };
    const lstDate = AstroDate.fromDateAndHMS(2010, 2, 7, 23, 23, 41, .{});
    const gstDate = ast.lstToGST(lstDate, 50.0); // Longitude 50° E
    const hms = ast.hrsToHMS(gstDate.hours);
    try expect(hms.hour == 20 and hms.min == 3 and hms.sec == 41);
}

test "nextDay" {
    var y: Year = undefined;
    var m: Month = undefined;
    var d: Day = undefined;

    y, m, d = ast.nextDay(2025, 10, 18);
    try expect(y == 2025 and m == 10 and d == 19);

    y, m, d = ast.nextDay(2025, 10, 31);
    try expect(y == 2025 and m == 11 and d == 1);

    y, m, d = ast.nextDay(2025, 12, 31);
    try expect(y == 2026 and m == 1 and d == 1);
}

test "previousDay" {
    var y: Year = undefined;
    var m: Month = undefined;
    var d: Day = undefined;

    y, m, d = ast.previousDay(2025, 10, 18);
    try expect(y == 2025 and m == 10 and d == 17);

    y, m, d = ast.previousDay(2025, 11, 1);
    try expect(y == 2025 and m == 10 and d == 31);

    y, m, d = ast.previousDay(2025, 10, 1);
    try expect(y == 2025 and m == 9 and d == 30);

    y, m, d = ast.previousDay(2025, 3, 1);
    try expect(y == 2025 and m == 2 and d == 28);

    y, m, d = ast.previousDay(2000, 3, 1);
    try expect(y == 2000 and m == 2 and d == 29);

    y, m, d = ast.previousDay(2026, 1, 1);
    try expect(y == 2025 and m == 12 and d == 31);
}

test "TimeZone" {
    var tz = TimeZone.init(true, -5, -15); // UTC-5:15 with DST
    var tz_str = try tz.toString(allocator);
    defer allocator.free(tz_str);
    try expect(std.mem.eql(u8, tz_str, "-05:15 DST"));
    allocator.free(tz_str);
    var offset_hours = tz.getOffsetHours();
    try expect(std.math.approxEqAbs(f64, offset_hours, -4.25, 0.0001));

    tz = TimeZone.init(false, -5, -30); // UTC-5:30
    tz_str = try tz.toString(allocator);
    try expect(std.mem.eql(u8, tz_str, "-05:30"));
    allocator.free(tz_str);
    offset_hours = tz.getOffsetHours();
    try expect(std.math.approxEqAbs(f64, offset_hours, -5.5, 0.0001));

    tz = TimeZone.init(true, -5, -45); // UTC-5:45 with DST
    tz_str = try tz.toString(allocator);
    try expect(std.mem.eql(u8, tz_str, "-05:45 DST"));
    allocator.free(tz_str);
    offset_hours = tz.getOffsetHours();
    try expect(std.math.approxEqAbs(f64, offset_hours, -4.75, 0.0001));

    tz = TimeZone.init(true, 5, 0); // UTC+5:00 with DST
    tz_str = try tz.toString(allocator);
    try expect(std.mem.eql(u8, tz_str, "+05:00 DST"));
    allocator.free(tz_str);
    offset_hours = tz.getOffsetHours();
    try expect(std.math.approxEqAbs(f64, offset_hours, 6.0, 0.0001));

    tz = TimeZone.init(false, 13, 30); // UTC+13:30
    tz_str = try tz.toString(allocator);
    try expect(std.mem.eql(u8, tz_str, "+13:30"));

    offset_hours = tz.getOffsetHours();
    try expect(std.math.approxEqAbs(f64, offset_hours, 13.5, 0.0001));

    const loc = GeoCoord.init(Angle.fromDegrees(38.0), Angle.fromDegrees(-78.0));
    tz = TimeZone.fromLocation(loc, true);
    try expect(tz.offset == -20); // -5 hours in 15-min units
    try expect(tz.dst == true);
}