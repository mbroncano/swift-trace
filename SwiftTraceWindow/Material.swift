//
//  Material.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/19/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

enum Refl_t { case DIFF; case SPEC; case REFR }  // material types, used in radiance()

protocol Material {
    var emission: Color { get }
    var color: Color { get }

    /// Evaluates material reflectance
    func sample(wi: Vec, normal: Vec) -> (Scalar, Vec)
}

struct Refractive: Material {
    let emission: Color
    let color: Color
    let nc: Scalar = 1
    let nt: Scalar = 1.5

    func sample(wi: Vec, normal: Vec) -> (Scalar, Vec) {
        let into: Bool
        let nl: Vec
        let nnt: Scalar
        
        // Adjust when the ray is inwards
        (nl, nnt, into) = dot(wi, normal) < 0 ? (normal, nc / nt, true) : (normal * -1, nt / nc, false)

        let ddn = dot(wi, nl)
        let cos2t = 1 - nnt * nnt * (1 - ddn * ddn)

        // Total internal reflection
        if (cos2t < 0) {
            return (1.0, reflect(wi, n: normal))
        }
        
        // Slick's approximation to Fresnel factor
        // https://en.wikipedia.org/wiki/Schlick%27s_approximation
        let t1 = (into ? 1 : -1) * (ddn * nnt + sqrt(cos2t))
        let tdir = normalize(wi * nnt - normal * t1)
        let a = nt - nc
        let b = nt + nc
        let R0 =  a * a / (b * b)
        let c = 1 - (into ? -ddn : dot(tdir, normal))
        let Re = R0 + (1 - R0) * (c * c * c * c * c)
        let Tr = 1 - Re
        let P = 0.25 + 0.5 * Re
        let RP = Re / P
        let TP = Tr / (1 - P)

        return (Random.random() < P) ? (RP, reflect(wi, n: normal)) : (TP, tdir)
    }
}

struct Specular: Material {
    let emission: Color
    let color: Color

    func sample(wi: Vec, normal: Vec) -> (Scalar, Vec) {
        return (1.0, reflect(wi, n: normal))
    }
}

struct Lambertian: Material {
    let emission: Color
    let color: Color

    func sample(wi: Vec, normal: Vec) -> (Scalar, Vec) {
        // see: http://mathworld.wolfram.com/SpherePointPicking.html
        
        let r1 = 2 * Scalar(M_PI) * Random.next()
        let r2 = Random.next()
        let r2s = sqrt(r2)
        let w = dot(normal, wi) < 0 ? normal: normal * -1 // corrected normal (always exterior)
        let u = cross((fabs(w.x)>Scalar.epsilon ? Vec(0, 1, 0) : Vec(1, 0, 0)), w).norm()
        let v = cross(w, u)
        
        let d1 = u * cos(r1) * r2s
        let d = (d1 + v * sin(r1) * r2s + w * sqrt(1 - r2)).norm()

        // importance sampled (cosine weighted), doesn't need prob. correction
        return (1.0, d)
    }
}