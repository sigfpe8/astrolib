const std = @import("std");

const ang = @import("angle.zig");
const Angle = ang.Angle;
const DMS = ang.DMS;
const HMS = ang.HMS;
const deg_to_rad = ang.deg_to_rad;

const ast = @import("astrodate.zig");
const AstroDate = ast.AstroDate;
const TimeZone = ast.TimeZone;
const Year = ast.Year;
const Month = ast.Month;
const Day = ast.Day;

const crd = @import("coord.zig");
const GeoCoord = crd.GeoCoord;
const EclipticCoord = crd.EclipticCoord;
const RaDec = crd.RaDec;
const HorCoord = crd.HorCoord;
const RiseAndSetLCT = crd.RiseAndSetLCT;

const orb = @import("orbits.zig");

// const epoch = crd.epoch;

const pi:     f64 = std.math.pi;
const two_pi: f64 = pi * 2.0;

const Allocator = std.mem.Allocator;

// --------------------------------------------------------------------------
//
// Sun
//
// --------------------------------------------------------------------------

/// Formulas for equinoxes and solstices from [Lawrence, 2018], which are
/// accurate only to about 15-20 minutes.
/// Return the March equinox date for a given year
pub fn marchEquinox(year: Year) AstroDate {
    const y: f64 = @floatFromInt(year);
    const t: f64 = y / 1000.0;
    const t2: f64 = t * t;
    const t3: f64 = t2 * t;

    const jd = 1_721_139.285_5 + 365.242_137_6 * y + 0.067_919_0 * t2 - 0.002_787_9 * t3;
    return AstroDate.fromJD(jd);
}

/// Return the June solstice date for a given year
pub fn juneSolstice(year: Year) AstroDate {
    const y: f64 = @floatFromInt(year);
    const t: f64 = y / 1000.0;
    const t2: f64 = t * t;
    const t3: f64 = t2 * t;

    const jd = 1_721_233.248_6 + 365.241_728_4 * y - 0.053_018_0 * t2 + 0.009_332_0 * t3;
    return AstroDate.fromJD(jd);
}

/// Return the September equinox date for a given year
pub fn septemberEquinox(year: Year) AstroDate {
    const y: f64 = @floatFromInt(year);
    const t: f64 = y / 1000.0;
    const t2: f64 = t * t;
    const t3: f64 = t2 * t;

    const jd = 1_721_325.697_8 + 365.242_505_5 * y - 0.126_689_0 * t2 + 0.001_940_1 * t3;
    return AstroDate.fromJD(jd);
}

/// Return the December solstice date for a given year
pub fn decemberSolstice(year: Year) AstroDate {
    const y: f64 = @floatFromInt(year);
    const t: f64 = y / 1000.0;
    const t2: f64 = t * t;
    const t3: f64 = t2 * t;

    const jd = 1_721_414.392_0 + 365.242_889_8 * y - 0.010_965_0 * t2 - 0.008_488_5 * t3;
    return AstroDate.fromJD(jd);
}

/// Return the Sun's horizontal coordinates for a given date (LCT) and location
pub fn sunHorCoord(date: AstroDate, loc: GeoCoord) HorCoord {
    const lst_hrs = ast.lctToLST(date, loc.lon).hours;
    const eq = sunRaDec(date);
    return eq.toHor(loc.lat, lst_hrs);
}

/// Return the Sun's equatorial coordinates for a given date (LCT)
pub fn sunRaDec(date: AstroDate) RaDec {
    return sunEclipticCoord(date).toRaDec();
}

/// Return the Sun's ecliptic coordinates for a given date (LCT)
pub fn sunEclipticCoord(date: AstroDate) EclipticCoord {
    const e = crd.epoch.ecc;

    // Mean anomaly
    const M = sunMeanAnomaly(date);
    
    // Equation of the center
    // const Ec = Angle.fromRadians(2 * e * M.sin()).asDegrees();
    // True anomaly
    // const v = Angle.fromDegrees(M.deg + Ec.deg).reduce360();

    // Find true anomaly by solving Kepler's equation
    const v = orb.trueAnomalyFromKeplerTan(e, M);

    // Ecliptic longitude    (λ = ν + ϖ)
    const lon = Angle.fromDegrees(v.toDegrees() + crd.epoch.sun_elong.toDegrees()).reduce360();
    // Ecliptic coordinates
    return EclipticCoord.init(Angle.fromDegrees(0), lon);
}

