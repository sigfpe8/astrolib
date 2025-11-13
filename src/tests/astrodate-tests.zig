const std = @import("std");
const ast = @import("astrolib").ast;
const AstroDate = ast.AstroDate;
const TimeZone = ast.TimeZone;
const UnixTime = ast.UnixTime;
const Year = ast.Year;
const Month = ast.Month;
const Day = ast.Day;
const Allocator = std.mem.Allocator;

const expect = std.testing.expect;
const print = std.debug.print;
//const DebugAllocator = @import("heap.debug_allocator").DebugAllocator;

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
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const date = AstroDate{.year = 2000, .month = 1, .day = 1, .hour = 12};
    const date_str = try date.toDateString(allocator);
    try expect(std.mem.eql(u8, date_str, "2000-01-01"));
    allocator.free(date_str);
}

test "toTimeString" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const date = AstroDate{.year = 2000, .month = 1, .day = 1, .hour = 12, .min = 30, .sec = 30 };
    const time_str = try date.toTimeString(allocator);
    try expect(std.mem.eql(u8, time_str, "12:30:30"));
    allocator.free(time_str);
}

test "toDateTimeString" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const date = AstroDate{.year = 2025, .month = 5, .day = 23, .hour = 23, .min = 59, .sec = 59};
    const date_time_str = try date.toDateTimeString(allocator);
    try expect(std.mem.eql(u8, date_time_str, "2025-05-23 23:59:59"));
    allocator.free(date_time_str);
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
    date: AstroDate,
    ts: UnixTime,
};

const TimeTests = [_]TimeTest{
    .{ .date = .{ .year=1970, .month= 1, .day= 1, .hour= 0, .min= 0, .sec= 0}, .ts=            0 },
    .{ .date = .{ .year=1970, .month= 1, .day= 1, .hour=12, .min=30, .sec=45}, .ts=        45045 },
    .{ .date = .{ .year=1970, .month= 1, .day= 1, .hour=23, .min=59, .sec=59}, .ts=        86399 },
    .{ .date = .{ .year=1970, .month=12, .day=31, .hour=23, .min=59, .sec=59}, .ts=     31535999 },
    .{ .date = .{ .year=1971, .month=12, .day=31, .hour=23, .min=59, .sec=59}, .ts=     63071999 },
    .{ .date = .{ .year=1972, .month= 2, .day=29, .hour= 0, .min= 0, .sec= 0}, .ts=     68169600 },
    .{ .date = .{ .year=1972, .month= 3, .day= 1, .hour= 0, .min= 0, .sec= 0}, .ts=     68256000 },
    .{ .date = .{ .year=1980, .month=12, .day=31, .hour=23, .min=59, .sec=59}, .ts=    347155199 },
    .{ .date = .{ .year=1999, .month=12, .day=31, .hour=23, .min=59, .sec=59}, .ts=    946684799 },
    .{ .date = .{ .year=2000, .month= 2, .day=29, .hour=12, .min= 0, .sec= 0}, .ts=    951825600 },
    .{ .date = .{ .year=2022, .month=12, .day=31, .hour=23, .min=59, .sec=59}, .ts=   1672531199 },
    .{ .date = .{ .year=2038, .month=12, .day=31, .hour=23, .min=59, .sec=59}, .ts=   2177452799 },
    .{ .date = .{ .year=2138, .month=12, .day=31, .hour=23, .min=59, .sec=59}, .ts=   5333126399 },

    .{ .date = .{ .year=1969, .month=12, .day=31, .hour=23, .min=59, .sec=59}, .ts=           -1 },
    .{ .date = .{ .year=1969, .month=12, .day=31, .hour= 0, .min= 0, .sec= 0}, .ts=       -86400 },
    .{ .date = .{ .year=1969, .month=12, .day= 1, .hour= 0, .min= 0, .sec= 0}, .ts=     -2678400 },
    .{ .date = .{ .year=1969, .month=11, .day=30, .hour=12, .min= 0, .sec= 0}, .ts=     -2721600 },
    .{ .date = .{ .year=1969, .month=11, .day=30, .hour=11, .min=30, .sec= 0}, .ts=     -2723400 },
    .{ .date = .{ .year=1969, .month=11, .day=30, .hour=11, .min=29, .sec=15}, .ts=     -2723445 },
    .{ .date = .{ .year=1968, .month=12, .day=15, .hour= 0, .min= 0, .sec= 0}, .ts=    -33004800 },
    .{ .date = .{ .year=1968, .month= 3, .day= 1, .hour= 0, .min= 0, .sec= 0}, .ts=    -57974400 },
    .{ .date = .{ .year=1968, .month= 2, .day=29, .hour= 0, .min= 0, .sec= 0}, .ts=    -58060800 },
    .{ .date = .{ .year=1968, .month= 2, .day=28, .hour= 0, .min= 0, .sec= 0}, .ts=    -58147200 },
    .{ .date = .{ .year=1900, .month= 1, .day= 1, .hour= 0, .min= 0, .sec= 0}, .ts=  -2208988800 },
};

test "fromUnixTimeT" {
    for (TimeTests) |tst| {
        const date = AstroDate.fromUnixTime(tst.ts);
        try expect(date.year == tst.date.year and
                   date.month == tst.date.month and
                   date.day == tst.date.day and
                   date.hour == tst.date.hour and
                   date.min == tst.date.min and
                   date.sec == tst.date.sec);
    }
}

test "toUnixTime" {
    for (TimeTests) |tst| {
        const ts = AstroDate.toUnixTime(tst.date);
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
                const dec = ast.hmsToDec(h, m, s);
                const date = ast.decToHMS(dec);
                try expect(date.hour == h and
                           date.min == m and
                           date.sec == s);
            }
        }
    }
}

test "utToGST" {
    // [Lawrence, 2018] p 47-48
    const utDate = AstroDate{ .year=2010, .month=2, .day=7, .hour=23, .min=30, .sec=0 };
    const gstDate = ast.utToGST(utDate);
    try expect(gstDate.hour == 8 and gstDate.min == 41 and gstDate.sec == 53);
}

test "gstToUT" {
    // [Lawrence, 2018] p 48-49
    const gstDate = AstroDate{ .year=2010, .month=2, .day=7, .hour=8, .min=41, .sec=53 };
    const utDate = ast.gstToUT(gstDate);
    try expect(utDate.hour == 23 and utDate.min == 30 and utDate.sec == 0);
}

test "gstToLST" {
    // [Lawrence, 2018] p 50
    const gstDate = AstroDate{ .year=2010, .month=2, .day=7, .hour=2, .min=3, .sec=41 };
    const lstDate = ast.gstToLST(gstDate, -40.0); // Longitude 40° W
    try expect(lstDate.hour == 23 and lstDate.min == 23 and lstDate.sec == 41);
}

test "lstToGST" {
    // [Lawrence, 2018] p 50
    const lstDate = AstroDate{ .year=2010, .month=2, .day=7, .hour=23, .min=23, .sec=41 };
    const gstDate = ast.lstToGST(lstDate, 50.0); // Longitude 50° E
    try expect(gstDate.hour == 20 and gstDate.min == 3 and gstDate.sec == 41);
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
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tz = TimeZone.init(true, -5, -15); // UTC-5:15 with DST
    var tz_str = try tz.toString(allocator);
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

    tz = TimeZone.init(true, -5, -45); // UTC-5:30 with DST
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
    allocator.free(tz_str);
    offset_hours = tz.getOffsetHours();
    try expect(std.math.approxEqAbs(f64, offset_hours, 13.5, 0.0001));

}