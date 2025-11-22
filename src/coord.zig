const std = @import("std");
const ad = @import("astrodate.zig");
const AstroDate = ad.AstroDate;
const TimeZone = ad.TimeZone;
const UnixTime = ad.UnixTime;
const Year = ad.Year;
const Month = ad.Month;
const Day = ad.Day;

const ang = @import("angle.zig");
const Angle = ang.Angle;
const DMS = ang.DMS;
const HMS = ang.HMS;

const pi:     f64 = std.math.pi;
const two_pi: f64 = pi * 2.0;

const Allocator = std.mem.Allocator;

pub const CoordError = error{
    ObjNeverRises,
};

pub const EpochTag = enum {
    B1950,
    J2000,
};

pub const Epoch = struct {
    name: EpochTag,     // Epoch designator
    year: u32,          // Year of epoch (e.g. 2000)
    jd: f64,            // JD of epoch
    obl: Angle,         // Mean obliquity of the ecliptic (ε0)
    sin_obl: f64,       // Sine of obliquity (sin ε0)
    cos_obl: f64,       // Cosine of obliquity (cos ε0)
    gra0: Angle,        // RA of galactic north pole
    gdec0: Angle,       // Dec of galactic north pole
    glon0: Angle,       // Galactic longitude of ascending node (N0)
    ecc: f64,           // Mean eccentricity of the Earth-Sun orbit (e)
    sun_elon: Angle,    // Sun's ecliptic mean longitude at the epoch (εg)
    sun_elong: Angle,   // Sun's ecliptic mean longitude at perigee at the epoch (ϖg)
};

pub var epoch= &epochJ2000;    // Default = J2000

const epochJ2000: Epoch = .{
    .name = .J2000,
    .year = 2000,
    .jd = 2_451_545.0,       // January 1, 2000, 12:00:00 UT
    .obl = Angle.fromDegrees(23.43929111),
    .sin_obl = Angle.fromDegrees(23.43929111).sin(),
    .cos_obl = Angle.fromDegrees(23.43929111).cos(),
    .gra0  = Angle.fromHMS(HMS{.sign='+', .hour=12, .min=51, .sec=26.36}),
    .gdec0 = Angle.fromDMS(DMS{.sign='+', .deg=27, .min=7, .sec=40.90}),
    .glon0 = Angle.fromDegrees(32.9319),
    .ecc = 0.016708,
    .sun_elon = Angle.fromDegrees(280.466_069),
    .sun_elong = Angle.fromDegrees(282.938_346),
};

const epochB1950: Epoch = .{
    .name = .B1950,
    .year = 1950,
    .jd = 2_433_282.423_459_05,       // Somewhat before midnight December 31, 1949 GMT...
    .obl = Angle.fromDegrees(23.45229444),
    .sin_obl = Angle.fromDegrees(23.45229444).sin(),
    .cos_obl = Angle.fromDegrees(23.45229444).cos(),
    .gra0  = Angle.fromDegrees(192.25),
    .gdec0 = Angle.fromDegrees(27.4),
    .glon0 = Angle.fromDegrees(33),
    .ecc = 0.01675,
    // FIX: the two values below are from J2000
    .sun_elon = Angle.fromDegrees(280.466_069),
    .sun_elong = Angle.fromDegrees(282.938_346),
};

pub fn setStdEpoch(epc: EpochTag) void {
    switch (epc) {
        .B1950 => { epoch = &epochB1950; },
        .J2000 => { epoch = &epochJ2000; },
    }
}

/// Rise and set local time and azimuth of a celestial object
pub const RiseAndSet = struct {
    rise_lct:   AstroDate,   // Rising time in LCT
    rise_az:    Angle,       // Azimuth at rising time [0°, 360°)
    set_lct:    AstroDate,   // Set time in LCT
    set_az:     Angle,       // Azimuth at set time [0°, 360°)
};

/// Rise and set LCT of a celestial object
pub const RiseAndSetLCT = struct {
    rise_lct:   AstroDate,  // Local rise time
    set_lct:    AstroDate,  // Local set time
};

/// Rise and set LST of a celestial object
pub const RiseAndSetLST = struct {
    rise_lst: f64,   // Rising time in LST hours
    set_lst:  f64,   // Set time in LST hours
};

pub const Latitude  = Angle;    // [ -90°, +90°]
pub const Longitude = Angle;    // [-180°, +180°] or [0°, 360°) for ecliptic/galactic longitude

