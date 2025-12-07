const std = @import("std");
const lib = @import("astrolib");

const orb = lib.orb;

const ang = lib.ang;
const Angle = ang.Angle;

const ast = lib.ast;
const AstroDate = ast.AstroDate;
const Year = ast.Year;
const Month = ast.Month;
const Day = ast.Day;

const crd = lib.crd;
const GeoCoord = crd.GeoCoord;
const RaDec = crd.RaDec;
const HorCoord = crd.HorCoord;
const EclipticCoord = crd.EclipticCoord;

const sol = lib.sol;
const HelioCoord = sol.HelioCoord;
const Body = sol.Body;
const bodies = sol.bodies;
const Sun = sol.Sun;
const Moon = sol.Moon;
const Mercury = sol.Mercury;
const Pluto = sol.Pluto;
const Earth = sol.Earth;
const Venus = sol.Venus;
const Saturn = sol.Saturn;

const expect = std.testing.expect;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;
const allocator = std.testing.allocator;

test "marchEquinox" {
    const year: Year = 2004;
    const date = sol.marchEquinox(year);
    const date_str = try date.toDateTimeString(allocator);
    defer allocator.free(date_str);
    // std.debug.print("March equinox for {d}: {s}\n", .{year, date_str});
    try expect(std.mem.eql(u8, date_str, "2004-03-20 06:42:35"));
}

test "juneSolstice" {
    const year: Year = 2004;
    const date = sol.juneSolstice(year);
    const date_str = try date.toDateTimeString(allocator);
    defer allocator.free(date_str);
    // std.debug.print("June solstice for {d}: {s}\n", .{year, date_str});
    try expect(std.mem.eql(u8, date_str, "2004-06-21 00:49:41"));
}

test "septemberEquinox" {
    const year: Year = 2004;
    const date = sol.septemberEquinox(year);
    const date_str = try date.toDateTimeString(allocator);
    defer allocator.free(date_str);
    // std.debug.print("September equinox for {d}: {s}\n", .{year, date_str});
    try expect(std.mem.eql(u8, date_str, "2004-09-22 16:27:20"));
}

test "decemberSolstice" {
    const year: Year = 2004;
    const date = sol.decemberSolstice(year);
    const date_str = try date.toDateTimeString(allocator);
    defer allocator.free(date_str);
    // std.debug.print("December solstice for {d}: {s}\n", .{year, date_str});
    try expect(std.mem.eql(u8, date_str, "2004-12-21 12:44:22"));
}

test "sunHorCoord" {
    const date = AstroDate.fromDateAndHMS(2015, 2, 5, 12, 0, 0, ast.tzEST);
    const loc = GeoCoord.init(Angle.fromDegrees(38), Angle.fromDegrees(-78));
    const hr = sol.sunHorCoord(date, loc);
    const hr_str = try hr.toString(allocator);
    defer allocator.free(hr_str);
    // std.debug.print("{s}\n\n", .{hr_str});
    try expect(std.mem.eql(u8, hr_str, "h=35°47′13″, A=172°16′25″"));
}

test "sunRaDec" {
    const date = AstroDate.fromDateAndHMS(2015, 2, 5, 12, 0, 0, ast.tzEST);
    const equ = sol.sunRaDec(date);
    const equ_str = try equ.toString(allocator);
    defer allocator.free(equ_str);
    // std.debug.print("{s}\n\n", .{equ_str});
    try expect(std.mem.eql(u8, equ_str, "α=21ʰ16ᵐ08ˢ, δ=-15°52′01″"));
}

