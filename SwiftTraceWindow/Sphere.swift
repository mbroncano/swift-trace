//
//  Sphere.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/25/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

///////////////////////////////////////////////////////////////////////////////////////////////////////////
/// Geometric definition of a sphere
final class Sphere: Primitive {
    /// The radius of the sphere
    let rad: Scalar
    /// The center of the sphere
    let p: Vec
    /// Material identifier
    let material: MaterialId
    
    private let preArea: Scalar

    init(rad: Scalar, p: Vec, material: MaterialId) {
        self.rad = rad
        self.p = p
        self.material = material
        self.preArea = 4 * Scalar(M_PI) * (rad * rad)
        super.init(bbox: AABB(a: p - Vec(rad), b: p + Vec(rad)))
    }

    override var center: Vec { get { return p } }
    override var area: Scalar { get { return preArea } }
    override func sample() -> Vec { return self.p + sampleSphere(self.rad) }

    override func intersectWithRay(r: Ray, inout hit: Intersection) -> Bool {
        let po = r.o - p
        let b = dot(r.d, po)
        let c = dot(po, po) - (rad * rad)
        let t = b*b - c

        // if the determinant is negative, there are not solutions
        guard (t > 0) else { return false }
        
        let s = sqrt(t)
        let d = (b < 0) ? (-b-s) : (-b+s)

        // check that the distance fits the ray boundaries
        guard d > r.tmin && d < r.tmax else { return false }
        
        // note this, it's not the usual behaviour
        // do we want to return true is it's not the case?
        if (d < hit.d) {
            hit.p = self
            hit.d = d

            let x = r.o + r.d * d
            let n = normalize(x - p)
            let u = 0.5 + atan2(n.z, n.x) / (2.0 * Scalar(M_PI))
            let v = 0.5 - asin(n.y) / Scalar(M_PI)
            
            hit.x = x
            hit.m = material
            hit.n = n
            hit.uv = Vec(u, v, 0)
        }
        
        return true
    }
}

func == (lhs: Sphere, rhs: Sphere) -> Bool { return lhs.p == rhs.p && lhs.rad == rhs.rad && lhs.material == rhs.material }
