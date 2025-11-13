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

pub const Epoch = enum {
    B1950,
    J2000,
    Custom,

    pub fn set(epoch: Epoch) void {
        switch (epoch) {
            .B1950 => {
                epch = .B1950;
                eps = eps0_B1950;
                sin_eps = sin_eps0_B1950;
                cos_eps = cos_eps0_B1950;
                gra0 = gra0_B1950;
                gdec0 = gdec0_B1950;
                glon0 = glon0_B1950;
            },
            .J2000 => {
                epch = .J2000;
                eps = eps0_J2000;
                sin_eps = sin_eps0_J2000;
                cos_eps = cos_eps0_J2000;
                gra0 = gra0_J2000;
                gdec0 = gdec0_J2000;
                glon0 = glon0_J2000;
            },
            .Custom => {
                // Do nothing; user must set parameters manually
            },
        }
    }
};

// Epoch B1950.0 constants
const eps0_B1950 = Angle.fromDegrees(23.45229444); // Mean obliquity (ε0) at 1950.0
const sin_eps0_B1950: f64 = eps0_B1950.sin();
const cos_eps0_B1950: f64 = eps0_B1950.cos();
// Galactic north pole and zero longitude
const gra0_B1950  = Angle.fromDegrees(192.25);
const gdec0_B1950 = Angle.fromDegrees(27.4);
const glon0_B1950 = Angle.fromDegrees(33);

// Epoch J2000.0 constants
const eps0_J2000  = Angle.fromDegrees(23.43929111); // Mean obliquity (ε0) at J2000.0
const sin_eps0_J2000: f64 = eps0_J2000.sin();
const cos_eps0_J2000: f64 = eps0_J2000.cos();
// Galactic north pole and zero longitude
const gra0_J2000  = Angle.fromHMS(HMS{.sign='+', .hour=12, .min=51, .sec=26.36});
const gdec0_J2000 = Angle.fromDMS(DMS{.sign='+', .deg=27, .min=7, .sec=40.90});
const glon0_J2000 = Angle.fromDegrees(32.9319);

// Current settings (default to J2000)
var epch = Epoch.J2000;         // Current epoch
var eps = eps0_J2000;           // Current obliquity of the ecliptic ()
var sin_eps: f64 = sin_eps0_J2000;     // Sine of obliquity (sin ε)
var cos_eps: f64 = cos_eps0_J2000;     // Cosine of obliquity (cos ε)
var gra0 = gra0_J2000;          // RA of galactic north pole
var gdec0 = gdec0_J2000;        // Dec of galactic north pole
var glon0 = glon0_J2000;        // Galactic longitude of ascending node (N0)

