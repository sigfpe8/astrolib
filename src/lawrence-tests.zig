// Tests from the exercises in the book "Celestial Calculations" by J. L. Lawrence

const std = @import("std");
const ad = @import("astrodate.zig");
const ang = @import("angle.zig");
const crd = @import("coords.zig");
const AstroDate = ad.AstroDate;
const TimeZone = ad.TimeZone;
const UnixTime = ad.UnixTime;
const Year = ad.Year;
const Month = ad.Month;
const Day = ad.Day;
const Angle = ang.Angle;
const DMS = ang.DMS;
const HMS = ang.HMS;
const CoordError = crd.CoordError;
const GeoCoord = crd.GeoCoord;
const RaDec = crd.RaDec;
const HorCoord = crd.HorCoord;
const Allocator = std.mem.Allocator;

const expect = std.testing.expect;
const allocator = std.testing.allocator;
const print = std.debug.print;

// Chapter 3 - Time Conversions
test "Chapter 3" {
    // 1. Was 1984 a leap year? (yes)
    try expect(ad.isLeapYear(1984) == true);

    // 2. Was 1974 a leap year? (no)
    try expect(ad.isLeapYear(1974) == false);

    // 3. Was 2000 a leap year? (yes)
    try expect(ad.isLeapYear(2000) == true);

    // 4. Was 1900 a leap year? (no)
    try expect(ad.isLeapYear(1900) == false);

    // 5 Convert midnight UT on November 1, 2010 to its Julian day number. (2455501.5)
    var date = AstroDate{ .year = 2010, .month = 11, .day = 1, .hour = 0, .min = 0, .sec = 0 };
    var jd = date.toJD();
    try expect(std.math.approxEqAbs(f64, jd, 2455501.5, 0.0001));

    // 6. Convert 6h UT on May 10, 2015, to its Julian day number. (2457152.75)
    date = AstroDate{ .year = 2015, .month = 5, .day = 10, .hour = 6, .min = 0, .sec = 0 };
    jd = date.toJD();
    try expect(std.math.approxEqAbs(f64, jd, 2457152.75, 0.0001));

    // 7. Convert 18h UT on May 10, 2015, to its Julian day number. (2457153.25)
    date = AstroDate{ .year = 2015, .month = 5, .day = 10, .hour = 18, .min = 0, .sec = 0 };
    jd = date.toJD();
    try expect(std.math.approxEqAbs(f64, jd, 2457153.25, 0.0001));

    // 8. Convert 2,369,915.5 to its corresponding calendar date. (1776-07-04 at midnight UT)
    date = AstroDate.fromJD(2_369_915.5);
    try expect(date.year == 1776 and date.month == 7 and date.day == 4 and date.hour == 0 and date.min == 0 and date.sec == 0);

    // 9. Convert 2,455,323.0 to its corresponding calendar date. (2010-05-06 at noon UT)
    date = AstroDate.fromJD(2_455_323.0);
    try expect(date.year == 2010 and date.month == 5 and date.day == 6 and date.hour == 12 and date.min == 0 and date.sec == 0);

    // 10. Convert 2,456,019.37 to its corresponding calendar date. (2012-04-01 at 20:52:48 UT)
    date = AstroDate.fromJD(2_456_019.37);
    try expect(date.year == 2012 and date.month == 4 and date.day == 1 and date.hour == 20 and date.min == 52 and date.sec == 48);

    // 11. On what day of the week did 7/4/1776 fall? (Thursday)
    date = AstroDate{ .year = 1776, .month = 7, .day = 4 };
    var dow = AstroDate.dayOfWeek(date);
    try expect(dow == 4);

    // 12. On what day of the week did 9/11/2011 fall? (Sunday)
    date = AstroDate{ .year = 2011, .month = 9, .day = 11 };
    dow = AstroDate.dayOfWeek(date);
    try expect(dow == 0);

    // 13. How many days into the year was 10/30/2009? (303)
    date = AstroDate{ .year = 2009, .month = 10, .day = 30 };
    const doy = date.daysIntoYear();
    try expect(doy == 303);

    // 14. If the date was 250 days into 1900, what was the date? (September 7, 1900)
    date = ad.dateFromDaysAndYear(250, 1900);
    try expect(date.year == 1900 and date.month == 9 and date.day == 7);

    // 15. Assume that the date is 12/12/2014, and an observer in the EST time zone is at
    // 77° W longitude. Assuming that standard time is in effect and that LCT is 20:00:00,
    // what are the corresponding UT, GST and LST times?
    //
    // UT = 01:00:00 (next day), GST = 06:26:34 (12/13/2014), and LST = 01:18:34 (12/13/2014)
    date = AstroDate{ .year = 2014, .month = 12, .day = 12, .hour = 20, .min = 0, .sec = 0,
                     .tz = ad.tzEST };
    var ut_date = ad.lctToUT(date);
    try expect(ut_date.year == 2014 and ut_date.month == 12 and ut_date.day == 13 and
               ut_date.hour == 1 and ut_date.min == 0 and ut_date.sec == 0);
    var gst_date = ad.utToGST(ut_date);
    try expect(gst_date.year == 2014 and gst_date.month == 12 and gst_date.day == 13 and
               gst_date.hour == 6 and gst_date.min == 26 and gst_date.sec == 34);
    var lst_date = ad.gstToLST(gst_date, -77.0);
    try expect(lst_date.year == 2014 and lst_date.month == 12 and lst_date.day == 13 and
               lst_date.hour == 1 and lst_date.min == 18 and lst_date.sec == 34);

    // 16. Assume that the date is 7/5/2000 for an observer at 60° E longitude
    // and that it is daylight saving time. If LST for the observer is 5:54:20,
    // what are the corresponding GST, UT and LCT times?
    //
    // GST = 01:54:20, UT = 07:00:00 and LCT = 12:00:00
    const tz = TimeZone.init(true, 4, 0); // UTC+4 DST
    lst_date = AstroDate{ .year = 2000, .month = 7, .day = 5, .hour = 5, .min = 54, .sec = 20, .tz = tz };
    gst_date = ad.lstToGST(lst_date, 60.0);
    try expect(gst_date.year == 2000 and gst_date.month == 7 and gst_date.day == 5 and
               gst_date.hour == 1 and gst_date.min == 54 and gst_date.sec == 20);
    ut_date = ad.gstToUT(gst_date);
    try expect(ut_date.year == 2000 and ut_date.month == 7 and ut_date.day == 5 and
               ut_date.hour == 7 and ut_date.min == 0 and ut_date.sec == 0);
    date = ad.utToLCT(ut_date, tz);
    try expect(date.year == 2000 and date.month == 7 and date.day == 5 and
               date.hour == 12 and date.min == 0 and date.sec == 0);
}

