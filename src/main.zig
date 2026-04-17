const std = @import("std");
// const ast = @import("astrodate.zig");
const lib = @import("astrolib");
const ang = lib.ang;
const ast = lib.ast;
const crd = lib.crd;
const sch = lib.sch;
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

const BUFFER_SIZE = 2048;
var stdout_buffer: [BUFFER_SIZE]u8 = undefined;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;
   // Get stdout
    var writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    const stdout = &writer.interface;

    // std.debug.print("Sizeof(AstroDate): {}\n", .{@sizeOf(AstroDate)});
    // std.debug.print("Sizeof(TimeZone): {}\n", .{@sizeOf(TimeZone)});

    const ut = ast.now(io);
    const today = ast.utToLCT(ut, ast.tzEST);
    const today_str = try today.toString(allocator);
    defer allocator.free(today_str);

    std.debug.print("\nCurrent date and time in NYC: {s}\n", .{today_str});

    const loc = GeoCoord.init(Angle.fromDMS(DMS{.sign='+',.deg=40,.min=42,.sec=46}),   // New York City
                                        Angle.fromDMS(DMS{.sign='-',.deg=74,.min=0,.sec=22}));
    const loc_str = try loc.toString(allocator);
    defer allocator.free(loc_str);

    const ras = try sol.sunRiseAndSet(loc, today);

    const strr = try ras.rise_lct.toTimeString(allocator);
    defer allocator.free(strr);

    const strs = try ras.set_lct.toTimeString(allocator);
    defer allocator.free(strs);

    std.debug.print("\nSunrise and sunset for NYC ({s}) today\n", .{loc_str});
    std.debug.print("  Sunrise = {s}\n", .{strr});
    std.debug.print("  Sunset  = {s}\n", .{strs});

    const radec = sol.sunRaDec(today);
    const radec_str = try radec.toString(allocator);
    defer allocator.free(radec_str);
    std.debug.print("Sun position now: {s}\n", .{radec_str});

    const obj = RaDec.init(Angle.fromHMS(HMS{.sign='+',.hour=5,.min=55,.sec=10.3053}),  // Betelgeuse
                                  Angle.fromDMS(DMS{.sign='+',.deg=7,.min=24,.sec=25.426}));

    const obj_str = try obj.toString(allocator);
    defer allocator.free(obj_str);
    std.debug.print("\nRise and set time for Betelgeuse ({s}) today in NYC:\n", .{obj_str});

    const rs = try crd.riseAndSet(loc, today, obj);
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

    const date = AstroDate.fromDateAndHours(2000, 1, 1, 12, .{});
    const date_str = try date.toString(allocator);
    defer allocator.free(date_str);
    try allPlanetPositions(allocator, date);
    try sol.equationOfTime(stdout, today.year, 10);
    try sol.analemma(stdout, allocator, today.year, 9.0, 12, loc);
}


const HelioCoord = sol.HelioCoord;
const Body = sol.Body;
const bodies = sol.bodies;
const Earth = sol.Earth;
const Mercury = sol.Mercury;

// JPL Ephemeris data for J2000.0 (2000-01-01 12:00 UT)
// Mercury, 272.085216823, -24.420380797,
// Venus, 239.901182168, -18.451853395,
// Mars, 330.524600894, -13.180499386,
// Jupiter,  23.869829157,   8.595898751,
// Saturn,  38.765998675,  12.616277574,
// Uranus, 317.483814310, -17.018841565,
// Neptune, 305.442651419, -19.212432532,
// Pluto, 251.428118762, -11.396418555,

const jpl_ephem = [_]RaDec {
    .{ .ra = Angle.fromDegrees(272.085216823), .dec = Angle.fromDegrees(-24.420380797) }, // Mercury
    .{ .ra = Angle.fromDegrees(239.901182168), .dec = Angle.fromDegrees(-18.451853395) }, // Venus
    .{ .ra = Angle.fromDegrees(330.524600894), .dec = Angle.fromDegrees(-13.180499386) }, // Mars
    .{ .ra = Angle.fromDegrees(23.869829157),  .dec = Angle.fromDegrees(8.595898751)   }, // Jupiter
    .{ .ra = Angle.fromDegrees(38.765998675),  .dec = Angle.fromDegrees(12.616277574)  }, // Saturn
    .{ .ra = Angle.fromDegrees(317.483814310), .dec = Angle.fromDegrees(-17.018841565) }, // Uranus
    .{ .ra = Angle.fromDegrees(305.442651419), .dec = Angle.fromDegrees(-19.212432532) }, // Neptune
    .{ .ra = Angle.fromDegrees(251.428118762), .dec = Angle.fromDegrees(-11.396418555) }, // Pluto
};

fn allPlanetPositions(allocator: std.mem.Allocator, date: AstroDate) !void {
    const date_str = try date.toString(allocator);
    defer allocator.free(date_str);
    std.debug.print("\nPlanet positions for date: {s}\n", .{date_str});
    const jd = date.toJD();
    std.debug.print("  JD = {d:.1}\n\n", .{jd});

    // Using algorithms from J.L. Lawrence (Celestial Calculations)
    const law = try sol.allPlanetPositions(date, allocator);
    defer allocator.free(law);
    // Using algorithms from P. Schlyter (http://www.stjarnhimlen.se/comp/ppcomp.html)
    const sly = try sch.allPlanetPositions(date.year, date.month, date.day, date.hours, allocator);
    defer allocator.free(sly);

    for (bodies[Mercury..], 0..) |*p, i| {
        const law_radec = law[i];
        const sly_radec = sly[i];
        const jpl_ra = jpl_ephem[i].ra.toDegrees();
        const jpl_dec = jpl_ephem[i].dec.toDegrees();

        std.debug.print("{s:10}: RA={d:10.6}°, Decl={d:10.6}°  (JPL)\n",
                    .{p.name, jpl_ra, jpl_dec});
        var ra = law_radec.ra.toDegrees();
        var dec = law_radec.dec.toDegrees();
        std.debug.print("{s:10}  RA={d:10.6}°, Decl={d:10.6}°  (Lawrence)  ΔJPL=({d:8.4}′, {d:8.4}′)\n",
                    .{"", ra, dec, (ra - jpl_ra) * 60, (dec - jpl_dec) * 60});
        ra = sly_radec.ra.toDegrees();
        dec = sly_radec.dec.toDegrees();
        std.debug.print("{s:10}  RA={d:10.6}°, Decl={d:10.6}°  (Schlyter)  ΔJPL=({d:8.4}′, {d:8.4}′)\n\n",
                    .{"", ra, dec, (ra - jpl_ra) * 60, (dec - jpl_dec) * 60});
    }
}

