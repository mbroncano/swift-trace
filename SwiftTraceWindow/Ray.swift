//
//  Ray.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/25/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

/// Structure containing two vector, origin and destination
public struct Ray: CustomStringConvertible {
    /// The origin vector
    let o: Vec
    /// The destination vector
    let d: Vec
    /// The minimum distance this ray will travel
    var tmin: Scalar = Scalar.epsilon
    /// The maximum distance this ray will travel
    var tmax: Scalar = Scalar.infinity
    /// The reciprocate of the direction
    var inv: Vec
    
    init(o: Vec, d: Vec) { self.init(o: o, d: d, tmin: Scalar.epsilon, tmax: Scalar.infinity) }
    init(o: Vec, d: Vec, tmin: Scalar, tmax: Scalar) { self.o = o; self.d = d; self.tmin = tmin; self.tmax = tmax; self.inv = recip(d) }
    init(from: Vec, to: Vec) { let d = to-from; self.init(o: from, d: d.norm(), tmin: Scalar.epsilon, tmax: d.len()) }

    public var description: String { return "<(\(o.x),\(o.y),\(o.z))->(\(d.x),\(d.y),\(d.z))" }
}
public func * (a:Ray, b:Scalar) -> Vec { return a.o + a.d * b }