pub const GeoCoord = struct {
    lat: Latitude,  // [ -90° (S),  +90° (N)]
    lon: Longitude, // [-180° (W), +180° (E)]

    pub fn init(lat: Latitude, lon: Longitude) GeoCoord {
        return GeoCoord{
            .lat = lat,
            .lon = lon,
        };
    }

    /// Format string: dd°mm′ss″ N/S, dd°mm′ss″ E/W
    pub fn toString(self: GeoCoord, allocator: Allocator) ![]const u8 {
        var lat_dms = self.lat.toDMS();
        var lon_dms = self.lon.toDMS();

        const lat_hemisphere = if (lat_dms.sign == '-') "S" else "N";
        const lon_hemisphere = if (lon_dms.sign == '-') "W" else "E";
        // Make sure we don't print the "-" sign
        lat_dms.sign = '+';
        lon_dms.sign = '+';

        const lat_str = try lat_dms.toString(allocator);
        defer allocator.free(lat_str);
        const lon_str = try lon_dms.toString(allocator);
        defer allocator.free(lon_str);

        // return std.fmt.allocPrint(allocator, "{d}°{d:0>2}′{d:0>2.0}″ {s}, {d}°{d:0>2}′{d:0>2.0}″ {s}",
        return std.fmt.allocPrint(allocator, "{s} {s}, {s} {s}",
            .{
                lat_str, lat_hemisphere,
                lon_str, lon_hemisphere,
            });
    }

    /// Computes the great-circle distance between two coordinates, in meters.
    pub fn distanceTo(self: GeoCoord, other: GeoCoord) f64 {
        // Using haversine formula (ChatGPT)
        const R = 6371_000.0; // Earth radius in meters (mean)
        const lat1 = self.lat.toRadians().rad;
        const lon1 = self.lon.toRadians().rad;
        const lat2 = other.lat.toRadians().rad;
        const lon2 = other.lon.toRadians().rad;

        const dlat = lat2 - lat1;
        const dlon = lon2 - lon1;

        const sin_dlat = std.math.sin(dlat / 2.0);
        const sin_dlon = std.math.sin(dlon / 2.0);

        const a = sin_dlat * sin_dlat +
            std.math.cos(lat1) * std.math.cos(lat2) * sin_dlon * sin_dlon;

        const c = 2.0 * std.math.atan2(std.math.sqrt(a), std.math.sqrt(1.0 - a));
        return R * c;
    }
};

pub const HorCoord = struct {
    alt: Angle,       // Altitude [-90°, +90°]  (h)
    az:  Angle,       // Azimuth [0°, 360°) from north to east (A)

    pub fn init(alt: Angle, az: Angle) HorCoord {
        return HorCoord{
            .alt = alt,
            .az  = az,
        };
    }

    /// Convert horizontal coordinates to equatorial coordinates in RA/Dec system.
    pub fn toRaDec(self: HorCoord, lat: Latitude, lst_hrs: f64) RaDec {
        const hadec = self.toHaDec(lat);
        const ra = Angle.fromHours(@mod(lst_hrs - hadec.ha.toHours().hrs, 24.0));
        return RaDec.init(
            ra,
            hadec.dec
        );
    }

    /// Convert horizontal coordinates to equatorial coordinates in HA/Dec system.
    pub fn toHaDec(self: HorCoord, lat: Latitude) HaDec {
        const sin_az = self.az.sin();
        const cos_az = self.az.cos();

        const sin_alt = self.alt.sin();
        const cos_alt = self.alt.cos();

        const sin_lat = lat.sin();
        const cos_lat = lat.cos();

        const sin_dec = sin_alt * lat.sin() + cos_alt * cos_lat * cos_az;

        const dec = Angle.asin(sin_dec);

        const cos_ha = (sin_alt - sin_lat * sin_dec) / (cos_lat * dec.cos());
        var ha = Angle.acos(cos_ha).toHours();

        if (sin_az > 0.0) {
            // ha = 360 - ha;
            // ha = 24h - ha;
            ha = Angle.fromHours(24.0 - ha.hrs);
        }

        return HaDec.init(
            ha,
            dec
        );
    }

    /// String format: h=dd°mm'ss", A=ddd°mm'ss"
    pub fn toString(self: HorCoord, allocator: Allocator) ![]const u8 {
        const az_str = try self.az.toDMSString(allocator);
        defer allocator.free(az_str);
        const alt_str = try self.alt.toDMSString(allocator);
        defer allocator.free(alt_str);

        return try std.fmt.allocPrint(allocator, "h={s}, A={s}", .{
            alt_str,
            az_str,
        });
    }
};