/// Return the Sun's mean anomaly for a given date (LCT)
pub fn sunMeanAnomaly(date: AstroDate) Angle {
    const De = ast.daysFromEpoch(date);

    return Angle.fromDegrees((360.0 * De) / 365.242_191 + 
                                crd.epoch.sun_elon.toDegrees() -
                                crd.epoch.sun_elong.toDegrees()).reduce360();
}

/// Return approximate local time for sunrise and sunset (Lawrence, 2018)
pub fn sunRiseAndSet(loc: GeoCoord, date: AstroDate) !RiseAndSetLCT {
    const ec1 = sunEclipticCoord(date.midnight());
    const lon1 = ec1.lon.toDegrees();
    const equ1 = ec1.toRaDec();
    const lst1 = crd.riseAndSetLST(loc, equ1) catch unreachable;
    const rise_lst1 = lst1.rise_lst;
    const set_lst1 = lst1.set_lst;

    var lon2 = lon1 + 0.985_647;
    if (lon2 > 360) {
        lon2 -= 360;
    }
    const ec2 = EclipticCoord.init(Angle.fromDegrees(0), Angle.fromDegrees(lon2));
    const equ2 = ec2.toRaDec();
    const lst2 = crd.riseAndSetLST(loc, equ2) catch unreachable;
    const rise_lst2 = lst2.rise_lst;
    const set_lst2 = lst2.set_lst;

    const tr = (24.07 * rise_lst1) / (24.07 + rise_lst1 - rise_lst2);
    const ts = (24.07 * set_lst1) / (24.07 + set_lst1 - set_lst2);

    const rise_lst = AstroDate.fromDateAndHours(date.year, date.month, date.day, tr, date.tz);
    const set_lst = AstroDate.fromDateAndHours(date.year, date.month, date.day, ts, date.tz);
    const lctr = ast.lstToLCT(rise_lst, loc.lon, date.tz);
    const lcts = ast.lstToLCT(set_lst, loc.lon, date.tz);

    return RiseAndSetLCT{
        .rise_lct = lctr,
        .set_lct  = lcts,
    };
}

/// Return approximate local time for sunrise and sunset
/// Wikipedia - Sunrise equation
pub fn sunRiseAndSet2(loc: GeoCoord, date: AstroDate) !RiseAndSetLCT {
    const J = date.midnight().toJD();
    // n = number of days since Jan 1st, 2000 12:00
    const n = std.math.ceil(J - 2_451_545.0 + 0.000_8);
    // Mean solar time
    const Js = n - (loc.lon.toDegrees() / 360);
    // Mean solar anomaly
    // const M = @mod((357.529_1 + 0.985_600_28 * Js), 360.0);
    const M = @mod(357.529_1 + 0.985_600_28 * Js, 360.0);
    const mr = M * pi / 180.0;      // Radians
    // Equation of the center
    const C = 1.914_8 * @sin(mr) + 0.020_0 * @sin(2 * mr) + 0.000_3 * @sin(3 * mr);
    // Ecliptic longitude
    const lon = @mod(M + C + 180 + 102.937_2, 360.0);
    const lor = lon * pi / 180.0;   // Radians
    // Solar transit
    const Jt =  2_451_545.0 + Js + 0.005_3 * @sin(mr) - 0.006_9 * @sin(2 * lor);
    // Declination of the Sun [-90, 90]
    const sin_dec = @sin(lor) * @sin(23.439_8 * pi / 180.0);            // [-1, 1]
    const cos_dec = std.math.sqrt(1.0 - sin_dec * sin_dec);    // [0, 1]
    // Hour angle
    const cos_w0 = (@sin(-0.833 * pi / 180) - @sin(loc.lat.toRadians()) * sin_dec) /
                   (@cos(loc.lat.toRadians()) * cos_dec);
    // const w0 = std.math.acos(cos_w0) * 180 / pi;
    // const w = w0 / 360.0;
    const w = std.math.acos(cos_w0) / two_pi;

    const lctr = AstroDate.fromJD(Jt - w);
    const lcts = AstroDate.fromJD(Jt + w);

    return RiseAndSetLCT{
        .rise_lct = ast.utToLCT(lctr, date.tz),
        .set_lct  = ast.utToLCT(lcts, date.tz),
    };
}

