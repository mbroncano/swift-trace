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
    weak var p: Primitive? = nil
    var m: MaterialId? = nil
    var d: Scalar = Scalar.infinity
    var x: Vec = Vec.Zero
    var n: Vec = Vec.Zero
    var uv: Vec = Vec.Zero
    // debug
    var count: Int = 0
    
    mutating func reset() { m = nil; d = Scalar.infinity; x = Vec.Zero; n = Vec.Zero; uv = Vec.Zero }
}

func ==(lhs: Intersection, rhs: Intersection) -> Bool { return lhs.d == rhs.d }
func < (lhs: Intersection, rhs: Intersection) -> Bool { return lhs.d < rhs.d }
