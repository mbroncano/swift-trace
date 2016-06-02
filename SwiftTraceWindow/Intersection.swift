//
//  Intersection.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/25/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation

///////////////////////////////////////////////////////////////////////////////////////////////////////////
/// The result of an intersection with a ray

struct Intersection: Comparable {
    /// Weak reference to the primitive
    weak var p: Primitive? = nil
    /// Pointer to the material of the surface
    var m: MaterialId = MaterialId.None
    /// Distance
    var d: Scalar = Scalar.infinity
    /// Intersection point
    var x: Vec = Vec.Zero
    /// Normal at the intersection point
    var n: Vec = Vec.Zero
    /// Parametric coordinates on the surface at the intersection point
    var uv: Vec = Vec.Zero
    // debug
    var count: Int = 1
    
    
    /// Resets the intersection to the default values
    mutating func reset() { m = MaterialId.None; d = Scalar.infinity; x = Vec.Zero; n = Vec.Zero; uv = Vec.Zero }
}

func ==(lhs: Intersection, rhs: Intersection) -> Bool { return lhs.d == rhs.d }
func < (lhs: Intersection, rhs: Intersection) -> Bool { return lhs.d < rhs.d }