/// Print to stdout a sideways graph of the equation of time for a given year
pub fn equationOfTime(allocator: std.mem.Allocator, year: Year, interval: u32) !void {
    // Get stdout
    const BUFFER_SIZE = 2048;
    const buffer = try allocator.alloc(u8, BUFFER_SIZE);
    defer allocator.free(buffer);
    var writer = std.fs.File.stdout().writer(buffer);
    var stdout = &writer.interface;

    //     -20     0     20
    // "ddd |  ... | ... |"
    const lineSize = 4 + 1 + 20 + 1 + 20 + 1;
    var line = [_]u8 { ' ' } ** lineSize;
    const delta_days = @min(@max(interval,1),30);   // [1,30]
    var days: u32 = 1;

    try stdout.print("\nDay | Equation of time (ΔT in min) for the year {d}\n\n", .{year});
    try stdout.print("   -20                   0                   20\n", .{});

    while (days < 366) : (days += delta_days) {
        const date = AstroDate.fromYearAndDays(year, days);
        const mins = deltaT(date);
        var y: i32 = @as(i32,@intFromFloat(@round(mins))) + 20;
        y = @min(@max(y,0),40); // [0,40]
        const x: usize = @as(usize,@intCast(y));
        _ = try std.fmt.bufPrint(
                &line,
                "{d:3} |                    |                    |",
                .{days});
        line[5+x] = '.';
        try stdout.print("{s}\n", .{line});
    }

    try stdout.flush();
}

/// Return the equation of time (ΔT in minutes) for a given date
pub fn deltaT(date: AstroDate) f64 {
    const noon = date.noon();
    const eq = sunRaDec(noon);
    const gst = AstroDate.fromDateAndHours(date.year, date.month, date.day, eq.ra.toHours(), .{});
    const ut = ast.gstToUT(gst);
    const mins = (ut.hours - 12) * 60;
    return mins;
}

// --------------------------------------------------------------------------
//
// Moon
//
// --------------------------------------------------------------------------

/// Return the Moon's horizontal coordinates for a given date (LCT) and location
pub fn moonHorCoord(date: AstroDate, loc: GeoCoord) HorCoord {
    const lst_hrs = ast.lctToLST(date, loc.lon).hours;
    const eq = moonRaDec(date);
    return eq.toHor(loc.lat, lst_hrs);
}

/// Return the Moon's equatorial coordinates for a given date (LCT)
pub fn moonRaDec(date: AstroDate) RaDec {
    return moonEclipticCoord(date).toRaDec();
}

/// Return the Moon's mean anomaly for a given date (LCT)
pub fn moonMeanAnomaly(date: AstroDate) Angle {
    const De = ast.daysFromEpochTT(date);

    // Moon's uncorrected mean longitude (7.3.1)
    var lon = Angle.fromDegrees(13.176_339_686 * De + 218.316_433).reduce360();

    // Moon's uncorrected mean anomaly (7.3.3)
    return Angle.fromDegrees(lon.toDegrees() - 0.111_404_1 * De - 83.353_451).reduce360();
}

