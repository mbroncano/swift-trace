//
//  Material.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/19/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import Cocoa
import simd

func cosineWeightedPdf(wo wo: Vec, normal: Vec) -> (Scalar, Vec) {
    let r1 = Scalar.pi2 * Scalar.Random()
    let r2 = Scalar.Random()
    let r2s = sqrt(r2)
    let w = dot(normal, wo) < 0 ? normal: normal * -1 // corrected normal (always exterior)
    let u = cross((fabs(w.x)>Scalar.epsilon ? Vec(0, 1, 0) : Vec(1, 0, 0)), w).norm()
    let v = cross(w, u)
    
    let d1 = u * cos(r1) * r2s
    let d = (d1 + v * sin(r1) * r2s + w * sqrt(1 - r2)).norm()
    
    return (1.0, d)
}

typealias MaterialId = Int
extension MaterialId {
    static let None = "__None".hashValue
}

protocol MaterialProtocol {
    var emission: Color { get }
    var isLight: Bool { get }
    func colorAtTextCoord(uv: Vec) -> Color
    func sample(wo wo: Vec, normal: Vec) -> (Scalar, Vec)
}

extension MaterialTemplate: MaterialProtocol {
    var emission: Color { get { return Ke } }
    var isLight: Bool { get { return emission != Vec.Zero } }
    
    // FIXME: implement texture support
    func colorAtTextCoord(uv: Vec) -> Color {
        return Kd
    }
    
    func sample(wo wo: Vec, normal: Vec) -> (Scalar, Vec) {
        let r1 = Scalar.pi2 * Scalar.Random()
        let r2 = Scalar.Random()
        let r2s = sqrt(r2)
        let w = dot(normal, wo) < 0 ? normal: normal * -1 // corrected normal (always exterior)
        let u = cross((fabs(w.x)>Scalar.epsilon ? Vec(0, 1, 0) : Vec(1, 0, 0)), w).norm()
        let v = cross(w, u)
        
        let d1 = u * cos(r1) * r2s
        let d = (d1 + v * sin(r1) * r2s + w * sqrt(1 - r2)).norm()

        return (1.0, d)
    }
}

class Material: MaterialProtocol {
    let emission: Color
    let diffuseColor: Color

    init (emission: Color, color: Color) throws {
        self.emission = emission
        self.diffuseColor = color
    }

    var isLight: Bool { get { return emission != Vec.Zero } }

    func sample(wo wo: Vec, normal: Vec) -> (Scalar, Vec) { return (0.0, Vec.Zero) }
    
    func colorAtTextCoord(uv: Vec) -> Color { return self.diffuseColor }
    func emissionAtTextCoord(uv: Vec) -> Color { return self.emission }
    /*
    // Phong model constants
    let Kd = 0.8
    let Ks = 0.2
    let Ns = 5.0

    func importance_sample(hit hit:IntersectionPointer, wo: Vec) -> (Scalar, Vec) {
        // Non uniform sample for the Phong model
        let u = Scalar.Random()
        let pdf: Scalar
        let wi: Vec
        if u < Kd {
            (pdf, wi) = cosineWeightedPdf(wo: wo, normal: hit.memory.n)
        } else if u < (Kd+Ks) {
            (pdf, wi) = (1.0, reflect(wo, n: hit.memory.n))
        } else {
            (pdf, wi) = (0.0, Vec.Zero)
        }
        
        return (pdf, wi)
    }

    func brdf(hit hit:IntersectionPointer, wo: Vec, wi: Vec) -> Color {
        // Phong model for GI (physically plausible)
        // fr(x,wi,wo) = frd(x,wi,wo) + frs(x,wi,wo) = Kd*(1/pi) + Ks*(n+2)/(2pi)*(cos(alpha)^n)
        // where Kd + Ks <= 1, n is the specular exponent and 
        // alpha the angle between wo and perfect reflection
        // alpha is clamped to (0, pi/2)
        
        let h = hit.memory
        let specular = reflect(wo, n: h.n)
        let cos_alpha = dot(wi, specular)
        let alpha_clamp = max(0, cos_alpha)
        let frd = Kd*M_1_PI
        let frs = Ks*(Ns+2)/(2*M_PI)*pow(alpha_clamp, Ns)
        
        return (frd + frs) * colorAtTextCoord(h.uv)
    }
    */
}

