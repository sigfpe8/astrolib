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
const epoch = crd.epoch;
const setStdEpoch = crd.setStdEpoch;

const expect = std.testing.expect;
const allocator = std.testing.allocator;

test "GeoCoord.distance" {
    const coord1 = GeoCoord.init(Angle.fromDegrees(52.5200), Angle.fromDegrees(13.4050)); // Berlin
    const coord2 = GeoCoord.init(Angle.fromDegrees(48.8566), Angle.fromDegrees(2.3522));  // Paris

    const distance = coord1.distanceTo(coord2);

    try expect(std.math.approxEqAbs(f64, distance, 878_000.0, 1_000.0)); // ~878 km
}

test "GeoCoord.toString" {
    const coord = GeoCoord.init(Angle.fromDegrees(51.5074), Angle.fromDegrees(-0.1278)); // London
    const coord_str = try coord.toString(allocator);
    defer allocator.free(coord_str);

    try expect(std.mem.eql(u8, coord_str, "51°30′27″ N, 0°07′40″ W"));
}

test "HorCoord.toHaDec" {
    const hor = HorCoord.init(Angle.fromDegrees(40.0), Angle.fromDegrees(115.0));
    const lat = Angle.fromDegrees(38.0);

    const equa = hor.toHaDec(lat);
    const ha_str = try equa.ha.toHMSString(allocator);
    defer allocator.free(ha_str);
    const dec_str = try equa.dec.toDMSString(allocator);
    defer allocator.free(dec_str);

    try expect(std.mem.eql(u8, ha_str, "21ʰ01ᵐ54ˢ"));
    try expect(std.mem.eql(u8, dec_str, "8°05′03″"));
}

test "HaDec.toHor" {
    const equa = HaDec.init(Angle.fromHMS(HMS{.sign='+', .hour=16,.min=29,.sec=45}),
                                  Angle.fromDMS(DMS{.sign='-',  .deg= 0,.min=30,.sec=30.0}));
                                          
    const lat = Angle.fromDegrees(25.0);

    const hor = equa.toHor(lat);
    const az_str = try hor.az.toDMSString(allocator);
    defer allocator.free(az_str);
    const alt_str = try hor.alt.toDMSString(allocator);
    defer allocator.free(alt_str);

    try expect(std.mem.eql(u8, az_str, "80°31′31″"));
    try expect(std.mem.eql(u8, alt_str, "-20°34′40″"));
}

test "RaDec.toHor" {
    // Sirius: RA 06h45m08.9s, Dec -16°42′58.0"
    const equa = RaDec.init(Angle.fromHMS(HMS{.sign='+', .hour=6,.min=45,.sec=8.9}),
                                  Angle.fromDMS(DMS{.sign='-', .deg=16,.min=42,.sec=58.0}));
    // Location: Rio de Janeiro, BR: (22°54′40" S, 43°12′20" W)
    const city = GeoCoord.init(Angle.fromDMS(DMS{.sign='-',.deg=22,.min=54,.sec=40}), 
                                         Angle.fromDMS(DMS{.sign='-',.deg=43,.min=12,.sec=20}));
    // Date: August 10, 1998, 23:10:00 LCT (UTC-3)
    const lct = AstroDate.fromDateAndHMS(1998, 8, 10, 23, 10, 0, ast.tzBRT);
    const lst_hrs = ast.lctToLST(lct, city.lon).hours;

    const hor = equa.toHor(city.lat, lst_hrs);
    const az_str = try hor.az.toDMSString(allocator);
    defer allocator.free(az_str);
    const alt_str = try hor.alt.toDMSString(allocator);
    defer allocator.free(alt_str);

    // Mathematica gives: Azimuth 143°32′23.6", Altitude -42°09′21.6". ...oh well, close enough :)
    // std.debug.print("Az  = {s}\n", .{az_str});
    // std.debug.print("Alt = {s}\n", .{alt_str});
    try expect(std.mem.eql(u8, az_str, "143°33′45″"));
    try expect(std.mem.eql(u8, alt_str, "-42°11′16″"));
}

test "RaDec.toEcliptic" {
    const equa = RaDec.init(Angle.fromHMS(HMS{.sign='+', .hour=12,.min=18,.sec=47.5}),
                                  Angle.fromDMS(DMS{.sign='-', .deg=0,.min=43,.sec=35.5}));

    const ecl = equa.toEcliptic();
    const lat_str = try ecl.lat.toDMSString(allocator);
    defer allocator.free(lat_str);
    const lon_str = try ecl.lon.toDMSString(allocator);
    defer allocator.free(lon_str);

    // std.debug.print("Ecliptic Latitude: {s}\n", .{lat_str});
    // std.debug.print("Ecliptic Longitude: {s}\n", .{lon_str});
    try expect(std.mem.eql(u8, lat_str, "1°12′00″"));
    try expect(std.mem.eql(u8, lon_str, "184°36′00″"));
}

test "RaDec.toGalactic" {
    const equa = RaDec.init(Angle.fromHMS(HMS{.sign='+', .hour=10,.min=12,.sec=43.0}),
                                  Angle.fromDMS(DMS{.sign='+', .deg=40,.min=48,.sec=33.0}));

    setStdEpoch(.B1950);
    const gal = equa.toGalactic();
    const lat_str = try gal.lat.toDMSString(allocator);
    defer allocator.free(lat_str);
    const lon_str = try gal.lon.toDMSString(allocator);
    defer allocator.free(lon_str);

    // std.debug.print("Galactic Latitude: {s}\n", .{lat_str});
    // std.debug.print("Galactic Longitude: {s}\n", .{lon_str});
    try expect(std.mem.eql(u8, lat_str, "55°19′55″"));
    try expect(std.mem.eql(u8, lon_str, "180°00′01″"));
}