/// Return the Moon's ecliptic coordinates for a given date (LCT)
pub fn moonEclipticCoord(date: AstroDate) EclipticCoord {
    // Algorithm by [Lawrence, 2018], p. 165
    const De = ast.daysFromEpochTT(date);

    // Moon's uncorrected mean longitude (7.3.1)
    var lon = Angle.fromDegrees(13.176_339_686 * De + 218.316_433).reduce360();
    // Moon's uncorrected mean longitude of the ascending node
    var node_lon = Angle.fromDegrees(125.044_522 - 0.052_953_9 * De).reduce360();

    // Moon's uncorrected mean anomaly (7.3.3)
    const Mm = Angle.fromDegrees(lon.toDegrees() - 0.111_404_1 * De - 83.353_451).reduce360();

    // Sun's position and Mean anomaly
    const sun = sunEclipticCoord(date);
    const Ms = sunMeanAnomaly(date);

    // Corrections to the Moon's anomaly (all in degrees) (7.3.4 - 7.3.6)
    const Ae = 0.1858 * Ms.sin();
    const Ev = 1.2739 * @sin(2 * (lon.toRadians() - sun.lon.toRadians()) - Mm.toRadians());
    const Ca = Mm.toDegrees() + Ev - Ae - 0.37 * Ms.sin();

    // Moon's true anomaly (7.3.7)
    const vm = 6.2886 * @sin(Ca * pi / 180.0) + 0.214 * @sin(2 * Ca * pi / 180.0);
    lon = Angle.fromDegrees(lon.toDegrees() + Ev + vm - Ae).reduce360();  // λ' (7.3.9)
    // Variation correction (7.3.8)
    const V = 0.6583 * @sin(2 * (lon.toRadians() - sun.lon.toRadians()));

    lon = Angle.fromDegrees(lon.toDegrees() + V).reduce360();   // λt (7.3.10)

    // Corrected longitude of the ascending node (7.3.11)
    node_lon = Angle.fromDegrees(node_lon.toDegrees() - 0.16 * Ms.sin()).reduce360();

    // Moon's ecliptic latitude and longitude (7.3.12-7.3.13)
    const e_rad = 5.145_396_4 * deg_to_rad;
    const sin_e = @sin(e_rad);
    const cos_e = @cos(e_rad);
    const delta_lon = lon.toRadians() - node_lon.toRadians();
    const sin_lon = @sin(delta_lon);
    const y = sin_lon * cos_e;
    const x = @cos(delta_lon);
    const T = Angle.atan2(y, x);

    lon = Angle.fromDegrees(T.toDegrees() + node_lon.toDegrees()).reduce360();
    const lat = Angle.asin(sin_lon * sin_e);

    return EclipticCoord.init(lat, lon);
}

const MoonPhase = struct {
    elong: Angle,       // Elongation angle (D)
    illum: f64,         // Illumination fraction (0..1)
    age_days: f64,      // Age in days since New Moon
    name: []const u8,   // Phase name
};

/// Return the Moon phase information for a given date (LCT)
pub fn moonPhase(date: AstroDate) MoonPhase {
    const Mm = moonMeanAnomaly(date);
    const moon = moonEclipticCoord(date);
    const sun = sunEclipticCoord(date);

    // Elongation angle or age (7.6.5)
    const elong = Angle.acos(@cos(moon.lon.toRadians() - sun.lon.toRadians()) * moon.lat.cos()).reduce360();
    const days = (elong.toDegrees() / 360.0) * 29.530_6;

    // Phase angle (7.6.6)
    const sin_mm = Mm.sin();
    const t1 = (1 - 0.054_9 * sin_mm);
    const t2 = (1 - 0.016_7 * sin_mm);
    const pa = 180 - elong.toDegrees() - 0.146_8 * (t1 / t2) * elong.sin();

    // Illumination fraction (7.6.7)
    const illum = (1 + @cos(pa * pi / 180.0)) * 0.5;
    
    const name = phase_names[@intFromFloat(@trunc((elong.toDegrees() + 22.5) / 45.0))];

    return .{
        .elong = elong,
        .illum = illum,
        .age_days = days,
        .name = name,
    };
}

const phase_names = [_][]const u8{
    "New Moon",
    "Waxing Crescent",
    "First Quarter",
    "Waxing Gibbous",
    "Full Moon",
    "Waning Gibbous",
    "Last Quarter",
    "Waning Crescent",
    "New Moon",
};

// --------------------------------------------------------------------------
//
// Planets
//
// --------------------------------------------------------------------------

/// Solar system bodies, per [Lawrence, 2018]
pub const Body = struct {
    name: []const u8,
    period: f64,                    // In Tropical years
    mass: f64,                      // Relative to the Earth
    radius: f64,                    // In Km (averages of polar and equatorial)
    day: f64,                       // Length relative to Earth (24h)
    eccentricity: f64,              // Orbital eccentricity (ellipses only)
    semi_major_axis_au: f64,        // Semi-major axis in AU
    semi_major_axis_km: f64,        // Semi-major axis in Km
    ang_diam_sec: f64,              // Angular diameter in arc seconds
    ang_diam_deg: f64,              // Angular diameter in degrees
    visual_mag: f64,                // Apparent visual magnitude at 1 AU
    grav_parm: f64,                 // In Km^3/s^2
    inclination: f64,               // Orbit inclination at epoch, in degrees
    lon_at_epoch: f64,              // Longitude at epoch, in degrees
    lon_at_peri: f64,               // Longitude at perihelion at epoch, in degrees
    lon_asc_node: f64,              // Longitude of ascending node, in degrees
};

