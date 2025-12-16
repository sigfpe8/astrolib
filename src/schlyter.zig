// Algorithms from
//   http://www.stjarnhimlen.se/comp/ppcomp.html
//   http://www.stjarnhimlen.se/comp/tutorial.html
const std = @import("std");

const ang = @import("angle.zig");
const Angle = ang.Angle;

const ast = @import("astrodate.zig");
const Year = ast.Year;
const Month = ast.Month;
const Day = ast.Day;

const crd = @import("coord.zig");
const RaDec = crd.RaDec;

const sol = @import("solar-system.zig");

const pi: f64 = std.math.pi;
const sqrt = std.math.sqrt;

const Allocator = std.mem.Allocator;

const rad_to_deg: f64 = 180.0 / pi;     // 1 radian = 180/π degrees
const deg_to_rad: f64 = pi / 180.0;     // 1 degree = π/180 radians

const HelioCoord = struct {
    d: f64 = 0,     // Day number for these coordinates
    x: f64 = 0,     // Heliocentric cartesian coordinates
    y: f64 = 0,
    z: f64 = 0,
    M: f64 = 0,     // Mean anomaly
    w: f64 = 0,     // Argument of the perihelion
    L: f64 = 0,     // Mean longitude
};

var sunXYZ: HelioCoord = .{};

// Trigonometric functions in degrees
fn sin(deg: f64) f64 { return @sin(deg * deg_to_rad); }
fn cos(deg: f64) f64 { return @cos(deg * deg_to_rad); }
fn atan2(y: f64, x:f64) f64 { return std.math.atan2(y,x) * rad_to_deg; }

const Pair = struct { f64, f64 };

