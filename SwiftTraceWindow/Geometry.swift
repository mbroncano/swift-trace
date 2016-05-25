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
    weak var p: Primitive? = nil
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

/// Defines a surfaced object
protocol Surface {
    /// Returns the geometric center of the surface
    var center: Vec { get }
    /// Returns the area of the surface
    var area: Scalar { get }
    /// Returns a random point on the surface
    func sample() -> Vec
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////
/// Axis aligned bounding box
struct AABB: IntersectWithRayBoolean, Surface, Equatable {
    let min, max: Vec
    private let preArea: Scalar
    private let preCenter: Vec
    
    init(a: Vec, b: Vec) {
        self.min = a
        self.max = b
        let d = max - min
        self.preCenter = min + d * 0.5
        self.preArea = 2.0 * (d.x * d.y + d.x * d.z + d.y + d.z)
    }

    init() { self.init(a: Vec.Zero, b: Vec.Zero) }

    var center: Vec { get { return preCenter } }
    var area: Scalar { get { return preArea } }

    // TODO
    func sample() -> Vec { return self.center }

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
        return simd.reduce_min(s) >= 0
    }
}

func == (lhs:AABB, rhs:AABB) -> Bool { return lhs.min == rhs.min && lhs.max == rhs.max }
func + (lhs:AABB, rhs: AABB) -> AABB { return AABB(a: min(lhs.min, rhs.min), b: max(lhs.max, rhs.max)) }


///////////////////////////////////////////////////////////////////////////////////////////////////////////
/// Base geometric primitive
class Primitive: IntersectWithRayIntersection, BoundingBox, Surface, Equatable {
    /// Axis aligned bounding box
    let bbox: AABB

    init(bbox: AABB) { self.bbox = bbox }
    
    func intersectWithRay(r: Ray, inout hit: Intersection) -> Bool { return bbox.intersectWithRay(r) }
    var center: Vec { get { return bbox.center } }
    var area: Scalar { get { return bbox.area } }
    func sample() -> Vec { return bbox.sample() }
}

func == (lhs:Primitive, rhs:Primitive) -> Bool { return lhs.bbox == rhs.bbox }


///////////////////////////////////////////////////////////////////////////////////////////////////////////
/// Bounding volume hierarchy node
final class BVHNode: Primitive {
    let left, right: Primitive

    // used only for debuggin
    let pid: Int
    
    init(nodes: [Primitive], inout id: Int) {
        // random axis strategy
        let axis = Int(Scalar.Random() * 3.0)
        self.pid = id

        let sorted = nodes.sort({ (a, b) -> Bool in return a.bbox.center[axis] > b.bbox.center[axis] })
        
        if sorted.count > 2 {
            let mid = sorted.count / 2
            id = id + 1
            left = BVHNode(nodes: [] + sorted[0..<mid], id: &id)
            id = id + 1
            right = BVHNode(nodes: [] + sorted[mid..<sorted.count], id: &id)
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


///////////////////////////////////////////////////////////////////////////////////////////////////////////
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
    
    private let preArea: Scalar

    init(rad: Scalar, p: Vec, material: MaterialId) {
        self.rad = rad
        self.p = p
        self.material = material
        self.preArea = 4 * M_PI * (rad * rad)
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

func == (lhs: Sphere, rhs: Sphere) -> Bool { return lhs.p == rhs.p && lhs.rad == rhs.rad && lhs.material == rhs.material }

///////////////////////////////////////////////////////////////////////////////////////////////////////////
/// Geometric definition of a triangle
final class Triangle: Primitive {
    let p1, p2, p3: Vec
    let edge1, edge2: Vec
    let normal: Vec

    /// Material identifier
    let material: MaterialId

    // TODO: precompute center
    override var center: Vec { get { return (edge2 + edge1) * 0.5 } }
    // same as bbox
//    override var area: Scalar { get { return edge1.len() * edge2.len() * 2.0 } }

    init(p1:Vec, p2:Vec, p3: Vec, material: MaterialId) {
        self.p1 = p1
        self.p2 = p2
        self.p3 = p3
        
        self.material = material
    
        // find vectors for two edges sharing V1
        edge1 = p2 - p1
        edge2 = p3 - p1
        normal = normalize(cross(edge1, edge2))
        
        // compute bounding box
        let _min = min(min(p1, p2), min(p2, p3))
        let _max = max(max(p1, p2), max(p2, p3))
        super.init(bbox: AABB(a: _min, b: _max))
    }
    
    /// https://en.wikipedia.org/wiki/Möller–Trumbore_intersection_algorithm
    override func intersectWithRay(r: Ray, inout hit: Intersection) -> Bool {
        // begin calculating determinant - also used to calculate u parameter
        let p = cross(r.d, edge2)
        
        // if determinant is near zero, ray lies in plane of triangle
        let det = dot(edge1, p)
        
        // NOT CULLING
        if (det > -Scalar.epsilon && det < Scalar.epsilon) { return false }

        let inv_det = 1.0 / det;

        //calculate distance from V1 to ray origin
        let t = r.o - p1
        //Calculate u parameter and test bound
        let u = dot(t, p) * inv_det

        //The intersection lies outside of the triangle
        if (u < 0.0 || u > 1.0) { return false }

        //Prepare to test v parameter
        let q = cross(t, edge1)

        //Calculate V parameter and test bound
        let v = dot(r.d, q) * inv_det;
        //The intersection lies outside of the triangle
        if (v < 0.0 || u + v  > 1.0) { return false }

        let t1 = dot(edge2, q) * inv_det;

        if (t1 > Scalar.epsilon) { //ray intersection
            if (t1 < hit.d) {
                hit.p = self
                hit.d = t1
                
                let x = r.o + r.d * t1
                
                hit.x = x
                hit.m = material
                hit.n = normal
                hit.uv = Vec(u, v, 0)
            }
            return true
        }

        // No hit, no win
        return false
    }
    /*
    override func intersectWithRay(r: Ray, inout hit: Intersection) -> Bool {

        // find vectors for two edges sharing p1
        // let edge1 = p2 - p1
        // let edge2 = p3 - p1

        // compute some initial values
        let distance: Vec = r.o - p1
        let s: Vec = cross(r.d, edge2)
        let d: Scalar = simd.recip(dot(s, edge1))

        // calculate the first barycentric coordinate
        let u: Scalar = dot(distance, s) * d;

        // reject the intersection if the barycentric coordinate is out of range
        guard u <= -Scalar.epsilon || u >= (1 + Scalar.epsilon) else { return false }

        // calculate the second barycentric coordinate
        let t: Vec = cross(distance, edge1)
        let v: Scalar = dot(r.d, t) * d

        // reject the intersection if the barycentric coordinate is out of range
        guard v <= -Scalar.epsilon || (u + v) >= (1 + Scalar.epsilon) else { return false }

        // compute the final intersection point
        let dist: Scalar = dot(edge2, t) * d
        
        if (dist < hit.d) {
            hit.p = self
            hit.d = dist

            let x = r.o + r.d * dist
            
            hit.x = x
            hit.m = material
            hit.n = normal
            hit.uv = Vec(u, v, 0)
        }
        
        return true
    }
    */
    /*
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
    }*/
}

