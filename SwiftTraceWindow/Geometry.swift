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
    var material: Material { get }

    func intersectWithRay(r: Ray) -> Scalar
    func normalAtPoint(x: Vec) -> Vec
    func sampleSurface() -> Vec
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
class Sphere: Geometry {
    let rad: Scalar         // radius
    let p: Vec              // position
    let material: Material  // surface type

    init(rad: Scalar, p: Vec, material: Material) {
        self.rad = rad
        self.p = p
        self.material = material
    }

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
    
    func sampleSurface() -> Vec {
        var v: Vec
        
        repeat {
            v = Vec(Random.random(), Random.random(), Random.random()) * 2 - Vec.Unit
        } while (length(v) > 1)
        
        return p + normalize(v)
    }
}

class Triangle: Geometry {
    let p1, p2, p3: Vec
    let edge1, edge2: Vec
    let normal: Vec

    let material: Material  // surface type

    init(p1:Vec, p2:Vec, p3: Vec, material: Material) {
        self.p1 = p1
        self.p2 = p2
        self.p3 = p3
        
        self.material = material
    
        //Find vectors for two edges sharing V1
        edge1 = p2 - p1
        edge2 = p3 - p1
        normal = normalize(cross(edge1, edge2))
    }
    
    /// https://en.wikipedia.org/wiki/Möller–Trumbore_intersection_algorithm
    func intersectWithRay(r: Ray) -> Scalar {
        //Begin calculating determinant - also used to calculate u parameter
        let p = cross(r.d, edge2)
        //if determinant is near zero, ray lies in plane of triangle
        let det = dot(edge1, p)
        // NOT CULLING
        if (det > -Scalar.epsilon && det < Scalar.epsilon) { return Scalar.infinity }

        let inv_det = 1.0 / det;

        //calculate distance from V1 to ray origin
        let t = r.o - p1
        //Calculate u parameter and test bound
        let u = dot(t, p) * inv_det

        //The intersection lies outside of the triangle
        if (u < 0.0 || u > 1.0) { return Scalar.infinity }

        //Prepare to test v parameter
        let q = cross(t, edge1)

        //Calculate V parameter and test bound
        let v = dot(r.d, q) * inv_det;
        //The intersection lies outside of the triangle
        if (v < 0.0 || u + v  > 1.0) { return Scalar.infinity }

        let t1 = dot(edge2, q) * inv_det;

        if (t1 > Scalar.epsilon) { //ray intersection
            return t1
        }

        // No hit, no win
        return Scalar.infinity
    }

    func intersectWithRay2(r: Ray) -> Scalar {

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

    func normalAtPoint(x: Vec) -> Vec {
        return normal
    }
    
    func sampleSurface() -> Vec {
        let r1 = Random.random()
        let r2 = Random.random()
        
        let p = (1 - sqrt(r1)) * p1 + (sqrt(r1) * (1 - r2)) * p2 + (r2 * sqrt(r1)) * p3
        
        return p
    }

}