const Body = struct {
    // The primary orbital elements of the Body
    //      N = longitude of the ascending node (Ω)
    //      i = inclination to the ecliptic (plane of the Earth's orbit)
    //      w = argument of perihelion (ω)
    //      a = semi-major axis, or mean distance from Sun
    //      e = eccentricity (0=circle, 0-1=ellipse, 1=parabola)
    //      M = mean anomaly (0 at perihelion; increases uniformly with time)
    //
    // The value of `a` is given in AU for the planets and in Earth radii for the Moon.
    // The arguments to the constructor are actually pairs of values [v0,v1] such that
    // the desired element value can be calculated at a given day number `d` as
    //      v = v0 + v1 * d
    id: usize,
    name: []const u8,
    N0: f64,
    N1: f64,
    i0: f64,
    i1: f64,
    w0: f64,
    w1: f64,
    a0: f64,
    a1: f64,
    e0: f64,
    e1: f64,
    M0: f64,
    M1: f64,

    pub fn init(id: usize, name:[]const u8, N:Pair, i:Pair, w:Pair, a:Pair, e: Pair, M:Pair) Body {
        return .{
            .id = id,
            .name = name,
            .N0 = N[0],
            .N1 = N[1],
            .i0 = i[0],
            .i1 = i[1],
            .w0 = w[0],
            .w1 = w[1],
            .a0 = a[0],
            .a1 = a[1],
            .e0 = e[0],
            .e1 = e[1],
            .M0 = M[0],
            .M1 = M[1],
        };
    }

	// Return the body's orbital elements adjusted for day number 'd'
	// All angles are reduced to the range [0, 360)
	pub fn fN(self: *const Body, d: f64) f64 { return @rem(@rem(self.N0 + self.N1 * d, 360) + 360, 360); }
	pub fn fi(self: *const Body, d: f64) f64 { return @rem(@rem(self.i0 + self.i1 * d, 360) + 360, 360); }
	pub fn fw(self: *const Body, d: f64) f64 { return @rem(@rem(self.w0 + self.w1 * d, 360) + 360, 360); }
	pub fn fa(self: *const Body, d: f64) f64 { return self.a0 + self.a1 * d; }
	pub fn fe(self: *const Body, d: f64) f64 { return self.e0 + self.e1 * d; }
	pub fn fM(self: *const Body, d: f64) f64 { return @rem(@rem(self.M0 + self.M1 * d, 360) + 360, 360); }

	pub fn bodyRaDec(self: *const Body, d: f64) RaDec {
		// Adjusted orbital elements
		const N = self.fN(d);
		const w = self.fw(d);
		const e = self.fe(d);
		const M = self.fM(d);
		const a = self.fa(d);
		const i = self.fi(d);

		// Obliquity of the ecliptic
		const oblecl = 23.4393 - 3.563E-7 * d;

		// Eccentric anomaly
		// E0 = M + (180_deg/pi) * e * sin(M) * (1 + e * cos(M))
		// E1 = E0 - (E0 - (180_deg/pi) * e * sin(E0) - M) / (1 - e * cos(E0))
		var E0 = M + (rad_to_deg) * e * sin(M) * (1 + e * cos(M));
		var E = E0 - (E0 - (rad_to_deg) * e * sin(E0) - M) / (1 - e * cos(E0));
		var niters: u32 = 0;
		while (@abs(E - E0) > 0.005 and niters < 20) : (niters += 1) {
			E0 = E;
			E = E0 - (E0 - (rad_to_deg) * e * sin(E0) - M) / (1 - e * cos(E0));
		}

		// Compute the body's rectangular coordinates in the plane of the ecliptic
		const xv = a * (cos(E) - e);
		const yv = a * (sqrt(1.0 - e * e) * sin(E));

		// Compute distance and true anomaly
		const r = sqrt(xv * xv + yv * yv);
		const v = atan2(yv, xv);
		//console.log("r=",r,"v=",v);

		// Compute the body's position in 3-D space
		// Heliocentric for the planets, geocentric for the Moon
		var xh = r * (cos(N) * cos(v+w) - sin(N) * sin(v+w) * cos(i));
		var yh = r * (sin(N) * cos(v+w) + cos(N) * sin(v+w) * cos(i));
		var zh = r * (sin(v+w) * sin(i));
        // std.debug.print("{s:10}: xh={d:10.6},  yh={d:10.6},  zh={d:10.6}\n", .{self.name, xh, yh, zh});

		// Ecliptical coordinates
		var lon = @rem((atan2(yh, xh) + 360), 360);
		var lat = atan2(zh, sqrt(xh*xh + yh*yh));
		// std.debug.print("{s:10}: lon={d:8.4}  lat={d:7.4}  r={d:10.6}\n", .{self.name, lon, lat, r});

		// The Sun's elements must be calculated before those of the other bodies
		if (sunXYZ.d != d and self.id != Sun) {
			_ = bodies[Sun].bodyRaDec(d);
			// std.debug.print("Initialized the Sun: x={d:.4}, y={d:.4}\n",.{sunXYZ.x, sunXYZ.y});
		}

		// Calculate main perturbations to the Moon, Jupiter, Saturn and Uranus

		var xg: f64 = undefined;	    // Geocentric coordinates
        var yg: f64 = undefined;
        var zg: f64 = undefined;
		var Mm: f64 = undefined;
        var Mj: f64 = undefined;        // Mean anomaly for Moon/Jupiter/Saturn/Sun/Uranus
        var Ms: f64 = undefined;
        var Mu: f64 = undefined;
		var Nm: f64 = undefined;	    // Longitude of the Moon's node
		var ws: f64 = undefined;	    // Argument of perihelion for the Sun and the Moon
        var wm: f64 = undefined;
		var Ls: f64 = undefined;	    // Mean longitude of the Sun
		var Lm: f64 = undefined;	    // Mean longitude of the Moon
		var D: f64 = undefined;		    // Mean elongation of the Moon
		var F: f64 = undefined;		    // Argument of latutude for the moon
		var lon_pert: f64 = undefined;	// Longitude/latitude perturbations
        var lat_pert: f64 = undefined;
		var dis_pert: f64 = undefined;	// Distance perturbations

		switch (self.id) {
            Sun => {
                // Remember these parameters for the other bodies
                sunXYZ.d = d;
                sunXYZ.x = xh;
                sunXYZ.y = yh;
                sunXYZ.z = 0;
                sunXYZ.M = M;
                sunXYZ.w = w;
                sunXYZ.L = @rem(@rem(w + M, 360) + 360, 360);
            },
		    Moon => {
		        // The Moon's position is already geocentric, but we need
		        // to add the perturbations to lon and lat.
		        Ms = sunXYZ.M;
		        ws = sunXYZ.w;
		        Mm = M;
		        Nm = N;
		        wm = w;
		        Ls = Ms + ws;
		        Lm = Mm + wm + Nm;
		        D = Lm - Ls;
		        F = Lm - Nm;
		        lon_pert = 
		        	-1.274 * sin(Mm - 2*D)			// The Evection
		        	+ 0.658 * sin(2*D)				// The Variation
		        	- 0.186 * sin(Ms)				// The Yearly Equation
		        	- 0.059 * sin(2*Mm - 2*D)
		        	- 0.057 * sin(Mm - 2*D + Ms)
		        	+ 0.053 * sin(Mm + 2*D)
		        	+ 0.046 * sin(2*D - Ms)
		        	+ 0.041 * sin(Mm - Ms)
		        	- 0.035 * sin(D)					// The Parallactic Equation
		        	- 0.031 * sin(Mm + Ms)
		        	- 0.015 * sin(2*F - 2*D)
		        	+ 0.011 * sin(Mm - 4*D);
		        lat_pert =
		        	-0.173 * sin(F - 2*D)
		        	- 0.055 * sin(Mm - F - 2*D)
		        	- 0.046 * sin(Mm + F - 2*D)
		        	+ 0.033 * sin(F + 2*D)
		        	+ 0.017 * sin(2*Mm + F);
		        dis_pert =
		        	-0.58 * cos(Mm - 2*D)
		        	- 0.46 * cos(2*D);
		        lon += lon_pert;
		        lat += lat_pert;
		        // r += dis_pert;
		        // console.log("Moon: lon=",lon,"lat=",lat,"r=",r);
		        // r = 1.0;
		        xg = cos(lon) * cos(lat);
		        yg = sin(lon) * cos(lat);
		        zg = sin(lat);
            },
		    Jupiter => {
		    	// Add longitude perturbations
		    	Mj = M;
		    	Ms = bodies[Saturn].fM(d);
		    	lon_pert =
		    		-0.332 * sin(2*Mj - 5*Ms - 67.6)
		    		- 0.056 * sin(2*Mj - 2*Ms + 21)
		    		+ 0.042 * sin(3*Mj - 5*Ms + 21)
		    		- 0.036 * sin(Mj - 2*Ms)
		    		+ 0.022 * cos(Mj - Ms)
		    		+ 0.023 * sin(2*Mj - 3*Ms + 52)
		    		- 0.016 * sin(Mj - 5*Ms - 69);
		    	lon += lon_pert;
		    	xh = r * cos(lon) * cos(lat);
		    	yh = r * sin(lon) * cos(lat);
		    	zh = r * sin(lat);
                },
		    Saturn => {
		    	// Add longitude and latitude perturbations
		    	Mj = bodies[Jupiter].fM(d);
		    	Ms = M;
		    	lon_pert =
		    		 0.812 * sin(2*Mj - 5*Ms - 67.6)
		    		- 0.229 * cos(2*Mj - 4*Ms - 2)
		    		+ 0.119 * sin(Mj - 2*Ms - 3)
		    		+ 0.046 * sin(2*Mj - 6*Ms - 69)
		    		+ 0.014 * sin(Mj - 3*Ms + 32);
		    	lat_pert =
		    		-0.020 * cos(2*Mj - 4*Ms - 2)
		    		+ 0.018 * sin(2*Mj - 6*Ms - 49);
		    	lon += lon_pert;
		    	lat += lat_pert;
		    	xh = r * cos(lon) * cos(lat);
		    	yh = r * sin(lon) * cos(lat);
		    	zh = r * sin(lat);
            },
		    Uranus => {
		    	// Add longitude perturbations
		    	Mj = bodies[Jupiter].fM(d);
		    	Ms = bodies[Saturn].fM(d);
		    	Mu = M;
		    	lon_pert =
		    		 0.040 * sin(Ms - 2*Mu + 6)
		    		+ 0.035 * sin(Ms - 3*Mu + 33)
		    		- 0.015 * sin(Mj - Mu + 20);
		    	lon += lon_pert;
            },
            else => {},
		}

		if (self.id != Moon) {
			xg = xh + sunXYZ.x;
			yg = yh + sunXYZ.y;
			zg = zh;
		}

		// Geocentric rectangular to equatorial coordinates
		const xeqt = xg;
		const yeqt = yg * cos(oblecl) - zg * sin(oblecl);
		const zeqt = yg * sin(oblecl) + zg * cos(oblecl);

		// Convert to RA and DE:
		const RA_deg = @rem(atan2(yeqt, xeqt) + 360, 360);
		// const RA = (RA_deg * 24) / 360;  // in hours
		const DE_deg  = atan2(zeqt, sqrt(xeqt*xeqt + yeqt*yeqt));
        // std.debug.print("{s:10}: RA={d:7.4}, Decl={d:8.4}\n", .{self.name, RA, DE});
        const Ra = Angle.fromDegrees(RA_deg);
        const Dec = Angle.fromDegrees(DE_deg);
        return RaDec.init(Ra, Dec);
    }

    /// Return the orbital elements of a body adjusted for a given date
    pub fn orbitalElements(self: *const Body, d: f64) struct { f64, f64, f64, f64, f64, f64 } {
        const N = self.fN(d);
        const i = self.fi(d);
        const w = self.fw(d);
        const a = self.fa(d);
        const e = self.fe(d);
        const M = self.fM(d);

        return .{ N, i, w, a, e, M };
    }

    /// Return the non-adjusted orbital elements of a body
    pub fn orbitalElements0(self: *const Body) struct { f64, f64, f64, f64, f64, f64 } {
        const N = self.N0;
        const i = self.i0;
        const w = self.w0;
        const a = self.a0;
        const e = self.e0;
        const M = self.M0;

        return .{ N, i, w, a, e, M };
    }
};

