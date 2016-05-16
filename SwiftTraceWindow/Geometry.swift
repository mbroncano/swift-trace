//
//  Geometry.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/19/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import simd

/// Protocol to define a geometric primitive
protocol Geometry {
    /// Material surface
    var material: Material { get }

    /// Intersects with a ray, returns distance or infinity
    func intersectWithRay(r: Ray) -> Scalar
    
    /// Normal vector at a point over the surface
    func normalAtPoint(x: Vec) -> Vec
    
    /// Returns a random point over the surface
    func sampleSurface() -> Vec
}

/// Geometric collection of objects
typealias GeometryCollectionItemId = Int
extension GeometryCollectionItemId {
    static var invalid = -1
    
    var isValid: Bool { get { return self > 0 } }
}

/// Protocol to define a geometric primitive collection
protocol GeometryCollection {
    /// Items in teh collection
    var items: [Geometry] { get }

    /// Returns an item with a particular id
    subscript(id: GeometryCollectionItemId) -> Geometry? { get }

    /// Returns the first instance in the collection that intersectes with a ray and the distance
    func intersectWithRay(r: Ray) -> (GeometryCollectionItemId, Scalar)
}

struct GeometryList: GeometryCollection {
    let items: [Geometry]

    func intersectWithRay(r: Ray) -> (GeometryCollectionItemId, Scalar) {
        /*
        // Functional approach, funnily enough is slower than the trivial one
        return (0..<list.count).lazy.reduce((GeometryListId.invalid, Scalar.infinity)) {
            accum, id in
            let distance = list[id].intersectWithRay(r)
            return (distance < accum.1) ? (id, distance) : accum
        }
        */
    
        var ret = (id: GeometryCollectionItemId(), dist: Scalar.infinity)
        for index in 0..<items.count {
            let distance = items[index].intersectWithRay(r)
            if distance < ret.dist {
                ret = (index, distance)
            }
        }
        
        return ret
    }
    
    subscript(id: GeometryCollectionItemId) -> Geometry? { return items[id] }
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

