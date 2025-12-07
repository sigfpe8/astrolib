const std = @import("std");
const lib = @import("astrolib");
const ang = lib.ang;

const Angle = ang.Angle;
const DMS = ang.DMS;
const HMS = ang.HMS;

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const allocator = std.testing.allocator;

test "toString" {
    const angle_deg = Angle.fromDegrees(45.0);
    const angle_rad = angle_deg.asRadians();
    const angle_hrs = angle_deg.asHours();
    const test_ang = Angle.fromHours(-14.598333);
    const one_sec = Angle.fromDMS(DMS{
        .sign = '-',
        .deg = 0,
        .min = 0,
        .sec = 1.0,
    });

    const deg_str = try angle_deg.toString(allocator);
    defer allocator.free(deg_str);
    const rad_str = try angle_rad.toString(allocator);
    defer allocator.free(rad_str);
    const hrs_str = try angle_hrs.toString(allocator);
    defer allocator.free(hrs_str);
    const hms_str = try angle_deg.toHMSString(allocator);
    defer allocator.free(hms_str);
    const dms_str = try angle_deg.toDMSString(allocator);
    defer allocator.free(dms_str);
    const tst_str = try test_ang.toHMSString(allocator);
    defer allocator.free(tst_str);
    const one_str = try one_sec.toDMSString(allocator);
    defer allocator.free(one_str);

    try expect(std.mem.eql(u8, deg_str, "45.0000°"));
    try expect(std.mem.eql(u8, rad_str, "0.7854 rad"));
    try expect(std.mem.eql(u8, hrs_str, "3.0000ʰ"));
    try expect(std.mem.eql(u8, hms_str, "03ʰ00ᵐ00ˢ"));
    try expect(std.mem.eql(u8, dms_str, "45°00′00″"));
    try expect(std.mem.eql(u8, tst_str, "-14ʰ35ᵐ54ˢ"));
    try expect(std.mem.eql(u8, one_str, "-0°00′01″"));
}

test "fromDMS" {
    var angle = Angle.fromDMS(DMS{
        .sign = '+',
        .deg = 30,
        .min = 15,
        .sec = 50.0,
    });

    var deg = angle.toDegrees();
    try expect(std.math.approxEqAbs(f64, deg, 30.2638888889, 0.00001));

    angle = Angle.fromDMS(DMS{
        .sign = '-',
        .deg = 0,
        .min = 30,
        .sec = 30.0,
    });

    deg = angle.toDegrees();
    try expect(std.math.approxEqAbs(f64, deg,  -0.5083333,  0.00001));
}

test "fromHMS" {
    var angle = Angle.fromHMS(HMS{
        .sign = '+',
        .hour = 5,
        .min = 30,
        .sec = 0.0,
    });

    var hrs = angle.toHours();
    try expect(std.math.approxEqAbs(f64, hrs, 5.5, 0.00001));

    angle = Angle.fromHMS(HMS{
        .sign = '-',
        .hour = 2,
        .min = 15,
        .sec = 30.0,
    });

    hrs = angle.toHours();
    try expect(std.math.approxEqAbs(f64, hrs, -2.2583333, 0.00001));

    angle = Angle.fromHMS(HMS{
        .sign = '-',
        .hour = 0,
        .min = 0,
        .sec = 1.0,
    });

    hrs = angle.toHours();
    try expect(std.math.approxEqAbs(f64, hrs, -0.0002777778, 0.0000001));
}

test "HMS.fromString" {
    var hms = try HMS.fromString("8h35m47s");
    try expect(hms.sign == '+' and hms.hour == 8 and hms.min == 35 and hms.sec == 47.0);
    hms = try HMS.fromString("+8ʰ53ᵐ01ˢ");
    try expect(hms.sign == '+' and hms.hour == 8 and hms.min == 53 and hms.sec == 1.0);
    hms = try HMS.fromString("-05h55m17.5s");
    try expect(hms.sign == '-' and hms.hour == 5 and hms.min == 55 and hms.sec == 17.5);
    hms = try HMS.fromString("-23ʰ59m59.555s #$%");
    try expect(hms.sign == '-' and hms.hour == 23 and hms.min == 59 and hms.sec == 59.555);

    try expectError(ang.AngleError.InvalidAngleFormat, HMS.fromString("12 00 00"));
    try expectError(ang.AngleError.HourIsTooBig, HMS.fromString("24h00m00s"));
    try expectError(ang.AngleError.MinuteIsTooBig, HMS.fromString("23h60m00s"));
    try expectError(ang.AngleError.SecondIsTooBig, HMS.fromString("23h59m60s"));
}

test "DMS.fromString" {
    var dms = try DMS.fromString("8°35'47\"");
    try expect(dms.sign == '+' and dms.deg == 8 and dms.min == 35 and dms.sec == 47.0);
    dms = try DMS.fromString("+358°53′01″");
    try expect(dms.sign == '+' and dms.deg == 358 and dms.min == 53 and dms.sec == 1.0);
    dms = try DMS.fromString("-05°55'17.5″");
    try expect(dms.sign == '-' and dms.deg == 5 and dms.min == 55 and dms.sec == 17.5);
    dms = try DMS.fromString("-23°59'59.555″ #$%");
    try expect(dms.sign == '-' and dms.deg == 23 and dms.min == 59 and dms.sec == 59.555);

    try expectError(ang.AngleError.InvalidAngleFormat, DMS.fromString("90 00 00"));
    try expectError(ang.AngleError.DegreeIsTooBig, DMS.fromString("360°00'00\""));
    try expectError(ang.AngleError.MinuteIsTooBig, DMS.fromString("270°60'00s"));
    try expectError(ang.AngleError.SecondIsTooBig, DMS.fromString("180°59'60\""));
}