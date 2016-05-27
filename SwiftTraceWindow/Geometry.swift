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
    let t = 2.0 * Scalar.Random() * Scalar(M_PI)
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

/// The object intersects with a ray, updating an intersection descriptor, and returns a boolean
protocol IntersectWithRayIntersection {
    func intersectWithRay(ray ray: RayPointer, hit: IntersectionPointer) -> Bool
}

protocol IntersectWithRayDistance {
    func intersectWithRay(ray: Ray) -> Scalar
}

protocol IntersectWithRayBoolean {
    func intersectWithRay(ray ray: RayPointer) -> Bool
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