test "sunEclipticCoord" {
    const date = AstroDate.fromDateAndHMS(2015, 2, 5, 12, 0, 0, ast.tzEST);
    const ecl = sol.sunEclipticCoord(date);
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

//     std.debug.print("M={d}, ta={d}\n", .{M.toDegrees(), v.toDegrees()});
// }

// test "keplerNewtonRaphson" {
//     std.debug.print("Kepler via Newton-Raphson\n", .{});
//     const e: f64 = 0.5;
//     const M = Angle.fromDegrees(24.742896);
//     const E = orb.keplerNewtonRaphson(e, M);

//     std.debug.print("M={d}, E={d}\n", .{M.toDegrees(), E.toDegrees()});
// }

// test "keplerSimple" {
//     std.debug.print("Kepler via simple iteration\n", .{});
//     const e: f64 = 0.5;
//     const M = Angle.fromDegrees(24.742896);
//     const E = orb.keplerSimple(e, M);

//     std.debug.print("M={d}, E={d}\n", .{M.toDegrees(), E.toDegrees()});
// }

// fn printTrueAnomaly(e: f64, M: Angle) void {
//     std.debug.print("\nComparing methods: e={d:.6}, M={d:.6}\n", .{e, M.toDegrees()});
//     const v1 = orb.trueAnomalyFromEqCtr(e, M);
//     const v2 = orb.trueAnomalyFromKeplerCos(e, M);
//     const v3 = orb.trueAnomalyFromKeplerTan(e, M);
//     const v4 = orb.trueAnomalyFromKeplerSeries(e, M);

//     std.debug.print("EqCtr    {d:.6}\n", .{v1.toDegrees()});
//     std.debug.print("KepCos   {d:.6}\n", .{v2.toDegrees()});
//     std.debug.print("KepTan   {d:.6}\n", .{v3.toDegrees()});
//     std.debug.print("KepSer   {d:.6}\n", .{v4.toDegrees()});
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
    const ras = try sol.sunRiseAndSet(loc, date);

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

    // const ras2 = try sol.sunRiseAndSet2(loc, date);

    // const strr2 = try ras2.rise_lct.toTimeString(allocator);
    // defer allocator.free(strr2);

    // const strs2 = try ras2.set_lct.toTimeString(allocator);
    // defer allocator.free(strs2);

    // std.debug.print("  LCTr = {s}\n", .{strr2});
    // std.debug.print("  LCTs = {s}\n", .{strs2});
}

test "moonHorCoord" {
    const date = AstroDate.fromDateAndHours(2015, 1, 1, 22, ast.tzEST);
    const loc = GeoCoord.init(Angle.fromDegrees(38),   // New York City
                                        Angle.fromDegrees(-78));
    const hc = sol.moonHorCoord(date, loc);
    const hc_str = try hc.toString(allocator);
    defer allocator.free(hc_str);
    try expect(std.mem.eql(u8, hc_str, "h=68°51′54″, A=192°11′24″"));
}

test "moonRaDec" {
    const date = AstroDate.fromDateAndHours(2015, 1, 1, 22, ast.tzEST);
    const equ = sol.moonRaDec(date);
    const equ_str = try equ.toString(allocator);
    defer allocator.free(equ_str);
    try expect(std.mem.eql(u8, equ_str, "α=04ʰ15ᵐ28ˢ, δ=17°14′56″"));
}

test "moonEclipticCoord" {
    const date = AstroDate.fromDateAndHours(2015, 1, 1, 22, ast.tzEST);
    const ec = sol.moonEclipticCoord(date);
    const ec_str = try ec.toString(allocator);
    defer allocator.free(ec_str);
    try expect(std.mem.eql(u8, ec_str, "β=-00ʰ15ᵐ50ˢ, λ=65°03′35″"));
}

test "moonPhase" {
    const date = AstroDate.fromDateAndHMS(2015, 1, 1, 0, 0, 0, .{});
    const phase = sol.moonPhase(date);

    // std.debug.print("Elongation={d:.6}\n", .{phase.elong.toDegrees()});
    // std.debug.print("Illumination={d:.6}\n", .{phase.illum});
    // std.debug.print("Age days={d:.6}\n", .{phase.age_days});
    // std.debug.print("Phase name={s}\n", .{phase.name});

    try expectApproxEqAbs(129.968_447, phase.elong.toDegrees(), 0.000_001);
    try expectApproxEqAbs(0.821_907, phase.illum, 0.000_001);
    try expectApproxEqAbs(10.661_240, phase.age_days, 0.000_001);
    try expect(std.mem.eql(u8, phase.name, "Waxing Gibbous"));
}

