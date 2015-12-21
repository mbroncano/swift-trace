//
//  Geometry.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/19/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import simd

/// Protocol to define a geometric intersecting object
protocol Geometry {
    var p: Vec { get }     // position
    var material: String { get }

    /// Returns an optional intersection structure
    func intersectWithRay(r: Ray) -> Scalar
    func normalAtPoint(x: Vec) -> Vec
}

protocol Intersectable {
    func intersectsWithRay(ray: Ray, inout distance: Scalar) -> Bool
}

/// Geometric collection of objects
struct GeometryList {
    let list: [Geometry]

    func intersect(r: Ray) -> (Geometry?, Scalar) {
        var ret: Geometry?
        var current: Scalar = Scalar.infinity
        
        for object in list {
            let distance = object.intersectWithRay(r)
            if distance < current { ret = object; current = distance }
        }
        
        // TODO: refactor this
        if ret != nil { return (ret, current) } else { return (nil, current) }
    }
}

/// Geometric definition of a sphere
struct Sphere: Geometry {
    let rad: Scalar         // radius
    let p: Vec              // position
    let material: String  // surface type

    func intersectWithRay(r: Ray) -> Scalar {
        let po = r.o - p
        let b = dot(r.d, po)
        let c = dot(po, po) - (rad * rad)
        let d = b*b - c

        // If the determinant is negative, there are not solutions
        if (d < 0) { return Scalar.infinity }
        
        let s = sqrt(d)
        let q = (b < 0) ? (-b-s) : (-b+s)
        let t = (q > Scalar.epsilon) ? q : 0
        
        if (t == 0) { return Scalar.infinity }
        
        return t
    }
    
    func normalAtPoint(x: Vec) -> Vec {
        return normalize(x - p)
    }
}

struct Triangle {
    let p1, p2, p3: Vec
    let edge1, edge2: Vec
    let normal: Vec
    
    init(p1:Vec, p2:Vec, p3: Vec) {
        self.p1 = p1
        self.p2 = p2
        self.p3 = p3
    
        // compute edges, normal
        edge1 = p2 - p1
        edge2 = p3 - p2
        normal = normalize(cross(edge1, edge2))
    }
    
    func intersectWithRay(r: Ray) -> Scalar {
        /* Compute some initial values. */
        let distance: Vec = r.o - p1;
        let s: Vec = cross(r.d, edge2)
        let d: Scalar = 1.0 / dot(s, edge1);

        /* Calculate the first barycentric coordinate. */
        let u: Scalar = dot(distance, s) * d;

        /* Reject the intersection if the barycentric coordinate is out of range. */
        if ((u <= -Scalar.epsilon) || (u >= 1 + Scalar.epsilon)) { return Scalar.infinity }

        /* Calculate the second barycentric coordinate. */
        let t = cross(distance, edge1)
        let v: Scalar = dot(r.d, t) * d

        /* Reject the intersection if the barycentric coordinate is out of range. */
        if ((v <= -Scalar.epsilon) || (u + v >= 1 + Scalar.epsilon)) { return Scalar.infinity }

        /* Compute the final intersection point. */
        return dot(edge2, t) * d
    }
}

