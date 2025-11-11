const std = @import("std");
const ang = @import("angle.zig");
const Angle = ang.Angle;

/// Angle type supporting degrees, radians, or hours.
// const Angle = union(enum) {
//     deg: f64,   // Decimal degrees
//     rad: f64,   // Radians
//     hrs: f64,   // Decimal hours

//     pub fn fromDegrees(degrees: f64) Angle {
//         return Angle{ .deg = degrees };
//     }

//     /// Convert to degrees (regardless of internal unit).
//     pub fn toDegrees(self: Angle) f64 {
//         return switch (self) {
//             .deg => |v| v,
//             .rad => |v| v * 180.0 / std.math.pi,
//             .hrs => |v| v * 15.0,
//         };
//     }
// };

/// Geographic coordinate using typed angles.
pub const GeoCoord = struct {
    pub const Latitude  = Angle;    // [ -90° (S),  +90° (N)]
    pub const Longitude = Angle;    // [-180° (W), +180° (E)]

    lat: Latitude,
    lon: Longitude,

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

/// World capital information.
const Capital = struct {
    city: []const u8,
    country: []const u8,
    coord: GeoCoord,
};

/// Sample list of major world capitals.
const capitals = [_]Capital{
    .{ .city = "Washington D.C.", .country = "United States", .coord = .{
        .lat = Angle.fromDegrees(38.8951),
        .lon = Angle.fromDegrees(-77.0364),
    }},
    .{ .city = "London", .country = "United Kingdom", .coord = .{
        .lat = Angle.fromDegrees(51.5074),
        .lon = Angle.fromDegrees(-0.1278),
    }},
    .{ .city = "Paris", .country = "France", .coord = .{
        .lat = Angle.fromDegrees(48.8566),
        .lon = Angle.fromDegrees(2.3522),
    }},
    .{ .city = "Berlin", .country = "Germany", .coord = .{
        .lat = Angle.fromDegrees(52.5200),
        .lon = Angle.fromDegrees(13.4050),
    }},
    .{ .city = "Rome", .country = "Italy", .coord = .{
        .lat = Angle.fromDegrees(41.9028),
        .lon = Angle.fromDegrees(12.4964),
    }},
    .{ .city = "Madrid", .country = "Spain", .coord = .{
        .lat = Angle.fromDegrees(40.4168),
        .lon = Angle.fromDegrees(-3.7038),
    }},
    .{ .city = "Lisbon", .country = "Portugal", .coord = .{
        .lat = Angle.fromDegrees(38.7169),
        .lon = Angle.fromDegrees(-9.1399),
    }},
    .{ .city = "Moscow", .country = "Russia", .coord = .{
        .lat = Angle.fromDegrees(55.7558),
        .lon = Angle.fromDegrees(37.6173),
    }},
    .{ .city = "Beijing", .country = "China", .coord = .{
        .lat = Angle.fromDegrees(39.9042),
        .lon = Angle.fromDegrees(116.4074),
    }},
    .{ .city = "Tokyo", .country = "Japan", .coord = .{
        .lat = Angle.fromDegrees(35.6895),
        .lon = Angle.fromDegrees(139.6917),
    }},
    .{ .city = "Seoul", .country = "South Korea", .coord = .{
        .lat = Angle.fromDegrees(37.5665),
        .lon = Angle.fromDegrees(126.9780),
    }},
    .{ .city = "New Delhi", .country = "India", .coord = .{
        .lat = Angle.fromDegrees(28.6139),
        .lon = Angle.fromDegrees(77.2090),
    }},
    .{ .city = "Canberra", .country = "Australia", .coord = .{
        .lat = Angle.fromDegrees(-35.2809),
        .lon = Angle.fromDegrees(149.1300),
    }},
    .{ .city = "Ottawa", .country = "Canada", .coord = .{
        .lat = Angle.fromDegrees(45.4215),
        .lon = Angle.fromDegrees(-75.6993),
    }},
    .{ .city = "Brasília", .country = "Brazil", .coord = .{
        .lat = Angle.fromDegrees(-15.7939),
        .lon = Angle.fromDegrees(-47.8828),
    }},
    .{ .city = "Buenos Aires", .country = "Argentina", .coord = .{
        .lat = Angle.fromDegrees(-34.6037),
        .lon = Angle.fromDegrees(-58.3816),
    }},
    .{ .city = "Mexico City", .country = "Mexico", .coord = .{
        .lat = Angle.fromDegrees(19.4326),
        .lon = Angle.fromDegrees(-99.1332),
    }},
    .{ .city = "Cairo", .country = "Egypt", .coord = .{
        .lat = Angle.fromDegrees(30.0444),
        .lon = Angle.fromDegrees(31.2357),
    }},
    .{ .city = "Nairobi", .country = "Kenya", .coord = .{
        .lat = Angle.fromDegrees(-1.2921),
        .lon = Angle.fromDegrees(36.8219),
    }},
    .{ .city = "Cape Town", .country = "South Africa", .coord = .{
        .lat = Angle.fromDegrees(-33.9249),
        .lon = Angle.fromDegrees(18.4241),
    }},
    .{ .city = "Riyadh", .country = "Saudi Arabia", .coord = .{
        .lat = Angle.fromDegrees(24.7136),
        .lon = Angle.fromDegrees(46.6753),
    }},
    .{ .city = "Ankara", .country = "Turkey", .coord = .{
        .lat = Angle.fromDegrees(39.9334),
        .lon = Angle.fromDegrees(32.8597),
    }},
    .{ .city = "Bangkok", .country = "Thailand", .coord = .{
        .lat = Angle.fromDegrees(13.7563),
        .lon = Angle.fromDegrees(100.5018),
    }},
    .{ .city = "Singapore", .country = "Singapore", .coord = .{
        .lat = Angle.fromDegrees(1.3521),
        .lon = Angle.fromDegrees(103.8198),
    }},
    .{ .city = "Jakarta", .country = "Indonesia", .coord = .{
        .lat = Angle.fromDegrees(-6.2088),
        .lon = Angle.fromDegrees(106.8456),
    }},
};

test "Cities and Coordinates" {
    for (capitals) |c| {
        std.debug.print(
            "{s: <15} ({s: <15}): {d:.4}, {d:.4}\n",
            .{
                c.city,
                c.country,
                c.coord.lat.toDegrees().deg,
                c.coord.lon.toDegrees().deg,
            },
        );
    }

        const paris = GeoCoord{
        .lat = Angle.fromDegrees(48.8566),
        .lon = Angle.fromDegrees(2.3522),
    };

    const tokyo = GeoCoord{
        .lat = Angle.fromDegrees(35.6895),
        .lon = Angle.fromDegrees(139.6917),
    };

    const dist = paris.distanceTo(tokyo);
    std.debug.print(
        "Distance Paris → Tokyo: {d:.2} km\n",
        .{ dist / 1000.0 },
    );

}
