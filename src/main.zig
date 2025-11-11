const std = @import("std");
const ad = @import("astrodate.zig");
const AstroDate = ad.AstroDate;
const TimeZone = ad.TimeZone;
const Year = ad.Year;
const Month = ad.Month;
const Day = ad.Day;

pub fn main() !void {
    const dp: f64 = 360.0 * 3 + 25.0;
    const dn: f64 = -360.0 * 3 - 25.0;
    const rp: f64 = std.math.pi * 6 + 0.25;
    const rn: f64 = -std.math.pi * 6 - 0.25;

    std.debug.print("dp: {d}, dp mod 360: {d}\n", .{dp, @mod(dp, 360.0)});
    std.debug.print("dp: {d}, dp rem 360: {d}\n", .{dp, @rem(dp, 360.0)});
    std.debug.print("dn: {d}, dn mod 360: {d}\n", .{dn, @mod(dn, 360.0)});
    std.debug.print("dn: {d}, dn rem 360: {d}\n", .{dn, @rem(dn, 360.0)});
    std.debug.print("rp: {d}, rp mod 2π:  {d}\n", .{rp, @mod(rp, std.math.pi * 2)});
    std.debug.print("rp: {d}, rp rem 2π:  {d}\n", .{rp, @rem(rp, std.math.pi * 2)});
    std.debug.print("rn: {d}, rn mod 2π:  {d}\n", .{rn, @mod(rn, std.math.pi * 2)});
    std.debug.print("rn: {d}, rn rem 2π:  {d}\n", .{rn, @rem(rn, std.math.pi * 2)});

    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();


    var now = ad.now();
    now.tz = ad.TimeZone.init(true, 13, 30);

    // const date = AstroDate{.year = 2025, .month = 5, .day = 23, .hour = 23, .min = 59, .sec = 59};
    const date_time_str = try now.toString(allocator);
    std.debug.print("Current date and time: {s}\n", .{date_time_str});
    std.debug.print("Sizeof(AstroDate): {}\n", .{@sizeOf(AstroDate)});
    std.debug.print("Sizeof(TimeZone): {}\n", .{@sizeOf(TimeZone)});
    allocator.free(date_time_str);

    var date = AstroDate{ .year = 2010, .month = 2, .day = 7, .hour = 23, .min = 30, .sec = 0 };
    date = ad.utToGST(date);
    const date_str = try date.toString(allocator);
    std.debug.print("Date from JD 2436116.31: {s}\n", .{date_str});
    allocator.free(date_str);


    // var date = ad.fromJD(2436116.31);
    // var date_str = try date.toString(allocator);
    // std.debug.print("Date from JD 2436116.31: {s}\n", .{date_str});
    // allocator.free(date_str);

    // date = ad.fromJD(1842713.0);
    // date_str = try date.toString(allocator);
    // std.debug.print("Date from JD 1842713.0: {s}\n", .{date_str});
    // allocator.free(date_str);

    // date = ad.fromJD(1507900.13);
    // date_str = try date.toString(allocator);
    // std.debug.print("Date from JD 1507900.13: {s}\n", .{date_str});
    // allocator.free(date_str);
    // var date = ad.fromUnixTime(-1);
    // var date_str = try date.toString(allocator);
    // std.debug.print("Date from Unix time -1: {s}\n", .{date_str});
    // allocator.free(date_str);

    // date = ad.fromUnixTime(-86400);
    // date_str = try date.toString(allocator);
    // std.debug.print("Date from Unix time -86400: {s}\n", .{date_str});
    // allocator.free(date_str);

    // date = ad.fromUnixTime(-2678400);
    // date_str = try date.toString(allocator);
    // std.debug.print("Date from Unix time -2678400: {s}\n", .{date_str});
    // allocator.free(date_str);

    // date = ad.fromUnixTime(-2721600);
    // date_str = try date.toString(allocator);
    // std.debug.print("Date from Unix time -2721600: {s}\n", .{date_str});
    // allocator.free(date_str);

    // date = ad.fromUnixTime(-58060800);
    // date_str = try date.toString(allocator);
    // std.debug.print("Date from Unix time -58060800: {s}\n", .{date_str});
    // allocator.free(date_str);

    // date = ad.fromUnixTime(-2723445);
    // date_str = try date.toString(allocator);
    // std.debug.print("Date from Unix time -2723445: {s}\n", .{date_str});
    // allocator.free(date_str);

    // date = ad.fromUnixTime(-2208988800);
    // date_str = try date.toString(allocator);
    // std.debug.print("Date from Unix time -2208988800: {s}\n", .{date_str});
    // allocator.free(date_str);

    // date = ad.fromUnixTime(1672531199);
    // date_str = try date.toString(allocator);
    // std.debug.print("Date from Unix time 1672531199: {s}\n", .{date_str});
    // allocator.free(date_str);
}

