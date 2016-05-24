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

typealias MaterialId = String

class Material {
    let emission: Color
    let diffuseColor: Color

    init (emission: Color, color: Color) {
        self.emission = emission
        self.diffuseColor = color
    }

    func isLight() -> Bool { return emission != Vec.Zero }

    func sample(wi: Vec, normal: Vec) -> (Scalar, Vec) { return (0.0, Vec.Zero) }
    
    func colorAtTextCoord(uv: Vec) -> Color { return self.diffuseColor }
    func emissionAtTextCoord(uv: Vec) -> Color { return self.emission }
}

class Refractive: Material {
    let nc: Scalar = 1
    let nt: Scalar = 1.5

    override func sample(wi: Vec, normal: Vec) -> (Scalar, Vec) {
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

        return (Scalar.Random() < P) ? (RP, reflect(wi, n: normal)) : (TP, tdir)
    }
}

class Textured: Lambertian {
    var texture: Texture? = nil

    override init(emission: Color, color: Color) {
        super.init(emission: emission, color: color)
        
        let bundle = NSBundle.mainBundle()
        let fileName = bundle.pathForResource("earth", ofType: "jpg")!
        texture = Texture(fileName: fileName)
    }

    override func colorAtTextCoord(uv: Vec) -> Color {
        return texture![uv]
    }
}

class Chessboard: Specular {

    override func colorAtTextCoord(uv: Vec) -> Color {
        let squares = 20.0
        let t1 = uv.x * squares
        let t2 = uv.y * squares
        
        let c = Bool((Int(t1) % 2) ^ (Int(t2) % 2))
        return c ? (Color.White - diffuseColor) : self.diffuseColor
    }
}

class Specular: Material {
    let fuzz = 0.2

    override func sample(wi: Vec, normal: Vec) -> (Scalar, Vec) {
        // prob. of reflected ray is 1 (dirac function)
        return (1.0, reflect(wi, n: normal) + sampleSphere() * fuzz)
    }
}

class Lambertian: Material {
    override func sample(wi: Vec, normal: Vec) -> (Scalar, Vec) {
        // cosine weighted sampling
        // see: http://mathworld.wolfram.com/SpherePointPicking.html
        
        let r1 = 2 * Scalar(M_PI) * Scalar.Random()
        let r2 = Scalar.Random()
        let r2s = sqrt(r2)
        let w = dot(normal, wi) < 0 ? normal: normal * -1 // corrected normal (always exterior)
        let u = cross((fabs(w.x)>Scalar.epsilon ? Vec(0, 1, 0) : Vec(1, 0, 0)), w).norm()
        let v = cross(w, u)
        
        let d1 = u * cos(r1) * r2s
        let d = (d1 + v * sin(r1) * r2s + w * sqrt(1 - r2)).norm()

        return (1.0, d)
    }
}