const Sun = sol.Sun;
const Moon = sol.Moon;
const Earth = sol.Earth;
const Mercury = sol.Mercury;
const Venus = sol.Venus;
const Mars = sol.Mars;
const Jupiter = sol.Jupiter;
const Saturn = sol.Saturn;
const Uranus = sol.Uranus;
const Neptune = sol.Neptune;
const Pluto = sol.Pluto;

const bodies = [_]Body{
    Body.init(Sun, "Sun",
            .{0, 0},                        // N
            .{0, 0},                        // i
            .{282.9404, 4.70935E-5},        // w
            .{1.000000, 0},                 // a
            .{0.016709, -1.151E-9},         // e
            .{356.0470, 0.9856002585}),     // M

    Body.init(Moon, "Moon",
            .{125.1228, -0.0529538083},     // N
            .{5.1454, 0},                   // i
            .{318.0634, 0.1643573223},      // w
            .{60.2666, 0},                  // a (Earth radii)
            .{0.054900, 0},                 // e
            .{115.3654, 13.0649929509}),    // M

    Body.init(Earth, "Earth",
            .{0, 0},                        // N
            .{0, 0},                        // i
            .{282.9404, 4.70935E-5},        // w
            .{1.000000, 0},                 // a
            .{0.016709, -1.151E-9},         // e
            .{356.0470, 0.9856002585}),     // M

    Body.init(Mercury, "Mercury",
            .{48.3313, 3.24587E-5},         // N
            .{7.0047, 5.00E-8},             // i
            .{29.1241, 1.01444E-5},         // w
            .{0.387098, 0},                 // a
            .{0.205635, 5.59E-10},          // e
            .{168.6562, 4.0923344368}),     // M

    Body.init(Venus, "Venus",
            .{76.6799, 2.46590E-5},         // N
            .{3.3946, 2.75E-8},             // i
            .{54.8910, 1.38374E-5},         // w
            .{0.723330, 0},                 // a
            .{0.006773, -1.302E-9},         // e
            .{48.0052, 1.6021302244}),      // M

    Body.init(Mars, "Mars",
            .{49.5574, 2.11081E-5},         // N
            .{1.8497, -1.78E-8},            // i
            .{286.5016, 2.92961E-5},        // w
            .{1.523688, 0},                 // a
            .{0.093405, 2.516E-9},          // e
            .{18.6021, 0.5240207766}),      // M

    Body.init(Jupiter, "Jupiter",
            .{100.4542, 2.76854E-5},        // N
            .{1.3030, -1.557E-7},           // i
            .{273.8777, 1.64505E-5},        // w
            .{5.20256, 0},                  // a
            .{0.048498, 4.469E-9},          // e
            .{19.8950, 0.0830853001}),      // M

    Body.init(Saturn, "Saturn",
            .{113.6634, 2.38980E-5},        // N
            .{2.4886, -1.081E-7},           // i
            .{339.3939, 2.97661E-5},        // w
            .{9.55475, 0},                  // a
            .{0.055546, -9.499E-9},         // e
            .{316.9670, 0.0334442282}),     // M

    Body.init(Uranus, "Uranus",
            .{74.0005, 1.3978E-5},          // N
            .{0.7733, 1.9E-8},              // i
            .{96.6612, 3.0565E-5},          // w
            .{19.18171, -1.55E-8},          // a
            .{0.047318, 7.45E-9},           // e
            .{142.5905, 0.011725806}),      // M

    Body.init(Neptune, "Neptune",
            .{131.7806, 3.0173E-5},         // N
            .{1.7700, -2.55E-7},            // i
            .{272.8461, -6.027E-6},         // w
            .{30.05826, 3.313E-8},          // a
            .{0.008606, 2.15E-9},           // e
            .{260.2471, 0.005995147}),      // M

    Body.init(Pluto, "Pluto",                   // To be completed
            .{110.2212, 0},                 // N
            .{17.1400, 0},                  // i
            .{224.0665, 0},                 // w ?
            .{39.4821, 0},                  // a
            .{0.248808, 0},                 // e
            .{0, 0}),                       // M ?
};

