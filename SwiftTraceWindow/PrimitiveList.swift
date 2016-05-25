//
//  PrimitiveList.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/25/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation

///////////////////////////////////////////////////////////////////////////////////////////////////////////
/// Simple linear primitive list collection
final class PrimitiveList: Primitive {
    let list: [Primitive]
    
    init(nodes: [Primitive]) {
        list = nodes
        super.init(bbox: nodes.reduce(AABB()) { (box, node) -> AABB in
            return box + node.bbox
        })
    }

    override func intersectWithRay(r: Ray, inout hit: Intersection) -> Bool {
        guard bbox.intersectWithRay(r) else { return false }

        // only one positive intersect is needed to acknoledge the hit
        // but we need to traverse the list anyway to find the nearest primitive
        var result = false
        for n in list {
            guard n.intersectWithRay(r, hit: &hit) else { continue }
            result = true
        }
        
        return result
    }
}