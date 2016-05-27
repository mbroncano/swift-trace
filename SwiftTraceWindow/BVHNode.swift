//
//  BVHNode.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/25/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation

///////////////////////////////////////////////////////////////////////////////////////////////////////////
/// Bounding volume hierarchy node
final class BVHNode: Primitive {
    let left, right: Primitive

    // used only for debugging
    let pid: Int
    
    init(nodes: [Primitive], inout id: Int) {
        // random axis strategy
        let axis = Int(Scalar.Random() * 3.0)
        
        // debug
        self.pid = id
        id = id + 1
        
        let sorted = nodes.sort({ (a, b) -> Bool in return a.bbox.center[axis] > b.bbox.center[axis] })
        
        if sorted.count > 2 {
            let mid = sorted.count / 2
            left = BVHNode(nodes: [] + sorted[0..<mid], id: &id)
            right = BVHNode(nodes: [] + sorted[mid..<sorted.count], id: &id)
        } else {
            left = sorted[0]
            right = sorted[sorted.count - 1]
        }
        
        super.init(bbox: left.bbox + right.bbox)
    }

    override func intersectWithRay(r: Ray, inout hit: Intersection) -> Bool {
        hit.count += 1
        guard bbox.intersectWithRay(r) else { return false }

        let lbool = left.intersectWithRay(r, hit: &hit)
        let rbool = right.intersectWithRay(r, hit: &hit)
        
        return lbool || rbool
    }
}