/// Equatorial coordinate using HA/Dec
pub const HaDec = struct {
    ha:  Angle,       // Hour Angle [0h, 24h)     (H)
    dec: Angle,       // Declination [-90°, +90°] (δ)

    pub fn init(ha: Angle, dec: Angle) HaDec {
        return HaDec{
            .ha  = ha,
            .dec = dec,
        };
    }   

    /// Convert to horizontal coordinates.
    pub fn toHor(self: HaDec, lat: Latitude) HorCoord {
        const ha = self.ha.toRadians();

        const sin_dec = self.dec.sin();
        const cos_dec = self.dec.cos();

        const sin_lat = lat.sin();
        const cos_lat = lat.cos();

        const sin_alt = sin_dec * sin_lat + cos_dec * cos_lat * ha.cos();
        const alt = Angle.asin(sin_alt);

        const cos_az = (sin_dec - sin_alt * sin_lat) / (cos_lat * alt.cos());
        var az = Angle.acos(cos_az).toDegrees();

        const sin_ha = ha.sin();
        if (sin_ha > 0.0) {
            // az = 360 - az;
            az = Angle.fromDegrees(360.0 - az.deg);
        }

        return HorCoord.init(
            alt,
            az
        );
    }

    /// String format: H=hhʰmmᵐssˢ, δ=dd°mm'ss"
    pub fn toString(self: HaDec, allocator: Allocator) ![]const u8 {
        const ha_str = try self.ha.toHMSString(allocator);
        defer allocator.free(ha_str);
        const dec_str = try self.dec.toDMSString(allocator);
        defer allocator.free(dec_str);

        return try std.fmt.allocPrint(allocator, "H={s}, δ={s}", .{
            ha_str,
            dec_str,
        });
    }
};

/// Equatorial coordinate using RA/Dec
pub const RaDec = struct {
    ra:  Angle,       // Right Ascension [0h, 24h)  (ɑ)
    dec: Angle,       // Declination [-90°, +90°]   (δ)

    pub fn init(ra: Angle, dec: Angle) RaDec {
        return RaDec{
            .ra  = ra,
            .dec = dec,
        };
    }

    /// Convert to horizontal coordinates
    pub fn toHor(self: RaDec, lat: Latitude, lst_hrs: f64) HorCoord {
        const ha_equa = HaDec.init(
            // Convert RA to HA: HA = LST - RA
            Angle.fromHours(@mod(lst_hrs - self.ra.toHours().hrs, 24.0)),
            self.dec
        );
        return ha_equa.toHor(lat);
    }

    /// Convert to ecliptic coordinates
    pub fn toEcliptic(self: RaDec) EclipticCoord {
        // Formulas from "Celestial Calculations" by J.L. Lawrence, Chapter 4
        //   sin β = sin δ * cos ε - cos δ * sin ε * sin ɑ
        //   tan λ = (sin ɑ * cos ε + tan δ * sin ε) / cos ɑ
        const sin_dec = self.dec.sin();
        const cos_dec = self.dec.cos();
        const tan_dec = self.dec.tan();

        const sin_ra = self.ra.sin();
        const cos_ra = self.ra.cos();

        const sin_lat = sin_dec * epoch.cos_obl - cos_dec * epoch.sin_obl * sin_ra;
        const lat = Angle.asin(sin_lat);

        const y = sin_ra * epoch.cos_obl + tan_dec * epoch.sin_obl;
        const x = cos_ra;

        var lon = Angle.atan2(y, x).toDegrees();
        if (lon.deg < 0.0) { // [-180°, 180°) -> [0°, 360°)
            lon = Angle.fromDegrees(lon.deg + 360.0);
        }

        return EclipticCoord.init(
            lat,
            lon
        );
    }
    
    /// Convert to galactic coordinates
    pub fn toGalactic(self: RaDec) GalacticCoord {
        // Formulas from "Celestial Calculations" by J.L. Lawrence, Chapter 4
        //  (4.9.3)  sin b = cos δ * cos δ₀ * cos(ɑ - ɑ₀) + sin δ * sin δ₀
        //  (4.9.4)  l = atan2(sin δ - sin b * sin δ₀, cos δ * sin(ɑ - ɑ₀) * cos δ₀) + l₀
        const sin_dec = self.dec.sin();
        const cos_dec = self.dec.cos();

        const sin_dec0 = epoch.gdec0.sin();
        const cos_dec0 = epoch.gdec0.cos();

        const ra = Angle.fromHours(self.ra.toHours().hrs - epoch.gra0.toHours().hrs);
        const sin_ra = ra.sin();
        const cos_ra = ra.cos();

        const sin_lat = cos_dec * cos_dec0 * cos_ra + sin_dec * sin_dec0;
        const lat = Angle.asin(sin_lat);
        const y = sin_dec - sin_lat * sin_dec0;
        const x = cos_dec * sin_ra * cos_dec0;

        var lon = Angle.atan2(y, x).toDegrees();
        lon = Angle.fromDegrees(@mod(lon.deg + epoch.glon0.toDegrees().deg, 360.0));

        return GalacticCoord.init(
            lat,
            lon
        );
    }

    /// Adjust coordinates for precession between two epochs.
    pub fn adjustPrecession(self: RaDec, from_epoch: f64,   // Eg: 1950.0
                                         to_epoch: f64      // Eg: 2000.0
                                    ) RaDec {
        const d = to_epoch - from_epoch;
        const t = (to_epoch - 1900.0) / 100.0;
        const m: f64 = 3.07234 + 0.00186 * t;
        const nd: f64 = 20.0468 - 0.0085 * t;
        const nt: f64 = nd / 15.0;
        const delta_ra = (m + nt * self.ra.sin() * self.dec.tan()) * d;
        const delta_dec = nd * self.ra.cos() * d;

        return RaDec.init(
            Angle.fromHours(self.ra.toHours().hrs + delta_ra / 3600.0),
            Angle.fromDegrees(self.dec.toDegrees().deg + delta_dec / 3600.0)
        );
    }

    /// String format: α=dd°mm'ss", δ=dd°mm'ss"
    pub fn toString(self: RaDec, allocator: Allocator) ![]const u8 {
        const ra_str = try self.ra.toHMSString(allocator);
        defer allocator.free(ra_str);
        const dec_str = try self.dec.toDMSString(allocator);
        defer allocator.free(dec_str);

        return try std.fmt.allocPrint(allocator, "α={s}, δ={s}", .{
            ra_str,
            dec_str,
        });
    }
};

