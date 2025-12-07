const std = @import("std");
// const ast = @import("astrodate.zig");
const lib = @import("astrolib");
const ang = lib.ang;
const ast = lib.ast;
const crd = lib.crd;
const sol = lib.sol;
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

    // std.debug.print("Sizeof(AstroDate): {}\n", .{@sizeOf(AstroDate)});
    // std.debug.print("Sizeof(TimeZone): {}\n", .{@sizeOf(TimeZone)});

    const date_ut = ast.now();
    const date = ast.utToLCT(date_ut, ast.tzEST);
    const date_str = try date.toString(allocator);
    defer allocator.free(date_str);

    std.debug.print("\nCurrent date and time in NYC: {s}\n", .{date_str});

    const loc = GeoCoord.init(Angle.fromDMS(DMS{.sign='+',.deg=40,.min=42,.sec=46}),   // New York City
                                        Angle.fromDMS(DMS{.sign='-',.deg=74,.min=0,.sec=22}));
    const loc_str = try loc.toString(allocator);
    defer allocator.free(loc_str);

    const ras = try sol.sunRiseAndSet(loc, date);

    const strr = try ras.rise_lct.toTimeString(allocator);
    defer allocator.free(strr);

    const strs = try ras.set_lct.toTimeString(allocator);
    defer allocator.free(strs);

    std.debug.print("\nSunrise and sunset for NYC ({s}) today\n", .{loc_str});
    std.debug.print("  Sunrise = {s}\n", .{strr});
    std.debug.print("  Sunset  = {s}\n", .{strs});

    const radec = sol.sunRaDec(date);
    const radec_str = try radec.toString(allocator);
    defer allocator.free(radec_str);
    std.debug.print("Sun position: {s}\n", .{radec_str});

    const obj = RaDec.init(Angle.fromHMS(HMS{.sign='+',.hour=5,.min=55,.sec=10.3053}),  // Betelgeuse
                                  Angle.fromDMS(DMS{.sign='+',.deg=7,.min=24,.sec=25.426}));

    const obj_str = try obj.toString(allocator);
    defer allocator.free(obj_str);
    std.debug.print("\nRise and set time for Betelgeuse ({s}) today in NYC:\n", .{obj_str});

    const rs = try crd.riseAndSet(loc, date, obj);
    const rise_lct_str = try rs.rise_lct.toString(allocator);
    defer allocator.free(rise_lct_str);
    const set_lct_str = try rs.set_lct.toString(allocator);
    defer allocator.free(set_lct_str);
    const rise_az_str = try rs.rise_az.toDMSString(allocator);
    defer allocator.free(rise_az_str);
    const set_az_str = try rs.set_az.toDMSString(allocator);
    defer allocator.free(set_az_str);

    std.debug.print("  Rise Time: {s}, Azimuth: {s}\n", .{rise_lct_str, rise_az_str});
    std.debug.print("  Set Time:  {s}, Azimuth: {s}\n", .{set_lct_str, set_az_str});

    try allPlanetPositions(allocator, date);
}

const HelioCoord = sol.HelioCoord;
const Body = sol.Body;
const bodies = sol.bodies;
const Earth = sol.Earth;
const Mercury = sol.Mercury;

fn allPlanetPositions(allocator: std.mem.Allocator, date: AstroDate) !void {
    const earth = sol.HelioCoord.fromDate(&bodies[Earth], date);
    const date_str = try date.toString(allocator);
    defer allocator.free(date_str);
    std.debug.print("\nPlanet positions for date: {s}\n", .{date_str});

    for (bodies[Mercury..]) |*p| {
        const radec = sol.bodyRaDec(p, date, &earth);
        const radec_str = try radec.toString(allocator);
        std.debug.print("{s:10} {s}\n", .{p.name, radec_str});
        allocator.free(radec_str);
    }
}