// Chapter 5 - Stars in the Nighttime sky
test "Chapter 5" {
    // 1. An observer is located at latitude 45° N, logitude 100° W in the Pacific
    // Standard Time zone. Assuming the LCT is 09:00:00 on December 1, 2015 and
    // the observer is not on daylight saving time, calculate the horizon coordinates
    // for a star at right ascencion 06:00:00, declination -60°00'00".
    //
    // h = -59°41'58", A = 224°15'27".
    var loc = GeoCoord.init(Angle.fromDMS(DMS{.sign='+',.deg=45,.min=0,.sec=0}),
                                      Angle.fromDMS(DMS{.sign='-',.deg=100,.min=0,.sec=0}));
    var date = AstroDate{.year=2015, .month=12, .day=1, .hour=9, .min=0, .sec=0, .tz=ad.tzPST};
    var date_lst = ad.lctToLST(date, loc.lon);
    var lst = Angle.fromHours(ad.hmsToDec(date_lst.hour,date_lst.min, date_lst.sec));

    var obj_equ = RaDec.init(Angle.fromHMS(HMS{.sign='+',.hour=6,.min=0,.sec=0}),
                                   Angle.fromDMS(DMS{.sign='-',.deg=60,.min=0,.sec=0}));

    var obj_hor = obj_equ.toHor(loc.lat, lst);

    const alt_str = obj_hor.alt.toDMSString(allocator) catch unreachable;
    const az_str = obj_hor.az.toDMSString(allocator) catch unreachable;
    // print("h={s}, A={s}\n", .{alt_str, az_str});

    try expect(std.mem.eql(u8, alt_str, "-59°41'57\""));
    try expect(std.mem.eql(u8, az_str, "224°15'27\""));

    allocator.free(alt_str);
    allocator.free(az_str);

    // 2. An observer is located at latitude 38.25° N, longitude 78.3° W in the Eastern
    // Standard Time zone. At 21:00:00 LCT on June 6, 2015, the observer located
    // an object at altitude 45°00'00", azimuth 90°00'00". Assuming this is daylight
    // saving time, what are the objects equatorial coordinates?
    //
    //   ra = 16h14m42s, dec=25°57'41"
    loc = GeoCoord.init(Angle.fromDegrees(38.25), Angle.fromDegrees(-78.3));
    date = AstroDate{.year=2015, .month=6, .day=6, .hour=21, .min=0, .sec=0, .tz=ad.tzEDT};
    date_lst = ad.lctToLST(date, loc.lon);
    lst = Angle.fromHours(ad.hmsToDec(date_lst.hour,date_lst.min, date_lst.sec));

    obj_hor = HorCoord.init(Angle.fromDegrees(90), Angle.fromDegrees(45));
    obj_equ = obj_hor.toRaDec(loc.lat, lst);

    const ra_str = try obj_equ.ra.toHMSString(allocator);
    const dec_str = try obj_equ.dec.toDMSString(allocator);
    // print("ra = {s}, dec = {s}\n", .{ra_str, dec_str});

    try expect(std.mem.eql(u8, ra_str, "16ʰ14ᵐ42ˢ"));
    try expect(std.mem.eql(u8, dec_str, "25°57'41\""));

    allocator.free(ra_str);
    allocator.free(dec_str);

    // 3. What are the rising and setting times for the star from problem number 1?
    //
    // Star doesn't rise or set for the observer
    loc = GeoCoord.init(Angle.fromDMS(DMS{.sign='+',.deg=45,.min=0,.sec=0}),
                                      Angle.fromDMS(DMS{.sign='-',.deg=100,.min=0,.sec=0}));
    date = AstroDate{.year=2015, .month=12, .day=1, .hour=9, .min=0, .sec=0, .tz=ad.tzPST};
    obj_equ = RaDec.init(Angle.fromHMS(HMS{.sign='+',.hour=6,.min=0,.sec=0}),
                                   Angle.fromDMS(DMS{.sign='-',.deg=60,.min=0,.sec=0}));
   
    _ = crd.riseAndSet(loc, date, obj_equ) catch |err| {
        try expect(err == CoordError.ObjNeverRises);
        // print("Error: {}", .{err});
   };

    // 4. What are the rising and setting times for the star from problem number 2?
    //
    // LCTr = 16ʰ57ᵐ49ˢ,  LCTs = 7ʰ59ᵐ51ˢ 
    loc = GeoCoord.init(Angle.fromDegrees(38.25), Angle.fromDegrees(-78.3));
    date = AstroDate{.year=2015, .month=6, .day=6, .hour=21, .min=0, .sec=0, .tz=ad.tzEDT};
    obj_equ = RaDec.init(Angle.fromHMS(HMS{.sign='+',.hour=16,.min=14,.sec=42}),
                                   Angle.fromDMS(DMS{.sign='+',.deg=25,.min=57,.sec=41}));

    const ras = crd.riseAndSet(loc, date, obj_equ) catch |err| {
        print("Error: {}", .{err});
        return err;
    };

    const rise_str = try ras.rise_time.toTimeString(allocator);
    const set_str = try ras.set_time.toTimeString(allocator);

    // print("LCTr = {s}\n", .{rise_str});
    // print("LCTs = {s}\n", .{set_str});

    try expect(std.mem.eql(u8, rise_str, "16:57:49"));
    try expect(std.mem.eql(u8, set_str,  "07:59:51"));

    allocator.free(rise_str);
    allocator.free(set_str);
}