pub const Sun: usize = 0;
pub const Moon: usize = Sun + 1;
pub const Earth: usize = Moon + 1;
pub const Mercury: usize = Earth + 1;
pub const Venus: usize = Mercury + 1;
pub const Mars: usize = Venus + 1;
pub const Jupiter: usize = Mars + 1;
pub const Saturn: usize = Jupiter + 1;
pub const Uranus: usize = Saturn + 1;
pub const Neptune: usize = Uranus + 1;
pub const Pluto: usize = Neptune + 1;

pub const bodies= [_]Body{
    Body {
        .name = "Sun",
        .period = 0,
        .mass = 333000,
        .radius = 695700,
        .day = 25.449,
        .eccentricity = 0.016708,
        .semi_major_axis_au = 1.0,
        .semi_major_axis_km = 1.495985E08,
        .ang_diam_sec = 1919,
        .ang_diam_deg = 0.533128,
        .visual_mag = -26.74,
        .grav_parm = 1.32712E11,
        .inclination = 0.00005,
        .lon_at_epoch = 280.466069,
        .lon_at_peri = 282.938346,
        .lon_asc_node = 0,
    },
    Body {
        .name = "Moon",
        .period = 0,
        .mass = 0.0123,
        .radius = 1738.1,
        .day = 27.322,
        .eccentricity = 0.0549,
        .semi_major_axis_au = 0.002570,
        .semi_major_axis_km = 384400,
        .ang_diam_sec = 0,
        .ang_diam_deg = 0.5181,
        .visual_mag = -12.74,
        .grav_parm = 4900,
        .inclination = 5.1453964,
        .lon_at_epoch = 218.316433,
        .lon_at_peri = 83.353451,
        .lon_asc_node = 125.044522,
    },
    Body {
        .name = "Earth",
        .period = 1.0000174,
        .mass = 1.0,
        .radius = 6378.14,
        .day = 1.0,
        .eccentricity = 0.01671123,
        .semi_major_axis_au = 1.00000261,
        .semi_major_axis_km = 0,
        .ang_diam_sec = 0,
        .ang_diam_deg = 0,
        .visual_mag = 0,
        .grav_parm = 398600,
        .inclination = -0.00001531,
        .lon_at_epoch = 100.46457166,
        .lon_at_peri = 102.93768193,
        .lon_asc_node = 0,
    },
    Body {
        .name = "Mercury",
        .period = 0.2408467,
        .mass = 0.055274,
        .radius = 2439.7,
        .day = 58.6462,
        .eccentricity = 0.20563593,
        .semi_major_axis_au = 0.38709927,
        .semi_major_axis_km = 0,
        .ang_diam_sec = 6.74,
        .ang_diam_deg = 0,
        .visual_mag = -0.42,
        .grav_parm = 22032,
        .inclination = 7.00497902,
        .lon_at_epoch = 252.25032350,
        .lon_at_peri = 77.45779628,
        .lon_asc_node = 48.33076593,
    },
    Body {
        .name = "Venus",
        .period = 0.61519726,
        .mass = 0.814998,
        .radius = 6051.8,
        .day = 243.018,
        .eccentricity = 0.00677672,
        .semi_major_axis_au = 0.72333566,
        .semi_major_axis_km = 0,
        .ang_diam_sec = 16.92,
        .ang_diam_deg = 0,
        .visual_mag = -4.40,
        .grav_parm = 324860,
        .inclination = 3.39467605,
        .lon_at_epoch = 181.97909950,
        .lon_at_peri = 131.60246718,
        .lon_asc_node = 76.67984255,
    },
    Body {
        .name = "Mars",
        .period = 1.8808476,
        .mass = 0.107447,
        .radius = 3389.5,
        .day = 1.02595676,
        .eccentricity = 0.09339410,
        .semi_major_axis_au = 1.52371034,
        .semi_major_axis_km = 0,
        .ang_diam_sec = 9.36,
        .ang_diam_deg = 0,
        .visual_mag = -1.52,
        .grav_parm = 42828,
        .inclination = 1.84969142,
        .lon_at_epoch = -4.55343205,
        .lon_at_peri = -23.94362959,
        .lon_asc_node = 49.55953891,
    },
    Body {
        .name = "Jupiter",
        .period = 11.862615,
        .mass = 317.828133,
        .radius = 69911,
        .day = 0.41354,
        .eccentricity = 0.0483927,
        .semi_major_axis_au = 5.20288700,
        .semi_major_axis_km = 0,
        .ang_diam_sec = 196.74,
        .ang_diam_deg = 0,
        .visual_mag = -9.40,
        .grav_parm = 126687000,
        .inclination = 1.30439695,
        .lon_at_epoch = 34.39644051,
        .lon_at_peri = 14.72847983,
        .lon_asc_node = 100.47390909,
    },
    Body {
        .name = "Saturn",
        .period = 29.447498,
        .mass = 95.160904,
        .radius = 58232,
        .day = 0.44401,
        .eccentricity = 0.05386179,
        .semi_major_axis_au = 9.53667594,
        .semi_major_axis_km = 0,
        .ang_diam_sec = 165.60,
        .ang_diam_deg = 0,
        .visual_mag = -8.88,
        .grav_parm = 37931000,
        .inclination = 2.48599187,
        .lon_at_epoch = 49.95424423,
        .lon_at_peri = 92.59887831,
        .lon_asc_node = 113.66242448,
    },
    Body {
        .name = "Uranus",
        .period = 84.016846,
        .mass = 14.535757,
        .radius = 25362,
        .day = 0.71833,
        .eccentricity = 0.04725744,
        .semi_major_axis_au = 19.18916464,
        .semi_major_axis_km = 0,
        .ang_diam_sec = 65.80,
        .ang_diam_deg = 0,
        .visual_mag = -7.19,
        .grav_parm = 5794000,
        .inclination = 0.77263783,
        .lon_at_epoch = 313.23810451,
        .lon_at_peri = 170.95427630,
        .lon_asc_node = 74.01692503,
    },
    Body {
        .name = "Neptune",
        .period = 164.79132,
        .mass = 17.147813,
        .radius = 24622,
        .day = 0.67125,
        .eccentricity = 0.00859048,
        .semi_major_axis_au = 30.06992276,
        .semi_major_axis_km = 0,
        .ang_diam_sec = 62.20,
        .ang_diam_deg = 0,
        .visual_mag = -6.87,
        .grav_parm = 6835100,
        .inclination = 1.77004347 ,
        .lon_at_epoch = -55.12002969,
        .lon_at_peri = 44.96476227,
        .lon_asc_node = 131.78422574,
    },
    Body {
        .name = "Pluto",
        .period = 247.92065,
        .mass = 0.0022192,
        .radius = 1151,
        .day = 6.3872,
        .eccentricity = 0.24882730,
        .semi_major_axis_au = 39.48211675,
        .semi_major_axis_km = 0,
        .ang_diam_sec = 8.20,
        .ang_diam_deg = 0,
        .visual_mag = -1.00,
        .grav_parm = 870,
        .inclination = 17.14001206,
        .lon_at_epoch = 238.92903833,
        .lon_at_peri = 224.06891629,
        .lon_asc_node = 110.30393684,
    },
};