test "bodyHorCoord" {
    const date = AstroDate.fromDateAndHours(2016, 1, 3, 22, ast.tzEST);
    const loc = GeoCoord.init(Angle.fromDegrees(38),   // New York City
                                        Angle.fromDegrees(-78));
    const earth = HelioCoord.fromDate(&bodies[Earth], date);

    var hor: HorCoord = undefined;

    hor = sol.bodyHorCoord(&bodies[Venus], date, &earth, loc);
    var hor_str = try hor.toString(allocator);
    defer allocator.free(hor_str);
    try expect(std.mem.eql(u8, hor_str, "h=-70°42′24″, A=17°08′10″"));
    // std.debug.print("Venus        {s}\n", .{hor_str});
    allocator.free(hor_str);

    hor = sol.bodyHorCoord(&bodies[Saturn], date, &earth, loc);
    hor_str = try hor.toString(allocator);
    try expect(std.mem.eql(u8, hor_str, "h=-72°32′15″, A=0°07′56″"));
    // std.debug.print("Saturn       {s}\n", .{hor_str});
}

test "bodyRaDec" {
    const date = AstroDate.fromDateAndHours(2016, 1, 3, 22, ast.tzEST);
    const earth = HelioCoord.fromDate(&bodies[Earth], date);

    var radec: RaDec = undefined;

    radec = sol.bodyRaDec(&bodies[Venus], date, &earth);
    var radec_str = try radec.toString(allocator);
    defer allocator.free(radec_str);
    // std.debug.print("        Venus:  {s}\n", .{radec_str});
    // std.debug.print("        ra={d:.6}, dec={d:.6}\n", .{radec.ra.toHours(), radec.dec.toDegrees()});
    try expect(std.mem.eql(u8, radec_str, "α=16ʰ16ᵐ59ˢ, δ=-19°24′26″"));
    allocator.free(radec_str);

    radec = sol.bodyRaDec(&bodies[Saturn], date, &earth);
    radec_str = try radec.toString(allocator);
    // std.debug.print("        Saturn: {s}\n", .{radec_str});
    // std.debug.print("        ra={d:.6}, dec={d:.6}\n", .{radec.ra.toHours(), radec.dec.toDegrees()});
    try expect(std.mem.eql(u8, radec_str, "α=16ʰ40ᵐ31ˢ, δ=-20°32′15″"));
}

test "bodyEcliptic" {
    const date = AstroDate.fromDateAndHours(2016, 1, 3, 22, ast.tzEST);
    const earth = HelioCoord.fromDate(&bodies[Earth], date);

    const venus = sol.bodyEcliptic(&bodies[Venus], date, &earth);
    const venus_str = try venus.toString(allocator);
    defer allocator.free(venus_str);
    // std.debug.print("Venus:  {s}\n", .{venus_str});
    try expect(std.mem.eql(u8, venus_str, "β=00ʰ07ᵐ35ˢ, λ=245°47′34″"));

    const saturn = sol.bodyEcliptic(&bodies[Saturn], date, &earth);
    const saturn_str = try saturn.toString(allocator);
    defer allocator.free(saturn_str);
    // std.debug.print("Saturn: {s}\n", .{saturn_str});
    try expect(std.mem.eql(u8, saturn_str, "β=00ʰ06ᵐ31ˢ, λ=251°25′54″"));
}

// test "Bodies" {
//     const sun = &bodies[Sun];
//     const moon = &bodies[Moon];
//     const pluto = &bodies[Pluto];

//     std.debug.print("Sun:  mass={d}, grav_parm={d}\n", .{sun.mass, sun.grav_parm});
//     std.debug.print("Moon: mass={d}, grav_parm={d}\n", .{moon.mass, moon.grav_parm});
//     std.debug.print("{s}: inclination = {d}, longitude at epoch = {d:.6}\n", .{pluto.name,pluto.inclination,pluto.lon_at_epoch});

//     for (bodies[Mercury..], 0..) |*p, i| {
//         std.debug.print("{d:>2} - {s}\n", .{i, p.name});
//     }
// }

