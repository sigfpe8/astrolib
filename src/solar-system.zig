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
    // const Ec = Angle.fromRadians(2 * e * M.sin()).toDegrees();
    // True anomaly
    // const v = Angle.fromDegrees(M.deg + Ec.deg).reduce360();

    // Find true anomaly by solving Kepler's equation
    const v = orb.trueAnomalyFromKeplerTan(e, M);

    // Ecliptic longitude    (λ = ν + ϖ)
    const lon = Angle.fromDegrees(v.toDegrees().deg + crd.epoch.sun_elong.toDegrees().deg).reduce360();
    // Ecliptic coordinates
    return EclipticCoord.init(Angle.fromDegrees(0), lon);
}

/// Return the Sun's mean anomaly for a given date (LCT)
pub fn sunMeanAnomaly(date: AstroDate) Angle {
    const ut = ast.lctToUT(date);
    const jde = crd.epoch.jd;
    const jd = ut.toJD();
    const De = jd - jde;

    return Angle.fromDegrees((360.0 * De) / 365.242_191 + 
                                crd.epoch.sun_elon.toDegrees().deg -
                                crd.epoch.sun_elong.toDegrees().deg).reduce360();
}

/// Return approximate local time for sunrise and sunset (Lawrence, 2018)
pub fn sunRiseAndSet(loc: GeoCoord, date: AstroDate) !RiseAndSetLCT {
    const ec1 = sunEclipticCoord(date.midnight());
    const lon1 = ec1.lon.toDegrees().deg;
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
    const Js = n - (loc.lon.toDegrees().deg / 360);
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
    const cos_w0 = (@sin(-0.833 * pi / 180) - @sin(loc.lat.toRadians().rad) * sin_dec) /
                   (@cos(loc.lat.toRadians().rad) * cos_dec);
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

pub fn moonMeanAnomaly(date: AstroDate) Angle {
    const ut = ast.lctToUT(date);
    const tt = ast.utToTT(ut);
    const jd = tt.toJD();
    const De = jd - crd.epoch.jd;

    // Moon's uncorrected mean longitude (7.3.1)
    var lon = Angle.fromDegrees(13.176_339_686 * De + 218.316_433).reduce360();

    // Moon's uncorrected mean anomaly (7.3.3)
    return Angle.fromDegrees(lon.toDegrees().deg - 0.111_404_1 * De - 83.353_451).reduce360();
}

/// Return the Moon's ecliptic coordinates for a given date (LCT)
pub fn moonEclipticCoord(date: AstroDate) EclipticCoord {
    // Algorithm by [Lawrence, 2018], p. 165

    const ut = ast.lctToUT(date);
    const tt = ast.utToTT(ut);
    const jd = tt.toJD();
    const De = jd - crd.epoch.jd;

    // Moon's uncorrected mean longitude (7.3.1)
    var lon = Angle.fromDegrees(13.176_339_686 * De + 218.316_433).reduce360();
    // Moon's uncorrected mean longitude of the ascending node
    var node_lon = Angle.fromDegrees(125.044_522 - 0.052_953_9 * De).reduce360();

    // Moon's uncorrected mean anomaly (7.3.3)
    const Mm = Angle.fromDegrees(lon.toDegrees().deg - 0.111_404_1 * De - 83.353_451).reduce360();

    // Sun's position and Mean anomaly
    const sun = sunEclipticCoord(date);
    const Ms = sunMeanAnomaly(date);

    // Corrections to the Moon's anomaly (all in degrees) (7.3.4-7.3.6)
    const Ae = 0.1858 * Ms.sin();
    const Ev = 1.2739 * @sin(2 * (lon.toRadians().rad - sun.lon.toRadians().rad) - Mm.toRadians().rad);
    const Ca = Mm.toDegrees().deg + Ev - Ae - 0.37 * Ms.sin();

    // Moon's true anomaly (7.3.7)
    const vm = 6.2886 * @sin(Ca * pi / 180.0) + 0.214 * @sin(2 * Ca * pi / 180.0);
    lon = Angle.fromDegrees(lon.toDegrees().deg + Ev + vm - Ae).reduce360();  // λ' (7.3.9)
    // Variation correction (7.3.8)
    const V = 0.6583 * @sin(2 * (lon.toRadians().rad - sun.lon.toRadians().rad));

    lon = Angle.fromDegrees(lon.toDegrees().deg + V).reduce360();   // λt (7.3.10)

    // Corrected longitude of the ascending node (7.3.11)
    node_lon = Angle.fromDegrees(node_lon.toDegrees().deg - 0.16 * Ms.sin()).reduce360();

    // Moon's ecliptic latitude and longitude (7.3.12-7.3.13)
    const e_rad = 5.145_396_4 * deg_to_rad;
    const sin_e = @sin(e_rad);
    const cos_e = @cos(e_rad);
    const delta_lon = lon.toRadians().rad - node_lon.toRadians().rad;
    const sin_lon = @sin(delta_lon);
    const y = sin_lon * cos_e;
    const x = @cos(delta_lon);
    const T = Angle.atan2(y, x);

    lon = Angle.fromDegrees(T.toDegrees().deg + node_lon.toDegrees().deg).reduce360();
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
    const elong = Angle.acos(@cos(moon.lon.toRadians().rad - sun.lon.toRadians().rad) * moon.lat.cos()).reduce360();
    const days = (elong.toDegrees().deg / 360.0) * 29.530_6;

    // Phase angle (7.6.6)
    const sin_mm = Mm.sin();
    const t1 = (1 - 0.054_9 * sin_mm);
    const t2 = (1 - 0.016_7 * sin_mm);
    const pa = 180 - elong.toDegrees().deg - 0.146_8 * (t1 / t2) * elong.sin();

    // Illumination fraction (7.6.7)
    const illum = (1 + @cos(pa * pi / 180.0)) * 0.5;
    
    const name = phase_names[@intFromFloat(@trunc((elong.toDegrees().deg + 22.5) / 45.0))];

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
