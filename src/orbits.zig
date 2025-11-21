const std = @import("std");

const ang = @import("angle.zig");
const Angle = ang.Angle;

// Criteria for iterative methods
const max_it = 50;  // Maximum # of iterations
const eps: f64 = 0.000_002;       // Epsilon (desired precision)

// Equation of the center
//
//   Ec = ν - M
//
//   Ec = equation of the center
//   ν  = true anomaly
//   M  = mean anomaly

// ν = Ec + M
pub fn trueAnomalyFromEqCtr(
    e: f64,     // Orbit eccentricity
    M: Angle,   // Mean anomaly
) Angle {       // True anomaly
    // Calculate Ec with two terms from the infinite series (4.5.6)
    const mr: f64 = M.toRadians().rad;
    const t1: f64 = 2 * e * std.math.sin(mr);
    const two_mr: f64 = mr * 2;
    const t2: f64 = (5 * e * e * 0.25) * std.math.sin(two_mr);
    return Angle.fromRadians(t1 + t2 + mr);    // (4.5.5)
}

// Kepler's equation
//
//   M = E - e * sin(E)
//
//   M  = mean anomaly
//   E  = eccentric anomaly
//   e  = orbit eccentricity

pub fn trueAnomalyFromKeplerTan(
    e: f64,     // Orbit eccentricity
    M: Angle,   // Mean anomaly
) Angle {       // True anomaly (ν)
    const E = keplerNewtonRaphson(e, M);
    var v = trueAnomalyFromETan(e, E);
    if (v.toDegrees().deg < 0) {
        v = Angle.fromDegrees(v.toDegrees().deg + 360.0);
    }
    return v;
}

pub fn trueAnomalyFromKeplerCos(
    e: f64,     // Orbit eccentricity
    M: Angle,   // Mean anomaly
) Angle {       // True anomaly (ν)
    const E = keplerNewtonRaphson(e, M);
    return trueAnomalyFromECos(e, E);
}

pub fn trueAnomalyFromKeplerSeries(
    e: f64,     // Orbit eccentricity
    M: Angle,   // Mean anomaly
) Angle {       // True anomaly (ν)
    const E = keplerNewtonRaphson(e, M);
    return trueAnomalyFromESeries(e, E);
}

/// Solve Kepler's equation using the Newton-Raphson iterative method
pub fn keplerNewtonRaphson(
    e: f64,     // Orbit eccentricity
    M: Angle,   // Mean anomaly
) Angle {       // Eccentric anomaly (E)
    const mr: f64 = M.toRadians().rad;// Mean anomaly in radians
    var Ep: f64 = undefined;          // Previous estimate
    var Ei: f64 = undefined;          // Current estimate
    var i: usize = 1;                 // Current iteration

    Ep = if (e <= 0.75) mr else std.math.pi;

    while (i < max_it) : (i += 1) {
        Ei = Ep - (Ep - e * @sin(Ep) - mr) / (1 - e * @cos(Ep));
        const delta = @abs(Ei - Ep);
        // std.debug.print("i={d},  delta={d:0<10.6},  E={d:0<10.6}\n", .{i, delta, Ei});
        if (delta < eps)
            break;
        Ep = Ei;
    }

    return Angle.fromRadians(Ei);
}

/// Solve Kepler's equation using a simple iterative method
pub fn keplerSimple(
    e: f64,     // Orbit eccentricity
    M: Angle,   // Mean anomaly
) Angle {       // Eccentric anomaly (E)
    const mr: f64 = M.toRadians().rad;// Mean anomaly in radians
    var Ep: f64 = undefined;          // Previous estimate
    var Ei: f64 = undefined;          // Current estimate
    var i: usize = 1;                 // Current iteration

    Ep = mr;

    while (i < max_it) : (i += 1) {
        Ei = mr + e * @sin(Ep);
        const delta = @abs(Ei - Ep);
        // std.debug.print("i={d},  delta={d:0<10.6},  E={d:0<10.6}\n", .{i, delta, Ei});
        if (delta < eps)
            break;
        Ep = Ei;
    }

    return Angle.fromRadians(Ei);
}

/// Formulas for true anomaly (ν) given the eccentricity (e) and the eccentric anomaly (E)

/// tan(ν/2) = sqrt((1 + e) / (1 - e)) * tan(E / 2)
///   ν/2 ε [-π/2, +π/2];  ν ε [-π, +π]
pub fn trueAnomalyFromETan(
    e: f64,     // Orbit eccentricity
    E: Angle,   // Eccentric anomaly
) Angle {       // True anomaly (ν)
    const tan_half = std.math.sqrt((1+e)/(1-e)) * @tan(E.toRadians().rad/2);
    return Angle.fromRadians(std.math.atan(tan_half) * 2);
}

/// cos(ν) = (cos E - e) / (1 - e * cos E)
///   ν ε [0, π]
pub fn trueAnomalyFromECos(
    e: f64,     // Orbit eccentricity
    E: Angle,   // Eccentric anomaly
) Angle {       // True anomaly (ν)
    const cos_E = E.cos();
    const cos_v = (cos_E - e) / (1 - e * cos_E);
    return Angle.acos(cos_v);
}

/// [Smart, 1977] (85, p. 119)
/// ν = E + (e + 1/4*e^3) * sin(E) + 1/4*e^2 * sin(2E) + 1/12*e^3 * sin(3E)
pub fn trueAnomalyFromESeries(
    e: f64,     // Orbit eccentricity
    E: Angle,   // Eccentric anomaly
) Angle {       // True anomaly (ν)
    const Er = E.toRadians().rad;
    const e2 = e * e;
    const e3 = e2 * e;
    const t1 = Er;
    const t2 = (e + 0.25 * e3) * @sin(Er);
    const t3 = 0.25 * e2 * @sin(2 * Er);
    const t4 = e3 * @sin(Er * 3) / 12.0;
    return Angle.fromRadians(t1 + t2 + t3 + t4); 
}
