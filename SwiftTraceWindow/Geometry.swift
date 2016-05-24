//
//  Geometry.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/19/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import simd

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
    let t = 2.0 * Scalar.Random() * M_PI
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

///////////////////////////////////////////////////////////////////////////////////////////////////////////

/// The result of an intersection with a ray
struct Intersection: Comparable {
    var m: MaterialId? = nil
    var d: Scalar = Scalar.infinity
    var x: Vec = Vec.Zero
    var n: Vec = Vec.Zero
    var uv: Vec = Vec.Zero
    
    mutating func reset() { m = nil; d = Scalar.infinity; x = Vec.Zero; n = Vec.Zero; uv = Vec.Zero }
}

func ==(lhs: Intersection, rhs: Intersection) -> Bool { return lhs.d == rhs.d }
func < (lhs: Intersection, rhs: Intersection) -> Bool { return lhs.d < rhs.d }

/// The object intersects with a ray, updating an intersection descriptor, and returns a boolean
protocol IntersectWithRayIntersection {
    func intersectWithRay(r: Ray, inout hit: Intersection) -> Bool
}

protocol IntersectWithRayDistance {
    func intersectWithRay(ray: Ray) -> Scalar
}

protocol IntersectWithRayBoolean {
    func intersectWithRay(ray: Ray) -> Bool
}

/// The object provides a bounding box
protocol BoundingBox {
    /// Bouding box
    var bbox: AABB { get }
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////

/// Axis aligned bounding box
struct AABB: IntersectWithRayBoolean {
    let min, max: Vec
    
    init(a: Vec, b: Vec) { min = a; max = b }

    init() { self.init(a: Vec.Zero, b: Vec.Zero) }

    func intersectWithRay(r: Ray) -> Bool {

        // Iterative version (test)
        /*
        for a in 0...2 {
            let inv = 1.0 / r.d[a]
            var t0 = (min[a] - r.o[a]) * inv
            var t1 = (max[a] - r.o[a]) * inv
            
            if (inv < 0) { swap(&t0, &t1) }
            let tmin = t0 > r.tmin ? t0 : r.tmin
            let tmax = t1 > r.tmax ? t1 : r.tmax
            if (tmax <= tmin) { return false }
        }
        return true
        */
    
        // SIMD version
        let inv = simd.recip(r.d)
        let t0 = (min - r.o) * inv
        let t1 = (max - r.o) * inv
        let tmin = simd.max(simd.min(t0, t1), r.tmin)
        let tmax = simd.min(simd.max(t0, t1), r.tmax)
        let s = simd.sign(tmax - tmin)
        return simd.reduce_min(s) > 0
    }
}

/// Union operator
func + (lhs:AABB, rhs: AABB) -> AABB {
    return AABB(a: min(lhs.min, rhs.min), b: max(lhs.max, rhs.max))
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////////////

/// Base geometric primitive
class Primitive: IntersectWithRayIntersection, BoundingBox {
    /// Axis aligned bounding box
    let bbox: AABB

    init(bbox: AABB) { self.bbox = bbox }
    
    func intersectWithRay(r: Ray, inout hit: Intersection) -> Bool { return bbox.intersectWithRay(r) }
}

/// Bounding volume hierarchy node
final class BVHNode: Primitive {
    let left, right: Primitive
    
    init(nodes: [Primitive]) {
        // random axis strategy
        let axis = Int(Scalar.Random() * 3.0)

        let sorted = nodes.sort({ (a, b) -> Bool in return a.bbox.min[axis] > b.bbox.min[axis] })
        
        if sorted.count > 2 {
            let mid = sorted.count / 2
            left = BVHNode(nodes: [] + sorted[0..<mid])
            right = BVHNode(nodes: [] + sorted[mid..<sorted.count])
        } else {
            left = sorted[0]
            right = sorted[sorted.count - 1]
        }
        
        super.init(bbox: left.bbox + right.bbox)
    }

    override func intersectWithRay(r: Ray, inout hit: Intersection) -> Bool {
        guard bbox.intersectWithRay(r) else { return false }

        let lbool = left.intersectWithRay(r, hit: &hit)
        let rbool = right.intersectWithRay(r, hit: &hit)
        
        return lbool || rbool
    }
}

/// Simple linear primitive list collection
final class PrimitiveList: Primitive {
    let list: [Primitive]
    
    init(nodes: [Primitive]) {
        list = nodes
        super.init(bbox: nodes.reduce(AABB()) { (box, node) -> AABB in
            return box + node.bbox
        })
    }

    override func intersectWithRay(r: Ray, inout hit: Intersection) -> Bool {
        guard bbox.intersectWithRay(r) else { return false }

        // only one positive intersect is needed to acknoledge the hit
        // but we need to traverse the list anyway to find the nearest primitive
        var result = false
        for n in list {
            guard n.intersectWithRay(r, hit: &hit) else { continue }
            result = true
        }
        
        return result
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////

/// Geometric definition of a sphere
final class Sphere: Primitive {
    /// The radius of the sphere
    let rad: Scalar
    /// The center of the sphere
    let p: Vec
    /// Material identifier
    let material: MaterialId

    init(rad: Scalar, p: Vec, material: MaterialId) {
        self.rad = rad
        self.p = p
        self.material = material
        super.init(bbox: AABB(a: p - Vec(rad), b: p + Vec(rad)))
    }

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
            hit.d = d

            let x = r.o + r.d * d
            let n = normalize(x - p)
            let u = 0.5 + atan2(n.z, n.x) / (2.0 * M_PI)
            let v = 0.5 - asin(n.y) / M_PI
            
            hit.x = x
            hit.m = material
            hit.n = n
            hit.uv = Vec(u, v, 0)
        }
        
        return true
    }
}
/*
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

    // TODO
    func textureAtPoint(x: Vec) -> Vec {
        return Vec()
    }
}
*/