/// Heliocentric position of a celestial body for a given date
pub const HelioCoord = struct {
    lat: Angle,      // Heliocentric Ecliptic Latitude [-90°, +90°]  (Λ)
    lon: Angle,      // Heliocentric Ecliptic Longitude [0°, 360°)   (L)
    v: Angle,        // True anomaly
    r: f64,          // Radius vector (AU)

    pub fn fromDate(pb: *const Body, date: AstroDate) HelioCoord {
        const De = ast.daysFromEpoch(date);
        const e = pb.eccentricity;
        // std.debug.print("JD = {d:.3}, De = {d:.3}\n", .{jd, De});

        const M = Angle.fromDegrees((360.0 * De) / (365.242_191 * pb.period) + pb.lon_at_epoch - pb.lon_at_peri).reduce360();
        // std.debug.print("Mp = {d:.6}\n", .{Mp.toDegrees()});

        // Equation of the center (8.6.2)
        const Ec = Angle.fromRadians(2 * e * M.sin()).reduce360();
        // std.debug.print("Ec = {d:.6}\n", .{Ec.toDegrees()});

        // True anomaly (8.6.3)
        const vp = Angle.fromDegrees(M.toDegrees() + Ec.toDegrees()).reduce360();
        // std.debug.print("vp = {d:.6}\n", .{vp.toDegrees()});

        // Heliocentric ecliptic longitude (8.6.4)
        const Lon = Angle.fromDegrees(vp.toDegrees() + pb.lon_at_peri).reduce360();

        // Heliocentric ecliptic latidude (8.6.5)
        const delta_lon = Angle.fromDegrees(Lon.toDegrees() - pb.lon_asc_node); 
        const Lat = Angle.asin(delta_lon.sin() * @sin(pb.inclination * deg_to_rad)).reduce360();
        // std.debug.print("Lop = {d:.6}, Lap = {d:.6}\n", .{Lop.toDegrees(), Lap.toDegrees()});

        // Radius vector (8.6.6)
        const R = (pb.semi_major_axis_au * (1 - e * e)) / (1 + e * vp.cos());

        return .{
            .lat = Lat,
            .lon = Lon,
            .v = vp,
            .r = R,
        };
    }

    pub fn toString(self: HelioCoord, allocator: Allocator) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "Λ={d:.6}°, L={d:.6}°, ν={d:.6}°, R={d:.6} AU", .{
            self.lat.toDegrees(),
            self.lon.toDegrees(),
            self.v.toDegrees(),
            self.r
        });
    }
};

