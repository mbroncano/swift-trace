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
struct Intersection {
    var o: Geometry? = nil
    var d: Scalar = Scalar.infinity
    //var m: Material? = nil
}


/// The object provides intersection with ray primitive
protocol IntersecableWithRay {
    var bbox: AABB { get }

    func intersectWithRay(r: Ray, inout hit: Intersection) -> Bool
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////

/// The object provides a surface
protocol Surface {
    /// Surface material
    var material: Material { get }
    
    /// Normal vector at a point over the surface
    func normalAtPoint(x: Vec) -> Vec

    /// Color at a point over the surface
    func colorAtPoint(x: Vec) -> Color
    
    /// Emission at a point over the surface
    func emissionAtPoint(x: Vec) -> Color
    
    /// Returns a random point over the surface
    func sampleSurface() -> Vec

    /// Texture coordinates for a point on the surface
    func textureAtPoint(x: Vec) -> Vec
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////

class AABB: IntersecableWithRay {
    let min, max: Vec
    var bbox: AABB { get { return self } }
    
    init(a: Vec, b: Vec) { min = a; max = b }
    
    func intersectWithRay(r: Ray, inout hit: Intersection) -> Bool {
      /*  for a in 0...2 {
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
    
        let inv = simd.recip(r.d)
        let t0 = (min - r.o) * inv
        let t1 = (max - r.o) * inv
        let tmin = simd.max(simd.min(t0, t1), r.tmin)
        let tmax = simd.min(simd.max(t0, t1), r.tmax)
        let s = simd.sign(tmax - tmin)
        return simd.reduce_min(s) > 0
    }
}

func + (lhs:AABB, rhs: AABB) -> AABB {
    return AABB(a: min(lhs.min, rhs.min), b: max(lhs.max, rhs.max))
}

class BVHNode: IntersecableWithRay {
    let left: IntersecableWithRay
    let right: IntersecableWithRay
    let bbox: AABB
    
    init(nodes: [Geometry]) {
        // choose a random axis
        let axis = Int(Scalar.Random() * 3.0)

        let sorted = nodes.sort({ (a, b) -> Bool in
            if axis == 0 {
                return a.bbox.min.x > b.bbox.min.x
            } else if axis == 1 {
                return a.bbox.min.y > b.bbox.min.y
            } else {
                return a.bbox.min.z > b.bbox.min.z
            }
        })
        
        let count = sorted.count
        
        if count == 1 {
            left = sorted[0]
            right = sorted[0]
        } else if count == 2 {
            left = sorted[0]
            right = sorted[1]
        } else {
            let mid = count / 2
            left = BVHNode(nodes: [] + sorted[0..<mid])
            right = BVHNode(nodes: [] + sorted[mid..<count])
        }
        
        bbox = AABB(a: min(left.bbox.min, right.bbox.min), b: max(left.bbox.max, right.bbox.max))
    }
    
    func intersectWithRay(r: Ray, inout hit: Intersection) -> Bool {
        if bbox.intersectWithRay(r, hit: &hit) {
            var lhit = Intersection()
            var rhit = Intersection()
        
            let lbool = left.intersectWithRay(r, hit: &lhit)
            let rbool = right.intersectWithRay(r, hit: &rhit)
            
            if (lbool && rbool) {
                if lhit.d < rhit.d {
                    hit = lhit
                } else {
                    hit = rhit
                }

                return true
            } else if lbool {
                hit = lhit
                return true
            } else if rbool {
                hit = rhit
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }

}

///////////////////////////////////////////////////////////////////////////////////////////////////////////


protocol Geometry: Surface, IntersecableWithRay { }

/// Geometric collection of objects
/*
typealias GeometryCollectionItemId = Int
extension GeometryCollectionItemId {
    static var invalid = -1
    
    var isValid: Bool { get { return self > 0 } }
}*/

/// Protocol to define a geometric primitive collection
protocol GeometryCollection {
    /// Items in teh collection
    var items: [Geometry] { get }

    /// Returns an item with a particular id
//    subscript(id: GeometryCollectionItemId) -> Geometry? { get }

    /// Returns the first instance in the collection that intersectes with a ray and the distance
    //func intersectWithRay(r: Ray) -> (GeometryCollectionItemId, Scalar)

    func intersectWithRay(r: Ray) -> Intersection
}

class GeometryList: GeometryCollection, IntersecableWithRay {
    // FIXME
    let bbox: AABB = AABB(a: Vec.Zero, b: Vec.Zero)
    let items: [Geometry]
    
    init(items:[Geometry]) { self.items = items }

    // Deprecated!!
    func intersectWithRay(r: Ray) -> Intersection {
        var ret = Intersection()
        var tmp = Intersection()
        
        for object in items {
            if object.intersectWithRay(r, hit: &tmp) {
                if tmp.d < ret.d {
                    ret = tmp
                }
            }
        }
        return ret
    }

    func intersectWithRay(r: Ray, inout hit: Intersection) -> Bool {
        var tmp = Intersection()
        
        for object in items {
            if object.intersectWithRay(r, hit: &tmp) {
                if tmp.d < hit.d {
                    hit = tmp
                }
            }
        }
        return tmp.d.isFinite
    }
    
    
/*
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
  */
  /*
    subscript(id: GeometryCollectionItemId) -> Geometry? {
        guard items.indices ~= id else { return nil }
        return items[id]
    }*/
}

/// Geometric definition of a sphere
class Sphere: Geometry {
    let rad: Scalar         // radius
    let p: Vec              // position
    let material: Material  // surface type
    let bbox: AABB          // axis-aligned bounding box

    init(rad: Scalar, p: Vec, material: Material) {
        self.rad = rad
        self.p = p
        self.material = material
        self.bbox = AABB(a: p - Vec(rad), b: p + Vec(rad))
    }

    func intersectWithRay(r: Ray, inout hit: Intersection) -> Bool {
        let po = r.o - p
        let b = dot(r.d, po)
        let c = dot(po, po) - (rad * rad)
        let t = b*b - c

        // If the determinant is negative, there are not solutions
        guard (t > 0) else { return false }
        
        let s = sqrt(t)
        let d = (b < 0) ? (-b-s) : (-b+s)

        // Check that the distance is bigger than epsilon
        guard (d > Scalar.epsilon) else { return false }
        
        hit.o = self
        hit.d = d
        
        return true
    }
    
    func textureAtPoint(x: Vec) -> Vec {
        var n = normalAtPoint(x)
        let u = 0.5 + atan2(n.z, n.x) / (2.0 * M_PI)
        let v = 0.5 - asin(n.y) / M_PI
        
        return Vec(u, v, 0)
    }
    
    func colorAtPoint(x: Vec) -> Color {
        let uv = textureAtPoint(x)
        return material.colorAtTextCoord(uv)
    }

    func emissionAtPoint(x: Vec) -> Color {
        let uv = textureAtPoint(x)
        return material.emissionAtTextCoord(uv)
    }
    
    func normalAtPoint(x: Vec) -> Vec {
        return normalize(x - p)
    }
    
    func sampleSurface() -> Vec {
        return p + sampleSphere(rad)
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