// Return number of days since 2000 Jan 0.0 TDT
// Day 0 = 1999-12-31 00:00:00 aka 2000-01-00 00:00:00
// For simplicity, ignore the difference between UT and TDT
pub fn dayNumber(year:i32, month:i32, day:i32, ut: f64) f64 {
	// dn = 367*y - 7 * ( y + (m+9)/12 ) / 4 - 3 * ( ( y + (m-9)/7 ) / 100 + 1 ) / 4 + 275*m/9 + D - 730515
	// Use integer division everywhere except for the ut fraction
	const d1: i32 = 367 * year;
	const d2: i32 = @divTrunc(7 * (year + @divTrunc(month + 9, 12)), 4);
	const d3: i32 = 3 * @divTrunc(@divTrunc(year + @divTrunc(month - 9, 7), 100) + 1,  4);
	const d4: i32 = @divTrunc(275 * month, 9);
	const dn: f64 = @as(f64,@floatFromInt(d1)) - 
                    @as(f64,@floatFromInt(d2)) -
                    @as(f64,@floatFromInt(d3)) +
                    @as(f64,@floatFromInt(d4)) +
                    @as(f64,@floatFromInt(day)) -
                    730515.0 +
                    ut / 24;
	return dn;
}

pub fn allPlanetPositions(year: Year, month: Month, day: Day, ut: f64, allocator: Allocator) ![]RaDec {
    const d = dayNumber(year, month, day, ut);
    var list: std.ArrayList(RaDec) = .empty;

    for (bodies[Mercury..]) |*p| {
        const radec = p.bodyRaDec(d);
        try list.append(allocator, radec);
        // std.debug.print("{s:10}: RA={d:10.6}, Decl={d:10.6}\n",
        // .{p.name, radec.ra.toDegrees(), radec.dec.toDegrees()});
    }

    return list.toOwnedSlice(allocator);
}

