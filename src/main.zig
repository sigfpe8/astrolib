const std = @import("std");
// const ast = @import("astrodate.zig");
const lib = @import("astrolib");
const ang = lib.ang;
const ast = lib.ast;
const crd = lib.crd;
const Angle = ang.Angle;
const DMS = ang.DMS;
const HMS = ang.HMS;
const AstroDate = ast.AstroDate;
const TimeZone = ast.TimeZone;
const Year = ast.Year;
const Month = ast.Month;
const Day = ast.Day;
const GeoCoord = crd.GeoCoord;
const RaDec = crd.RaDec;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var now = ast.now();
    now.tz = ast.TimeZone.init(false, -3, 0);

    const date_time_str = try now.toString(allocator);
    std.debug.print("Current date and time: {s}\n", .{date_time_str});
    // std.debug.print("Sizeof(AstroDate): {}\n", .{@sizeOf(AstroDate)});
    // std.debug.print("Sizeof(TimeZone): {}\n", .{@sizeOf(TimeZone)});
    allocator.free(date_time_str);

    var date = AstroDate{ .year = 2010, .month = 2, .day = 7, .hour = 23, .min = 30, .sec = 0 };
    date = ast.utToGST(date);
    const date_str = try date.toString(allocator);
    std.debug.print("Date from JD 2436116.31: {s}\n", .{date_str});
    allocator.free(date_str);

    const loc = GeoCoord.init(Angle.fromDMS(DMS{.sign='+',.deg=38,.min=0,.sec=0}),   // New York City
                                      Angle.fromDMS(DMS{.sign='-',.deg=78,.min=0,.sec=0}));
    date= AstroDate{ .year = 2016, .month = 1, .day = 21,
                     .hour = 12, .min = 0, .sec = 0, .tz = ast.tzEST };
    const obj = RaDec.init(Angle.fromHMS(HMS{.sign='+',.hour=5,.min=55,.sec=0}),  // Betelgeuse
                                  Angle.fromDMS(DMS{.sign='+',.deg=7,.min=30,.sec=0}));

    const rs = try crd.riseAndSet(loc, date, obj);
    const rise_time_str = try rs.rise_time.toString(allocator);
    const set_time_str = try rs.set_time.toString(allocator);
    const rise_az_str = try rs.rise_az.toDMSString(allocator);
    const set_az_str = try rs.set_az.toDMSString(allocator);

    std.debug.print("Rise Time: {s}, Azimuth: {s}\n", .{rise_time_str, rise_az_str});
    std.debug.print("Set Time:  {s}, Azimuth: {s}\n", .{set_time_str, set_az_str});

    allocator.free(rise_time_str);
    allocator.free(set_time_str);
    allocator.free(rise_az_str);
    allocator.free(set_az_str);
}

