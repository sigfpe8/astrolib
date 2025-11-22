const std = @import("std");
const lib = @import("astrolib");
const ang = lib.ang;
const ast = lib.ast;
const crd = lib.crd;
const orb = lib.orb;
const sun = lib.sun;

const Angle = ang.Angle;

const AstroDate = ast.AstroDate;
const Year = ast.Year;
const Month = ast.Month;
const Day = ast.Day;

const GeoCoord = crd.GeoCoord;

const expect = std.testing.expect;
const allocator = std.testing.allocator;

test "marchEquinox" {
    const year: Year = 2004;
    const date = sun.marchEquinox(year);
    const date_str = try date.toDateTimeString(allocator);
    defer allocator.free(date_str);
    // std.debug.print("March equinox for {d}: {s}\n", .{year, date_str});
    try expect(std.mem.eql(u8, date_str, "2004-03-20 06:42:35"));
}

test "juneSolstice" {
    const year: Year = 2004;
    const date = sun.juneSolstice(year);
    const date_str = try date.toDateTimeString(allocator);
    defer allocator.free(date_str);
    // std.debug.print("June solstice for {d}: {s}\n", .{year, date_str});
    try expect(std.mem.eql(u8, date_str, "2004-06-21 00:49:41"));
}

test "septemberEquinox" {
    const year: Year = 2004;
    const date = sun.septemberEquinox(year);
    const date_str = try date.toDateTimeString(allocator);
    defer allocator.free(date_str);
    // std.debug.print("September equinox for {d}: {s}\n", .{year, date_str});
    try expect(std.mem.eql(u8, date_str, "2004-09-22 16:27:20"));
}

test "decemberSolstice" {
    const year: Year = 2004;
    const date = sun.decemberSolstice(year);
    const date_str = try date.toDateTimeString(allocator);
    defer allocator.free(date_str);
    // std.debug.print("December solstice for {d}: {s}\n", .{year, date_str});
    try expect(std.mem.eql(u8, date_str, "2004-12-21 12:44:22"));
}

test "sunHorCoord" {
    const date = AstroDate.fromDateAndHMS(2015, 2, 5, 12, 0, 0, ast.tzEST);
    const loc = GeoCoord.init(Angle.fromDegrees(38), Angle.fromDegrees(-78));
    const hr = sun.sunHorCoord(date, loc);
    const hr_str = try hr.toString(allocator);
    defer allocator.free(hr_str);
    // std.debug.print("{s}\n\n", .{hr_str});
    try expect(std.mem.eql(u8, hr_str, "h=35°47′13″, A=172°16′25″"));
}

test "sunRaDec" {
    const date = AstroDate.fromDateAndHMS(2015, 2, 5, 12, 0, 0, ast.tzEST);
    const equ = sun.sunRaDec(date);
    const equ_str = try equ.toString(allocator);
    defer allocator.free(equ_str);
    // std.debug.print("{s}\n\n", .{equ_str});
    try expect(std.mem.eql(u8, equ_str, "α=21ʰ16ᵐ08ˢ, δ=-15°52′01″"));
}

test "sunEclipticCoord" {
    const date = AstroDate.fromDateAndHMS(2015, 2, 5, 12, 0, 0, ast.tzEST);
    const ecl = sun.sunEclipticCoord(date);
    const ecl_str = try ecl.toString(allocator);
    defer allocator.free(ecl_str);
    // std.debug.print("{s}\n\n", .{ecl_str});
    try expect(std.mem.eql(u8, ecl_str, "β=00ʰ00ᵐ00ˢ, λ=316°34′50″"));
}

//  --------------
// test "trueAnomalyFromEqCtr" {
//     const e: f64 = 0.0167;
//     // const M = Angle.fromDegrees(98.8073);
//     const M = Angle.fromDegrees(180.0);
//     const v = orb.trueAnomalyFromEqCtr(e, M);

//     std.debug.print("M={d}, ta={d}\n", .{M.toDegrees().deg, v.toDegrees().deg});
// }

// test "keplerNewtonRaphson" {
//     std.debug.print("Kepler via Newton-Raphson\n", .{});
//     const e: f64 = 0.5;
//     const M = Angle.fromDegrees(24.742896);
//     const E = orb.keplerNewtonRaphson(e, M);

//     std.debug.print("M={d}, E={d}\n", .{M.toDegrees().deg, E.toDegrees().deg});
// }

// test "keplerSimple" {
//     std.debug.print("Kepler via simple iteration\n", .{});
//     const e: f64 = 0.5;
//     const M = Angle.fromDegrees(24.742896);
//     const E = orb.keplerSimple(e, M);

//     std.debug.print("M={d}, E={d}\n", .{M.toDegrees().deg, E.toDegrees().deg});
// }

// fn printTrueAnomaly(e: f64, M: Angle) void {
//     std.debug.print("\nComparing methods: e={d:.6}, M={d:.6}\n", .{e, M.toDegrees().deg});
//     const v1 = orb.trueAnomalyFromEqCtr(e, M);
//     const v2 = orb.trueAnomalyFromKeplerCos(e, M);
//     const v3 = orb.trueAnomalyFromKeplerTan(e, M);
//     const v4 = orb.trueAnomalyFromKeplerSeries(e, M);

//     std.debug.print("EqCtr    {d:.6}\n", .{v1.toDegrees().deg});
//     std.debug.print("KepCos   {d:.6}\n", .{v2.toDegrees().deg});
//     std.debug.print("KepTan   {d:.6}\n", .{v3.toDegrees().deg});
//     std.debug.print("KepSer   {d:.6}\n", .{v4.toDegrees().deg});
// }

// test "Compare Methods" {
//     const e: f64 = 0.1;

//     var deg: usize = 0;

//     while (deg <= 360) : (deg += 45) {
//         const M = Angle.fromDegrees(@floatFromInt(deg));
//         printTrueAnomaly(e, M);
//     }
// }

test "sunRiseAndSet" {
    const loc = GeoCoord.init(Angle.fromDegrees(38),   // New York City
                                        Angle.fromDegrees(-78));

    const date = AstroDate.fromDateAndHours(2015,2,5,0,ast.tzEST);

    // std.debug.print("Sun rise/set time test\n", .{});

    // std.debug.print("=> Lawrence approximation\n", .{});
    const ras = try sun.sunRiseAndSet(loc, date);

    const strr = try ras.rise_lct.toTimeString(allocator);
    defer allocator.free(strr);

    const strs = try ras.set_lct.toTimeString(allocator);
    defer allocator.free(strs);

    try expect(std.mem.eql(u8, strr, "07:18:35"));
    try expect(std.mem.eql(u8, strs, "17:31:46"));
    // std.debug.print("  LCTr = {s}\n", .{strr});
    // std.debug.print("  LCTs = {s}\n", .{strs});

    // ----------------------------------------------------
    // std.debug.print("=> Wikipedia approximation \n", .{});

    // const ras2 = try sun.sunRiseAndSet2(loc, date);

    // const strr2 = try ras2.rise_lct.toTimeString(allocator);
    // defer allocator.free(strr2);

    // const strs2 = try ras2.set_lct.toTimeString(allocator);
    // defer allocator.free(strs2);

    // std.debug.print("  LCTr = {s}\n", .{strr2});
    // std.debug.print("  LCTs = {s}\n", .{strs2});
}