pub const RiseAndSet = struct {
    rise_time: AstroDate,   // Rising time in LCT
    rise_az:   Angle,       // Azimuth at rising time [0°, 360°)
    set_time:  AstroDate,   // Set time in LCT
    set_az:    Angle,       // Azimuth at set time [0°, 360°)
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

    pub fn toString(self: GeoCoord, allocator: Allocator) ![]const u8 {
        const lat_dms = self.lat.toDMS();
        const lon_dms = self.lon.toDMS();

        const lat_hemisphere = if (lat_dms.sign == '-') "S" else "N";
        const lon_hemisphere = if (lon_dms.sign == '-') "W" else "E";

        return std.fmt.allocPrint(allocator, "{d}°{d:0>2}'{d:0>2.0}\" {s}, {d}°{d:0>2}'{d:0>2.0}\" {s}",
            .{
                lat_dms.deg, lat_dms.min, lat_dms.sec, lat_hemisphere,
                lon_dms.deg, lon_dms.min, lon_dms.sec, lon_hemisphere,
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
    az:  Angle,       // Azimuth [0°, 360°) from north to east
    alt: Angle,       // Altitude [-90°, +90°]

    pub fn init(az: Angle, alt: Angle) HorCoord {
        return HorCoord{
            .az  = az,
            .alt = alt,
        };
    }

    /// Convert horizontal coordinates to equatorial coordinates in RA/Dec system.
    pub fn toRaDec(self: HorCoord, lat: Latitude, lst: Angle) RaDec {
        const hadec = self.toHaDec(lat);
        const ra = Angle.fromHours(@mod(lst.toHours().hrs - hadec.ha.toHours().hrs, 24.0));
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
};

/// Equatorial coordinate using HA/Dec
pub const HaDec = struct {
    ha:  Angle,       // Hour Angle [0h, 24h)
    dec: Angle,       // Declination [-90°, +90°]

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
        // std.debug.print("DEBUG: cos_az = {d}, az = {d}\n", .{cos_az, az.deg});

        const sin_ha = ha.sin();
        // std.debug.print("DEBUG: sin_ha = {d}\n", .{sin_ha});
        if (sin_ha > 0.0) {
            // az = 360 - az;
            az = Angle.fromDegrees(360.0 - az.deg);
            // std.debug.print("DEBUG: corrected az = {d}\n", .{az.deg});
        }

        return HorCoord.init(
            az,
            alt
        );
    }
};

/// Equatorial coordinate using RA/Dec
pub const RaDec = struct {
    ra:  Angle,       // Right Ascension [0h, 24h)
    dec: Angle,       // Declination [-90°, +90°]

    pub fn init(ra: Angle, dec: Angle) RaDec {
        return RaDec{
            .ra  = ra,
            .dec = dec,
        };
    }

    /// Convert to horizontal coordinates
    pub fn toHor(self: RaDec, lat: Latitude, lst: Angle) HorCoord {
        const ha_equa = HaDec.init(
            // Convert RA to HA: HA = LST - RA
            Angle.fromHours(@mod(lst.toHours().hrs - self.ra.toHours().hrs, 24.0)),
            self.dec
        );
        // std.debug.print("DEBUG: HA = {d} deg\n", .{ha_equa.ha.toDegrees().deg});
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

        const sin_lat = sin_dec * cos_eps - cos_dec * sin_eps * sin_ra;
        const lat = Angle.asin(sin_lat);

        const y = sin_ra * cos_eps + tan_dec * sin_eps;
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

        const sin_dec0 = gdec0.sin();
        const cos_dec0 = gdec0.cos();

        const ra = Angle.fromHours(self.ra.toHours().hrs - gra0.toHours().hrs);
        const sin_ra = ra.sin();
        const cos_ra = ra.cos();

        const sin_lat = cos_dec * cos_dec0 * cos_ra + sin_dec * sin_dec0;
        const lat = Angle.asin(sin_lat);
        const y = sin_dec - sin_lat * sin_dec0;
        const x = cos_dec * sin_ra * cos_dec0;

        var lon = Angle.atan2(y, x).toDegrees();
        lon = Angle.fromDegrees(@mod(lon.deg + glon0.toDegrees().deg, 360.0));

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
};

pub const EclipticCoord = struct {
    lat: Latitude,      // Ecliptic Latitude [-90°, +90°]
    lon: Longitude,     // Ecliptic Longitude [0°, 360°)

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

        const sin_dec = sin_lat * cos_eps + cos_lat * sin_eps * sin_lon;
        const dec = Angle.asin(sin_dec);

        const y = sin_lon * cos_eps - tan_lat * sin_eps;
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
};

pub const GalacticCoord = struct {
    lat: Latitude,      // Galactic Latitude [-90°, +90°]
    lon: Longitude,     // Galactic Longitude [0°, 360°)

    
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
        const lon = Angle.fromDegrees(self.lon.toDegrees().deg - glon0.toDegrees().deg); // l - l₀
        const sin_lat = self.lat.sin();
        const cos_lat = self.lat.cos();

        const sin_dec0 = gdec0.sin();
        const cos_dec0 = gdec0.cos();

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

        ra = Angle.fromHours(@mod(ra.toHours().hrs + gra0.toHours().hrs, 24.0));

        return RaDec.init(
            ra,
            dec
        );
    }
};

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

    // Rise azimuth and time of object
    const rise_az = Angle.acos(ar);
    var rise_hrs = 24.0 + obj.ra.toHours().hrs - h2.hrs;
    if (rise_hrs > 24) {
        rise_hrs -= 24;
    }
    const rise_lst = AstroDate.fromDateAndHours(date.year, date.month, date.day, rise_hrs, tz);
    const rise_time = ad.lstToLCT(rise_lst, loc.lon, date.tz);

    // Set azimuth and time of object
    const set_az  = Angle.fromDegrees(360.0 - rise_az.toDegrees().deg);
    var set_hrs = obj.ra.toHours().hrs + h2.hrs;
    if (set_hrs > 24) {
        set_hrs -= 24;
    }
    const set_lst = AstroDate.fromDateAndHours(date.year, date.month, date.day, set_hrs, tz);
    var set_time  = ad.lstToLCT(set_lst, loc.lon, date.tz);
    if (set_time.toHours() < rise_time.toHours()) {
        set_time = set_time.adNextDay();        
    }

    return RiseAndSet{
        .rise_time = rise_time,
        .rise_az   = rise_az,
        .set_time  = set_time,
        .set_az    = set_az,
    };
}
