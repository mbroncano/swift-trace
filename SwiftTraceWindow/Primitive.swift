//
//  Primitive.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/25/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation

///////////////////////////////////////////////////////////////////////////////////////////////////////////
/// Base geometric primitive

class Primitive: IntersectWithRayIntersection, IntersectWithRayBoolean, IntersectWithRayDistance, BoundingBox, Surface, Equatable {
    /// Axis aligned bounding box
    let bbox: AABB
    /// Material identifier
    let material: MaterialId?

    convenience init(bbox: AABB) { self.init(bbox: bbox, material: nil) }
    init(bbox: AABB, material: MaterialId?) {
        self.bbox = bbox; self.material = material
    }
    
    func intersectWithRay(ray ray: RayPointer) -> Scalar { return bbox.intersectWithRay(ray: ray) }
    func intersectWithRay(ray ray: RayPointer) -> Bool { return intersectWithRay(ray: ray) != Scalar.infinity }
    // FIXME: this should return some kind of exception
    // another option would be to make aabb the base class
    // could we *not* have a base class?
    func intersectWithRay(ray ray: RayPointer, hit: IntersectionPointer) -> Bool { return self.intersectWithRay(ray: ray) }
    var center: Vec { get { return bbox.center } }
    var area: Scalar { get { return bbox.area } }
    func sample() -> Vec { return bbox.sample() }
}

func == (lhs:Primitive, rhs:Primitive) -> Bool { return lhs.bbox == rhs.bbox }
