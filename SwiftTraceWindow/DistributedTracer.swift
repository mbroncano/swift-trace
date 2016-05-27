//
//  DistributedRayTracer.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/27/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

/*
// http://artis.inrialpes.fr/Enseignement/TRSA/CookDistributed84.pdf
class DistributedTracer: Renderer, RayTracer {
    let scene: Scene
    let framebuffer: Framebuffer

    init(scene:Scene, w: Int, h: Int) {
        self.scene = scene
        framebuffer = Framebuffer(width: w, height: h)
    }

    /// Iterative brute force ray tracing
    func radiance(ray ray: RayPointer, hit: IntersectionPointer) -> Color {
        var depth = 8
        var color = Color.White
        var r = ray.memory
        var hit = hit.memory
        
        while depth > 0 {
            hit.reset()

            /// Performs the intersection and checks both the object and the distance
            guard
                scene.root.intersectWithRay(r, hit: &hit),
                let mid = hit.m,
                let material = scene.materialWithId(mid)
                else {
                    color = color * scene.skyColor(r);
                    break
            }
                        
            // if the surface is emissive (i.e. does not have measurable albedo), just return the emission
            if material.isLight {
                color = color * material.emission
                break
            }
            
            // compute scatterred ray
            let wo: Vec
            let p: Scalar
            (p, wo) = material.sample(r.d, normal: hit.n)
            
            r = Ray(o: hit.x, d: wo)
            depth = depth - 1
            color = color * material.colorAtTextCoord(hit.uv) * p
        }
        
        return color
    }
}
*/