pub const EclipticCoord = struct {
    lat: Latitude,      // Ecliptic Latitude [-90°, +90°]  (β)
    lon: Longitude,     // Ecliptic Longitude [0°, 360°)   (λ)

    pub fn init(lat: Angle, lon: Angle) EclipticCoord {
        return EclipticCoord{
            .lat = lat,
            .lon = lon,
        };
    }

    pub fn toRaDec(self: EclipticCoord) RaDec {
        // Formulas from "Celestial Calculations" by J.L. Lawrence, Chapter 4
        //   sin δ = sin β * cos ε + cos β * sin ε * sin λ
        //   tan ɑ = (sin λ * cos ε - tan β * sin ε) / cos λ
        const sin_lat = self.lat.sin();
        const cos_lat = self.lat.cos();
        const tan_lat = self.lat.tan();

        const sin_lon = self.lon.sin();
        const cos_lon = self.lon.cos();

        const sin_dec = sin_lat * epoch.cos_obl + cos_lat * epoch.sin_obl * sin_lon;
        const dec = Angle.asin(sin_dec);

        const y = sin_lon * epoch.cos_obl - tan_lat * epoch.sin_obl;
        const x = cos_lon;

        var ra = Angle.atan2(y, x).toHours();
        if (ra.hrs < 0.0) { // [-12h, 12h) -> [0h, 24h)
            ra = Angle.fromHours(ra.hrs + 24.0);
        }

        return RaDec.init(
            ra,
            dec
        );
    }

    /// String format: β=dd°mm'ss", λ=dd°mm'ss"
    pub fn toString(self: EclipticCoord, allocator: Allocator) ![]const u8 {
        const lat_str = try self.lat.toHMSString(allocator);
        defer allocator.free(lat_str);
        const lon_str = try self.lon.toDMSString(allocator);
        defer allocator.free(lon_str);

        return try std.fmt.allocPrint(allocator, "β={s}, λ={s}", .{
            lat_str,
            lon_str,
        });
    }
};