class Refractive: Material {
    let nc: Scalar = 1
    let nt: Scalar = 1.5

    override func sample(wo wo: Vec, normal: Vec) -> (Scalar, Vec) {
        let into: Bool
        let nl: Vec
        let nnt: Scalar
        
        // Adjust when the ray is inwards
        (nl, nnt, into) = dot(wo, normal) < 0 ? (normal, nc / nt, true) : (normal * -1, nt / nc, false)

        let ddn = dot(wo, nl)
        let cos2t = 1 - nnt * nnt * (1 - ddn * ddn)

        // Total internal reflection
        if (cos2t < 0) {
            return (1.0, reflect(wo, n: normal))
        }
        
        // Slick's approximation to Fresnel factor
        // https://en.wikipedia.org/wiki/Schlick%27s_approximation
        let t1 = (into ? 1 : -1) * (ddn * nnt + sqrt(cos2t))
        let tdir = normalize(wo * nnt - normal * t1)
        let a = nt - nc
        let b = nt + nc
        let R0 =  a * a / (b * b)
        let c = 1 - (into ? -ddn : dot(tdir, normal))
        let Re = R0 + (1 - R0) * (c * c * c * c * c)
        let Tr = 1 - Re
        let P = 0.25 + 0.5 * Re
        let RP = Re / P
        let TP = Tr / (1 - P)

        return (Scalar.Random() < P) ? (RP, reflect(wo, n: normal)) : (TP, tdir)
    }
}

class Textured: Lambertian {
    var texture: Texture? = nil

    init(name: String) throws {
        try super.init(emission: Vec.Zero, color: Color.White)
        
        texture = try Texture(name: name)
    }

    override func colorAtTextCoord(uv: Vec) -> Color {
        return texture![uv]
    }
}

class Chessboard: Specular {
    let squares: Scalar
    let white: Color
    let black: Color

    init(squares: Scalar = 20, white: Color = Color.White, black: Color = Color.Black) throws {
        self.squares = squares
        self.white = white
        self.black = black
        try super.init(emission: Vec.Zero, color: white)
    }

    override func colorAtTextCoord(uv: Vec) -> Color {
        let t1 = uv.x * squares
        let t2 = uv.y * squares
        
        let c = Bool((Int(t1) % 2) ^ (Int(t2) % 2))
        return c ? white : black
    }
}

class Specular: Material {
    let fuzz: Scalar = 0.2

    override func sample(wo wo: Vec, normal: Vec) -> (Scalar, Vec) {
        // prob. of reflected ray is 1 (dirac function)
        return (1.0, reflect(wo, n: normal) + sampleSphere() * fuzz)
    }
}

class Lambertian: Material {
    override func sample(wo wo: Vec, normal: Vec) -> (Scalar, Vec) {
        // cosine weighted sampling
        // see: http://mathworld.wolfram.com/SpherePointPicking.html
        
        let r1 = Scalar.pi2 * Scalar.Random()
        let r2 = Scalar.Random()
        let r2s = sqrt(r2)
        let w = dot(normal, wo) < 0 ? normal: normal * -1 // corrected normal (always exterior)
        let u = cross((fabs(w.x)>Scalar.epsilon ? Vec(0, 1, 0) : Vec(1, 0, 0)), w).norm()
        let v = cross(w, u)
        
        let d1 = u * cos(r1) * r2s
        let d = (d1 + v * sin(r1) * r2s + w * sqrt(1 - r2)).norm()

        return (1.0, d)
    }
}