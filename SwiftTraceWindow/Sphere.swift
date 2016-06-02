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
    
    private let preArea: Scalar

    init(rad: Scalar, p: Vec, material: MaterialId) {
        self.rad = rad
        self.p = p
        self.preArea = Scalar.pi4 * (rad * rad)
        super.init(bbox: AABB(a: p - Vec(rad), b: p + Vec(rad)), material: material)
    }

    override var center: Vec { get { return p } }
    override var area: Scalar { get { return preArea } }
    override func sample() -> Vec { return self.p + sampleSphere(self.rad) }

    override func intersectWithRay(ray ray: RayPointer) -> Scalar {
        let po = ray.memory.o - p
        let b = dot(ray.memory.d, po)
        let c = dot(po, po) - (rad * rad)
        let t = b*b - c

        // if the determinant is negative, there are not solutions
        guard (t > 0) else { return Scalar.infinity }
        
        let s = sqrt(t)
        let d = (b < 0) ? (-b-s) : (-b+s)

        // check that the distance fits the ray boundaries
        guard d > ray.memory.tmin && d < ray.memory.tmax else { return Scalar.infinity }
    
        return d
    }
    
    override func intersectWithRay(ray ray: RayPointer, hit: IntersectionPointer) -> Bool {
        let d: Scalar = intersectWithRay(ray: ray)
    
        if (d < hit.memory.d) {
            hit.memory.p = self
            hit.memory.d = d

            let x = ray.memory.o + ray.memory.d * d
            let n = normalize(x - p)
            let u = 0.5 + atan2(n.z, n.x) / Scalar.pi2
            let v = 0.5 - asin(n.y) / Scalar.pi
            
            hit.memory.x = x
            hit.memory.m = material!
            hit.memory.n = n
            hit.memory.uv = Vec(u, v, 0)
        }
        
        return d != Scalar.infinity
    }
}

//func == (lhs: Sphere, rhs: Sphere) -> Bool { return lhs.p == rhs.p && lhs.rad == rhs.rad && lhs.material == rhs.material }