pub const GalacticCoord = struct {
    lat: Latitude,      // Galactic Latitude [-90°, +90°]  (b)
    lon: Longitude,     // Galactic Longitude [0°, 360°).  (l)

    
    pub fn init(lat: Angle, lon: Angle) GalacticCoord {
        return GalacticCoord{
            .lat = lat,
            .lon = lon,
        };
    }

    pub fn toRaDec(self: GalacticCoord) RaDec {
        // Formulas from "Celestial Calculations" by J.L Lawrence, Chapter 4
        //   (4.9.1) sin δ = cos b cos δ₀ * sin(l - l₀) + sin b sin δ₀
        //   (4.9.2) ɑ = atan2(cos b * cos(l - l₀), sin b * cos δ₀ - cos b * sin δ₀ * sin(l - l₀)) + ɑ₀
        const lon = Angle.fromDegrees(self.lon.toDegrees().deg - epoch.glon0.toDegrees().deg); // l - l₀
        const sin_lat = self.lat.sin();
        const cos_lat = self.lat.cos();

        const sin_dec0 = epoch.gdec0.sin();
        const cos_dec0 = epoch.gdec0.cos();

        const sin_lon = lon.sin();
        const cos_lon = lon.cos();

        const sin_dec = cos_lat * cos_dec0 * sin_lon + sin_lat * sin_dec0;
        const dec = Angle.asin(sin_dec);

        const y = cos_lat * cos_lon;
        const x = sin_lat * cos_dec0 - cos_lat * sin_dec0 * sin_lon;
        var ra = Angle.atan2(y, x).toHours();

        if (ra.hrs < 0.0) { // [-12h, 12h) -> [0h, 24h)
            ra = Angle.fromHours(ra.hrs + 24.0);
        }

        ra = Angle.fromHours(@mod(ra.toHours().hrs + epoch.gra0.toHours().hrs, 24.0));

        return RaDec.init(
            ra,
            dec
        );
    }

    /// String format: b=dd°mm'ss", l=dd°mm'ss"
    pub fn toString(self: GalacticCoord, allocator: Allocator) ![]const u8 {
        const lat_str = try self.lat.toHMSString(allocator);
        defer allocator.free(lat_str);
        const lon_str = try self.lon.toDMSString(allocator);
        defer allocator.free(lon_str);

        return try std.fmt.allocPrint(allocator, "b={s}, l={s}", .{
            lat_str,
            lon_str,
        });
    }
};

/// Return the rise and set LCT and azimuth of a celestial object
pub fn riseAndSet(loc: GeoCoord, date: AstroDate, obj: RaDec) !RiseAndSet {
    const tan_lat = loc.lat.tan();
    const cos_lat = loc.lat.cos();
    const tan_dec = obj.dec.tan();
    const sin_dec = obj.dec.sin();
    const ar = sin_dec / cos_lat;
    const h1 = tan_lat * tan_dec;
    const tz = date.tz;

    if (ar < -1.0 or ar > 1.0 or h1 < -1.0 or h1 > 1.0) {
        return CoordError.ObjNeverRises;
    }

    const h2 = Angle.acos(-h1).toHours();

    // Rise tima and azimuth of object
    const rise_az = Angle.acos(ar);
    var rise_hrs = 24.0 + obj.ra.toHours().hrs - h2.hrs;
    if (rise_hrs > 24) {
        rise_hrs -= 24;
    }
    const rise_lst = AstroDate.fromDateAndHours(date.year, date.month, date.day, rise_hrs, tz);
    const rise_lct = ad.lstToLCT(rise_lst, loc.lon, date.tz);

    // Set time and azimuth of object
    const set_az  = Angle.fromDegrees(360.0 - rise_az.toDegrees().deg);
    var set_hrs = obj.ra.toHours().hrs + h2.hrs;
    if (set_hrs > 24) {
        set_hrs -= 24;
    }
    const set_lst = AstroDate.fromDateAndHours(date.year, date.month, date.day, set_hrs, tz);
    var set_lct  = ad.lstToLCT(set_lst, loc.lon, date.tz);
    if (set_lct.hours < rise_lct.hours) {
        set_lct = set_lct.adNextDay();        
    }

    return RiseAndSet{
        .rise_lct = rise_lct,
        .rise_az   = rise_az,
        .set_lct  = set_lct,
        .set_az    = set_az,
    };
}

/// Similar to riseAndSet() but return only the LST hours
pub fn riseAndSetLST(loc: GeoCoord, obj: RaDec) !RiseAndSetLST {
    const tan_lat = loc.lat.tan();
    const cos_lat = loc.lat.cos();
    const tan_dec = obj.dec.tan();
    const sin_dec = obj.dec.sin();
    const ar = sin_dec / cos_lat;
    const h1 = tan_lat * tan_dec;

    if (ar < -1.0 or ar > 1.0 or h1 < -1.0 or h1 > 1.0) {
        return CoordError.ObjNeverRises;
    }

    const h2 = Angle.acos(-h1).toHours();

    // Rise time of object
    var rise_lst = 24.0 + obj.ra.toHours().hrs - h2.hrs;
    if (rise_lst > 24) {
        rise_lst -= 24;
    }

    // Set time of object
    var set_lst = obj.ra.toHours().hrs + h2.hrs;
    if (set_lst > 24) {
        set_lst -= 24;
    }

    return RiseAndSetLST{
        .rise_lst = rise_lst,
        .set_lst  = set_lst,
    };
}
