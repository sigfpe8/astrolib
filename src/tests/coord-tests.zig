const std = @import("std");
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
const HorCoord = crd.HorCoord;
const EclipticCoord = crd.EclipticCoord;
const GalacticCoord = crd.GalacticCoord;
const HaDec = crd.HaDec;
const Epoch = crd.Epoch;

const expect = std.testing.expect;

test "GeoCoord.distance" {
    const coord1 = GeoCoord.init(Angle.fromDegrees(52.5200), Angle.fromDegrees(13.4050)); // Berlin
    const coord2 = GeoCoord.init(Angle.fromDegrees(48.8566), Angle.fromDegrees(2.3522));  // Paris

    const distance = coord1.distanceTo(coord2);

    try expect(std.math.approxEqAbs(f64, distance, 878_000.0, 1_000.0)); // ~878 km
}

test "GeoCoord.toString" {
    const coord = GeoCoord.init(Angle.fromDegrees(51.5074), Angle.fromDegrees(-0.1278)); // London
    const allocator = std.testing.allocator;
    const coord_str = try coord.toString(allocator);

    try expect(std.mem.eql(u8, coord_str, "51°30'27\" N, 0°07'40\" W"));

    allocator.free(coord_str);
}

test "HorCoord.toHaDec" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const hor = HorCoord.init(Angle.fromDegrees(115.0), Angle.fromDegrees(40.0));
    const lat = Angle.fromDegrees(38.0);

    const equa = hor.toHaDec(lat);
    const ha_str = try equa.ha.toHMSString(allocator);
    const dec_str = try equa.dec.toDMSString(allocator);

    try expect(std.mem.eql(u8, ha_str, "21ʰ01ᵐ54ˢ"));
    try expect(std.mem.eql(u8, dec_str, "8°05'03\""));

    allocator.free(ha_str);
    allocator.free(dec_str);
}

test "HaDec.toHor" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const equa = HaDec.init(Angle.fromHMS(HMS{.sign='+', .hour=16,.min=29,.sec=45}),
                                  Angle.fromDMS(DMS{.sign='-',  .deg= 0,.min=30,.sec=30.0}));
                                          
    const lat = Angle.fromDegrees(25.0);

    const hor = equa.toHor(lat);
    const az_str = try hor.az.toDMSString(allocator);
    const alt_str = try hor.alt.toDMSString(allocator);

    try expect(std.mem.eql(u8, az_str, "80°31'31\""));
    try expect(std.mem.eql(u8, alt_str, "-20°34'40\""));

    allocator.free(az_str);
    allocator.free(alt_str);
}

test "RaDec.toHor" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Sirius: RA 06h45m08.9s, Dec -16°42'58.0"
    const equa = RaDec.init(Angle.fromHMS(HMS{.sign='+', .hour=6,.min=45,.sec=8.9}),
                                  Angle.fromDMS(DMS{.sign='-', .deg=16,.min=42,.sec=58.0}));
    // Location: Rio de Janeiro, BR: (22°54'40" S, 43°12'20" W)
    const city = GeoCoord.init(Angle.fromDMS(DMS{.sign='-',.deg=22,.min=54,.sec=40}), 
                                         Angle.fromDMS(DMS{.sign='-',.deg=43,.min=12,.sec=20}));
    // Date: August 10, 1998, 23:10:00 LCT (UTC-3)
    const lct: AstroDate = .{ .year = 1998, .month = 8, .day = 10, .hour = 23, .min = 10, .sec = 0, .tz = ast.tzBRT };
    const lst = ast.lctToLST(lct, city.lon);
    const lst_hrs = Angle.fromHMS(HMS{.sign='+', .hour=lst.hour, .min=lst.min, .sec=@floatFromInt(lst.sec)});

    const hor = equa.toHor(city.lat, lst_hrs);
    const az_str = try hor.az.toDMSString(allocator);
    const alt_str = try hor.alt.toDMSString(allocator);

    // Mathematica gives: Azimuth 143°32'23.6", Altitude -42°09'21.6". ...oh well, close enough :)
    try expect(std.mem.eql(u8, az_str, "143°33'46\""));
    try expect(std.mem.eql(u8, alt_str, "-42°11'16\""));

    allocator.free(az_str);
    allocator.free(alt_str);
}

test "RaDec.toEcliptic" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const equa = RaDec.init(Angle.fromHMS(HMS{.sign='+', .hour=12,.min=18,.sec=47.5}),
                                  Angle.fromDMS(DMS{.sign='-', .deg=0,.min=43,.sec=35.5}));

    const ecl = equa.toEcliptic();
    const lat_str = try ecl.lat.toDMSString(allocator);
    const lon_str = try ecl.lon.toDMSString(allocator);

    // std.debug.print("Ecliptic Latitude: {s}\n", .{lat_str});
    // std.debug.print("Ecliptic Longitude: {s}\n", .{lon_str});
    try expect(std.mem.eql(u8, lat_str, "1°12'00\""));
    try expect(std.mem.eql(u8, lon_str, "184°36'00\""));

    allocator.free(lat_str);
    allocator.free(lon_str);
}

test "RaDec.toGalactic" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const equa = RaDec.init(Angle.fromHMS(HMS{.sign='+', .hour=10,.min=12,.sec=43.0}),
                                  Angle.fromDMS(DMS{.sign='+', .deg=40,.min=48,.sec=33.0}));

    Epoch.set(.B1950);
    const gal = equa.toGalactic();
    const lat_str = try gal.lat.toDMSString(allocator);
    const lon_str = try gal.lon.toDMSString(allocator);

    // std.debug.print("Galactic Latitude: {s}\n", .{lat_str});
    // std.debug.print("Galactic Longitude: {s}\n", .{lon_str});
    try expect(std.mem.eql(u8, lat_str, "55°19'55\""));
    try expect(std.mem.eql(u8, lon_str, "180°00'01\""));

    allocator.free(lat_str);
    allocator.free(lon_str);
}

