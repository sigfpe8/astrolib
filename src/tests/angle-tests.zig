const std = @import("std");
const lib = @import("astrolib");
const ang = lib.ang;

const Angle = ang.Angle;
const DMS = ang.DMS;
const HMS = ang.HMS;

const expect = std.testing.expect;

test "toString" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const angle_deg = Angle.fromDegrees(45.0);
    const angle_rad = angle_deg.toRadians();
    const angle_hrs = angle_deg.toHours();
    const test_ang = Angle.fromHours(-14.598333);
    const one_sec = Angle.fromDMS(DMS{
        .sign = '-',
        .deg = 0,
        .min = 0,
        .sec = 1.0,
    });

    const deg_str = try angle_deg.toString(allocator);
    const rad_str = try angle_rad.toString(allocator);
    const hrs_str = try angle_hrs.toString(allocator);
    const hms_str = try angle_deg.toHMSString(allocator);
    const dms_str = try angle_deg.toDMSString(allocator);
    const tst_str = try test_ang.toHMSString(allocator);
    const one_str = try one_sec.toDMSString(allocator);

    try expect(std.mem.eql(u8, deg_str, "45.0000°"));
    try expect(std.mem.eql(u8, rad_str, "0.7854 rad"));
    try expect(std.mem.eql(u8, hrs_str, "3.0000ʰ"));
    try expect(std.mem.eql(u8, hms_str, "03ʰ00ᵐ00ˢ"));
    try expect(std.mem.eql(u8, dms_str, "45°00'00\""));
    try expect(std.mem.eql(u8, tst_str, "-14ʰ35ᵐ54ˢ"));
    try expect(std.mem.eql(u8, one_str, "-0°00'01\""));

    allocator.free(deg_str);
    allocator.free(rad_str);
    allocator.free(hrs_str);
    allocator.free(hms_str);
    allocator.free(dms_str);
    allocator.free(tst_str);
    allocator.free(one_str);
}

test "fromDMS" {
    var angle = Angle.fromDMS(DMS{
        .sign = '+',
        .deg = 30,
        .min = 15,
        .sec = 50.0,
    });

    var deg = angle.toDegrees().deg;
    try expect(std.math.approxEqAbs(f64, deg, 30.2638888889, 0.00001));

    angle = Angle.fromDMS(DMS{
        .sign = '-',
        .deg = 0,
        .min = 30,
        .sec = 30.0,
    });

    deg = angle.toDegrees().deg;
    try expect(std.math.approxEqAbs(f64, deg,  -0.5083333,  0.00001));
}

test "fromHMS" {
    var angle = Angle.fromHMS(HMS{
        .sign = '+',
        .hour = 5,
        .min = 30,
        .sec = 0.0,
    });

    var hrs = angle.toHours().hrs;
    try expect(std.math.approxEqAbs(f64, hrs, 5.5, 0.00001));

    angle = Angle.fromHMS(HMS{
        .sign = '-',
        .hour = 2,
        .min = 15,
        .sec = 30.0,
    });

    hrs = angle.toHours().hrs;
    try expect(std.math.approxEqAbs(f64, hrs, -2.2583333, 0.00001));

    angle = Angle.fromHMS(HMS{
        .sign = '-',
        .hour = 0,
        .min = 0,
        .sec = 1.0,
    });

    hrs = angle.toHours().hrs;
    try expect(std.math.approxEqAbs(f64, hrs, -0.0002777778, 0.0000001));
}