pub fn printPlanetPositions(year: Year, month: Month, day: Day, ut: f64, allocator: Allocator) !void {
    const d = dayNumber(year, month, day, ut);
    std.debug.print("Planet positions for {d}-{d}-{d} {d:02.0}h UT (d={d})\n",
        .{year, month, day, ut, d});
    const list = try allPlanetPositions(year, month, day, ut, allocator);
    defer allocator.free(list);

    for (list, Mercury..) |radec, i| {
        const p = &bodies[i];
        std.debug.print("{s:10}: RA={d:10.6}, Decl={d:10.6}\n",
        .{p.name, radec.ra.toDegrees(), radec.dec.toDegrees()});
    }
}

pub fn printOrbitalElements(d: f64) void {
    std.debug.print("               N          i          w           a          e          M\n", .{});
    std.debug.print("           ---------   --------  ---------   ---------   --------  ---------\n", .{});
    for (bodies[Mercury..]) |*b| {
        // Elements at J2000 (non-adjusted)
        // var N, var i, var w, var a, var e, var M = b.orbitalElements0();
        // std.debug.print("{s:<10} {d:8.4}°  {d:8.4}°  {d:8.4}°  {d:10.6}  {d:9.6}  {d:8.4}°\n",
        //         .{b.name, N, i, w, a, e, M });
        // Elements adjusted for date
        const N, const i, const w, const a, const e, const M = b.orbitalElements(d);
        std.debug.print("{s:<10} {d:8.4}°  {d:8.4}°  {d:8.4}°  {d:10.6}  {d:9.6}  {d:8.4}°\n",
                .{b.name, N, i, w, a, e, M });
    }
}

test "Body" {
    const allocator = std.testing.allocator;
    const d = dayNumber(1990, 4, 19, 0);
    // printOrbitalElements(d);
    std.debug.print("1990-4-19 00:00 UT -> d={d}\n", .{d});
    // try printPlanetPositions(1990, 4, 19, 0, allocator);
    try printPlanetPositions(2000, 1, 1, 12, allocator);
    // for (bodies[Mercury..]) |*p| {
    //     const radec = p.bodyRaDec(d);
    //     std.debug.print("{s:10}: RA={d:10.6}, Decl={d:10.6}  (Schlyter)\n",
    //     .{p.name, radec.ra.toDegrees(), radec.dec.toDegrees()});

    // }
    // // std.debug.print("{s} -> w0={d}, M1={d}\n", .{sun.name, sun.w0, sun.M1});
}