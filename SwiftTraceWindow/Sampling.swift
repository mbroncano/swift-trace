//
//  Sampling.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/28/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

/////////////////////////////////////////////////
// FIXME: There's a lot to look into here
/////////////////////////////////////////////////

func uniformSampleHemiSphere(r1: Scalar, r2: Scalar) -> (Vec, Scalar) {
    let z = r1
    let r = sqrt(max(0, 1-z*z))
    let phi = Scalar.pi2 * r2
    let x = r * cos(phi)
    let y = r * sin(phi)
    
    return (Vec(x, y, z), 1 / Scalar.pi2)
}

func uniformSampleSphere(r1: Scalar, r2: Scalar) -> (Vec, Scalar) {
    let z = 1 - 2 * r1
    let r = sqrt(max(0, 1-z*z))
    let phi = Scalar.pi2 * r2
    let x = r * cos(phi)
    let y = r * sin(phi)
    
    return (Vec(x, y, z), 1 / Scalar.pi4)
}

/// Sample a point over the surface of a sphere, rejection method
// FIXME: Is this correct?
func sampleSphere(r: Scalar = 1.0) -> Vec {
    var v: Vec
    repeat {
        v = 2.0 * Vec(Scalar.Random(), Scalar.Random(), Scalar.Random()) - Vec.Unit
    } while (simd.length(v) >= 1.0)
    
    return v * r
}

/// Another sphere sample, trigonometry method
func sampleSphere2() -> Vec {
    let z = 2.0 * Scalar.Random() - 1.0
    let t = 2.0 * Scalar.Random() * Scalar.pi
    let r = sqrt(1.0 - z * z)
    let x = r * cos(t)
    let y = r * sin(t)
    
    return Vec(x, y, z)
}

/// Sample point in unit disk
func sampleDisk() -> Vec {
    var v: Vec
    repeat {
        v = 2.0 * Vec(Scalar.Random(), Scalar.Random(), 0) - Vec.XY
    } while (v.dot(v) >= 1.0)
    return v
}