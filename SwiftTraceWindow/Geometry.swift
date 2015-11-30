//
//  Geometry.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/19/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import simd

/// Result of an intersection
struct RayIntersection: Comparable {
    var dist: Scalar = Scalar.infinity
    var object: Geometry?
    
    /// Returns true is the intersection is valid
    var isValid:Bool { get { return dist.isNormal && object != nil } }
}

func == (a: RayIntersection, b: RayIntersection) -> Bool { return a.dist == b.dist }
func <  (a: RayIntersection, b: RayIntersection) -> Bool { return a.dist < b.dist }

/// Protocol to define a geometric intersecting object
protocol Geometry {
    var p: Vec { get }     // position
    var e: Vec { get }     // emission
    var c: Vec { get }     // color
    var refl: Refl_t { get }     // reflection type (DIFFuse, SPECular, REFRactive)
    
    /// Returns an optional intersection structure
    func intersect(r: Ray) -> RayIntersection?
}

/// Geometric collection of objects
struct GeometryList: Geometry {
    let list: [Geometry]
    let p, e, c: Vec      // position, emission, color
    let refl: Refl_t      // reflection type (DIFFuse, SPECular, REFRactive)

    func intersect(r: Ray) -> RayIntersection? { return list.flatMap{ $0.intersect(r) }.minElement() }
}

/// Geometric definition of a sphere
struct Sphere: Geometry {
    let rad: Scalar       // radius
    let p, e, c: Vec      // position, emission, color
    let refl: Refl_t      // reflection type (DIFFuse, SPECular, REFRactive)

    func intersect(r: Ray) -> RayIntersection? {
        let po = r.o - p
        let b = dot(r.d, po)
        let c = dot(po, po) - (rad * rad)
        let d = b*b - c

        if (d < 0) { return nil }
        
        let s = sqrt(d)
        let q = (b < 0) ? (-b-s) : (-b+s)
        let r = (q > Scalar.epsilon) ? q : 0
        
        if (r == 0) { return nil }
        
        return RayIntersection(dist: r, object: self)
    }
}
