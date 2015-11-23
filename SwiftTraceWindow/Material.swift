//
//  Material.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/19/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

enum Refl_t { case DIFF; case SPEC; case REFR }  // material types, used in radiance()

protocol Material {
    func brdf(normal: Vec, light: Vec) -> Vec
}

struct Lambertian: Material {
    let color: Color

    func brdf(normal: Vec, light: Vec) -> Vec {
        let cos = dot(normal, light)
        
        return color * max(0, cos)
    }
}