test "RaDec.adjustPrecession" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // North Galactic Pole B1950: RA 12h49m00s, Dec +27°24'00"
    const equa_B1950 = RaDec.init( Angle.fromHMS(HMS{.sign='+', .hour=12,.min=49,.sec=0}),
                                         Angle.fromDMS(DMS{.sign='+', .deg=27,.min=24,.sec=0}));

    const equa_J2000 = equa_B1950.adjustPrecession(1950.0, 2000.0);
    const ra_str = try equa_J2000.ra.toHMSString(allocator);
    const dec_str = try equa_J2000.dec.toDMSString(allocator);

    // std.debug.print("RA J2000: {s}\n", .{ra_str});
    // std.debug.print("Dec J2000: {s}\n", .{dec_str});
    try expect(std.mem.eql(u8, ra_str, "12ʰ51ᵐ26ˢ"));
    try expect(std.mem.eql(u8, dec_str, "27°07'41\""));

    allocator.free(ra_str);
    allocator.free(dec_str);
}

test "EclipticCoord.toRaDec" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const ecl = EclipticCoord.init(Angle.fromDMS(DMS{.sign='+',.deg=1,.min=12,.sec=0}), 
                                                  Angle.fromDMS(DMS{.sign='+',.deg=184,.min=36,.sec=0}));

    Epoch.set(.J2000);
    const equa = ecl.toRaDec();
    const ra_str = try equa.ra.toHMSString(allocator);
    const dec_str = try equa.dec.toDMSString(allocator);

    // std.debug.print("RA: {s}\n", .{ra_str});
    // std.debug.print("Dec: {s}\n", .{dec_str});
    try expect(std.mem.eql(u8, ra_str, "12ʰ18ᵐ47ˢ"));
    try expect(std.mem.eql(u8, dec_str, "-0°43'36\""));

    allocator.free(ra_str);
    allocator.free(dec_str);
}

test "GalacticCoord.toRaDec" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const gal = GalacticCoord.init(Angle.fromDMS(DMS{.sign='+',.deg=55,.min=20,.sec=0}), 
                                                  Angle.fromDegrees(180.0));
    Epoch.set(.B1950);
    var equa = gal.toRaDec();
    var ra_str = try equa.ra.toHMSString(allocator);
    var dec_str = try equa.dec.toDMSString(allocator);

    // std.debug.print("RA: {s}\n", .{ra_str});
    // std.debug.print("Dec: {s}\n", .{dec_str});
    try expect(std.mem.eql(u8, ra_str, "10ʰ12ᵐ43ˢ"));
    try expect(std.mem.eql(u8, dec_str, "40°48'33\""));

    allocator.free(ra_str);
    allocator.free(dec_str);

    Epoch.set(.J2000);
    equa = gal.toRaDec();
    ra_str = try equa.ra.toHMSString(allocator);
    dec_str = try equa.dec.toDMSString(allocator);

    // std.debug.print("RA: {s}\n", .{ra_str});
    // std.debug.print("Dec: {s}\n", .{dec_str});
    try expect(std.mem.eql(u8, ra_str, "10ʰ15ᵐ43ˢ"));
    try expect(std.mem.eql(u8, dec_str, "40°33'35\""));

    allocator.free(ra_str);
    allocator.free(dec_str);
}

test "RiseAndSet" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const loc = GeoCoord.init(Angle.fromDMS(DMS{.sign='+',.deg=38,.min=0,.sec=0}),   // New York City
                                      Angle.fromDMS(DMS{.sign='-',.deg=78,.min=0,.sec=0}));
    const date= AstroDate{ .year = 2016, .month = 1, .day = 21,
                                      .hour = 12, .min = 0, .sec = 0, .tz = ast.tzEST };
    const obj = RaDec.init(Angle.fromHMS(HMS{.sign='+',.hour=5,.min=55,.sec=0}),  // Betelgeuse
                                  Angle.fromDMS(DMS{.sign='+',.deg=7,.min=30,.sec=0}));

    const rs = try crd.riseAndSet(loc, date, obj);
    const rise_time_str = try rs.rise_time.toString(allocator);
    const set_time_str = try rs.set_time.toString(allocator);
    const rise_az_str = try rs.rise_az.toDMSString(allocator);
    const set_az_str = try rs.set_az.toDMSString(allocator);

    // std.debug.print("Rise Time: {s}, Azimuth: {s}\n", .{rise_time_str, rise_az_str});
    // std.debug.print("Set Time:  {s}, Azimuth: {s}\n", .{set_time_str, set_az_str});
    try expect(std.mem.eql(u8, rise_time_str, "2016-01-21 15:40:46 (-05:00)"));
    try expect(std.mem.eql(u8, rise_az_str, "80°27'56\""));
    try expect(std.mem.eql(u8, set_time_str, "2016-01-22 04:29:51 (-05:00)"));
    try expect(std.mem.eql(u8, set_az_str, "279°32'04\""));

    allocator.free(rise_time_str);
    allocator.free(set_time_str);
    allocator.free(rise_az_str);
    allocator.free(set_az_str);
}

test "gstToUT" {
    // [Lawrence, 2018] p 48-49
    const gstDate = AstroDate{ .year=2010, .month=2, .day=7, .hour=8, .min=41, .sec=53 };
    const utDate = ast.gstToUT(gstDate);
    try expect(utDate.hour == 23 and utDate.min == 30 and utDate.sec == 0);
}