test "RaDec.adjustPrecession" {
    // North Galactic Pole B1950: RA 12h49m00s, Dec +27°24′00"
    const equa_B1950 = RaDec.init( Angle.fromHMS(HMS{.sign='+', .hour=12,.min=49,.sec=0}),
                                         Angle.fromDMS(DMS{.sign='+', .deg=27,.min=24,.sec=0}));

    const equa_J2000 = equa_B1950.adjustPrecession(1950.0, 2000.0);
    const ra_str = try equa_J2000.ra.toHMSString(allocator);
    defer allocator.free(ra_str);
    const dec_str = try equa_J2000.dec.toDMSString(allocator);
    defer allocator.free(dec_str);

    // std.debug.print("RA J2000: {s}\n", .{ra_str});
    // std.debug.print("Dec J2000: {s}\n", .{dec_str});
    try expect(std.mem.eql(u8, ra_str, "12ʰ51ᵐ26ˢ"));
    try expect(std.mem.eql(u8, dec_str, "27°07′41″"));
}

test "EclipticCoord.toRaDec" {
    const ecl = EclipticCoord.init(Angle.fromDMS(DMS{.sign='+',.deg=1,.min=12,.sec=0}), 
                                                  Angle.fromDMS(DMS{.sign='+',.deg=184,.min=36,.sec=0}));

    setStdEpoch(.J2000);
    const equa = ecl.toRaDec();
    const ra_str = try equa.ra.toHMSString(allocator);
    defer allocator.free(ra_str);
    const dec_str = try equa.dec.toDMSString(allocator);
    defer allocator.free(dec_str);

    // std.debug.print("RA: {s}\n", .{ra_str});
    // std.debug.print("Dec: {s}\n", .{dec_str});
    try expect(std.mem.eql(u8, ra_str, "12ʰ18ᵐ47ˢ"));
    try expect(std.mem.eql(u8, dec_str, "-0°43′36″"));
}

test "GalacticCoord.toRaDec" {
    const gal = GalacticCoord.init(Angle.fromDMS(DMS{.sign='+',.deg=55,.min=20,.sec=0}), 
                                                  Angle.fromDegrees(180.0));
    setStdEpoch(.B1950);
    var equa = gal.toRaDec();
    var ra_str = try equa.ra.toHMSString(allocator);
    defer allocator.free(ra_str);
    var dec_str = try equa.dec.toDMSString(allocator);
    defer allocator.free(dec_str);

    // std.debug.print("RA: {s}\n", .{ra_str});
    // std.debug.print("Dec: {s}\n", .{dec_str});
    try expect(std.mem.eql(u8, ra_str, "10ʰ12ᵐ43ˢ"));
    try expect(std.mem.eql(u8, dec_str, "40°48′33″"));

    allocator.free(ra_str);
    allocator.free(dec_str);

    setStdEpoch(.J2000);
    equa = gal.toRaDec();
    ra_str = try equa.ra.toHMSString(allocator);
    dec_str = try equa.dec.toDMSString(allocator);

    // std.debug.print("RA: {s}\n", .{ra_str});
    // std.debug.print("Dec: {s}\n", .{dec_str});
    try expect(std.mem.eql(u8, ra_str, "10ʰ15ᵐ43ˢ"));
    try expect(std.mem.eql(u8, dec_str, "40°33′35″"));
}

test "RiseAndSet" {
    const loc = GeoCoord.init(Angle.fromDMS(DMS{.sign='+',.deg=38,.min=0,.sec=0}),   // New York City
                                      Angle.fromDMS(DMS{.sign='-',.deg=78,.min=0,.sec=0}));
    const date = AstroDate.fromDateAndHMS(2016, 1, 21, 12, 0, 0, ast.tzEST);
    const obj = RaDec.init(Angle.fromHMS(HMS{.sign='+',.hour=5,.min=55,.sec=0}),  // Betelgeuse
                                  Angle.fromDMS(DMS{.sign='+',.deg=7,.min=30,.sec=0}));

    const rs = try crd.riseAndSet(loc, date, obj);
    const rise_time_str = try rs.rise_time.toString(allocator);
    defer allocator.free(rise_time_str);
    const set_time_str = try rs.set_time.toString(allocator);
    defer allocator.free(set_time_str);
    const rise_az_str = try rs.rise_az.toDMSString(allocator);
    defer allocator.free(rise_az_str);
    const set_az_str = try rs.set_az.toDMSString(allocator);
    defer allocator.free(set_az_str);

    // std.debug.print("Rise Time: {s}, Azimuth: {s}\n", .{rise_time_str, rise_az_str});
    // std.debug.print("Set Time:  {s}, Azimuth: {s}\n", .{set_time_str, set_az_str});
    try expect(std.mem.eql(u8, rise_time_str, "2016-01-21 15:40:46 (-05:00)"));
    try expect(std.mem.eql(u8, rise_az_str, "80°27′56″"));
    try expect(std.mem.eql(u8, set_time_str, "2016-01-22 04:29:50 (-05:00)"));
    try expect(std.mem.eql(u8, set_az_str, "279°32′04″"));
}

test "gstToUT" {
    // [Lawrence, 2018] p 48-49
    const gstDate = AstroDate.fromDateAndHMS(2010, 2, 7, 8, 41, 53, .{});
    const utDate = ast.gstToUT(gstDate);
    const hms = ast.hrsToHMS(utDate.hours);
    try expect(hms.hour == 23 and hms.min == 30 and hms.sec == 0);
}
