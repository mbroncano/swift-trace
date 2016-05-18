//
//  Random.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 12/1/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation

/// Random number generator
struct Random {
    static let pbuffer = UnsafeMutablePointer<UInt16>.alloc(3)
    
    static func seed(a : UInt16) {
        pbuffer[2] = a
    }

    static func next() -> Scalar {
        return Scalar(erand48(pbuffer))
    }
    
    static func random() -> Scalar {
        return Scalar(drand48())
    }
}

extension Scalar {
    static func Random() -> Scalar { return Scalar(drand48()) }
}

extension Vec {
    static func Random() -> Vec {
        return Vec(Scalar.Random(), Scalar.Random(), Scalar.Random())
    }
}