/// Return the horizontal coordinates of a celestial body for a given date (LCT) and location
pub fn bodyHorCoord(pb: *const Body, date: AstroDate, earth: *const HelioCoord, loc: GeoCoord) HorCoord {
    const lst_hrs = ast.lctToLST(date, loc.lon).hours;
    const eq = bodyRaDec(pb, date, earth);
    return eq.toHor(loc.lat, lst_hrs);
}

/// Return the equatorial coordinates of a celestial body for a given date (LCT)
pub fn bodyRaDec(pb: *const Body, date: AstroDate, earth: *const HelioCoord) RaDec {
    return bodyEcliptic(pb, date, earth).toRaDec();
}

/// Return the ecliptic coordinates of a celestial body for a given date (LCT)
pub fn bodyEcliptic(pb: *const Body, date: AstroDate, earth: *const HelioCoord) EclipticCoord {
    // Body's heliocentric coordinates
    const body = HelioCoord.fromDate(pb, date);

    // Adjustment to ecliptic longitude (8.6.7)
    var delta_lon = Angle.fromDegrees(body.lon.toDegrees() - pb.lon_asc_node);
    var y = delta_lon.sin() * @cos(pb.inclination * deg_to_rad);
    var x = delta_lon.cos();
    const L = Angle.fromDegrees(pb.lon_asc_node + Angle.atan2(y,x).toDegrees()).reduce360();

    // Geocentric ecliptic longitude
    delta_lon = Angle.fromDegrees(earth.lon.toDegrees() - L.toDegrees());
    const sin_lon = delta_lon.sin();
    const cos_lon = delta_lon.cos();
    const cos_lat = body.lat.cos();
    const tan_lat = body.lat.tan();
    var lon: Angle = undefined;
    if (pb.semi_major_axis_au < 1.0) {
        // Inferior planet (8.6.8)
        y = body.r * cos_lat * sin_lon;
        x = earth.r - body.r * cos_lat * cos_lon;
        lon = Angle.fromDegrees(180 + earth.lon.toDegrees() + Angle.atan2(y,x).toDegrees()).reduce360();
    } else {
        // Superior planet (8.6.9)
        y = -earth.r * sin_lon;
        x = body.r * cos_lat - earth.r * cos_lon;
        lon = Angle.fromDegrees(L.toDegrees() + Angle.atan2(y,x).toDegrees()).reduce360();
    }
    // Geocentric ecliptic latitude (8.6.10)
    delta_lon = Angle.fromDegrees(lon.toDegrees() - L.toDegrees());
    y = body.r * cos_lat * tan_lat * delta_lon.sin();
    x = -earth.r * sin_lon;
    const lat = Angle.atan(y / x);  // [-90°, +90°]

    return .{
        .lat = lat,
        .lon = lon,
    };
}