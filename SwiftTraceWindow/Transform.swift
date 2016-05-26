//
//  Transform.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/25/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

///////////////////////////////////////////////////////////////////////////////////////////////////////////
/// Axis aligned bounding box

struct Transform {
    let transform: Matrix
    
    init(transform: Matrix) { self.transform = transform }
    
    init(translate t: Vec) { transform = Matrix([
        Row(1, 0, 0, t.x),
        Row(0, 1, 0, t.y),
        Row(0, 0, 1, t.z),
        Row(0, 0, 0, 1),
        ])
    }

    init(scale s: Vec) { transform = Matrix([
        Row(s.x, 0, 0, 0),
        Row(0, s.y, 0, 0),
        Row(0, 0, s.z, 0),
        Row(0, 0, 0, 1)])
    }

    init(rotate r: Vec) { transform = Matrix([
        Row(1, 0, 0, 0),
        Row(0, cos(r.x), -sin(r.x), 0),
        Row(0, sin(r.x), cos(r.x), 0),
        Row(0, 0, 0, 1)]) * Matrix([
        
        Row(cos(r.y), 0, sin(r.y), 0),
        Row(0, 1, 0, 0),
        Row(-sin(r.y), 0, cos(r.y), 0),
        Row(0, 0, 0, 1)]) * Matrix([
        
        Row(cos(r.z), -sin(r.z), 0, 0),
        Row(sin(r.z), cos(r.z), 0, 0),
        Row(0, 0, 1, 0),
        Row(0, 0, 0, 1)])
    }

    func apply(array: [Triangle]) -> [Triangle] {
        return array.map({ t in self.apply(t) })
    }
    
    func apply(t: Triangle) -> Triangle {
        let p1 = Vec(Col(t.p1.x, t.p1.y, t.p1.z, 1) * transform)
        let p2 = Vec(Col(t.p2.x, t.p2.y, t.p2.z, 1) * transform)
        let p3 = Vec(Col(t.p3.x, t.p3.y, t.p3.z, 1) * transform)
        
        return Triangle(p1, p2, p3, t.material, t.t1, t.t2, t.t3)
    }
}

/// Compose operation
func + (lhs:Transform, rhs: Transform) -> Transform { return Transform(transform: lhs.transform * rhs.transform) }
