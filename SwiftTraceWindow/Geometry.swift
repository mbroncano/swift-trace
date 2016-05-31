//
//  Geometry.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/19/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import simd

/// The object intersects with a ray, updating an intersection descriptor, and returns a boolean
protocol IntersectWithRayIntersection {
    func intersectWithRay(ray ray: RayPointer, hit: IntersectionPointer) -> Bool
}

/// The object intersects with a ray, returning the distance or infinity
protocol IntersectWithRayDistance {
    func intersectWithRay(ray ray: RayPointer) -> Scalar
}

/// The object intersects with a ray, returning a boolean
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












