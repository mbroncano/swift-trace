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
