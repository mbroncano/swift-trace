//
//  RayTracer.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 12/23/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

class RayTracer {
    let scene: Scene
    let framebuffer: Framebuffer

    init(scene:Scene, w: Int, h: Int) {
        self.scene = scene
        framebuffer = Framebuffer(width: w, height: h)
    }

    /// Iterative brute force ray tracing
    func radiance(ray: Ray) -> Color {
        var depth = 5
        var color = Color.White
        var r = ray
        var hit = Intersection()
        
        while depth > 0 {
            /// Performs the intersection and checks both the object and the distance
            guard scene.list.intersectWithRay(r, hit: &hit), let obj = hit.o
                else { color = color * scene.skyColor(r); break }
            
            // if the surface is emissive (i.e. does not have measurable albedo), just return the emission
            let material: Material = obj.material
            if material.isLight() {
                color = color * material.emission
                break
            }
            
            // compute hitpoint, normal
            let x = r.o + r.d * hit.d           // hit point
            var n = obj.normalAtPoint(x)    // normal at hitpoint
            if (dot(r.d, n) > 0) {          // correct normal direction
                n = n * -1
            }
            
            // compute scatterred ray
            let wo: Vec
            (_, wo) = material.sample(r.d, normal: n)
            
            r = Ray(o: x, d: wo)
            depth = depth - 1
            color = color * obj.colorAtPoint(x)
            hit.d = Scalar.infinity
        }
        
        return color
    }

    func render() {
        framebuffer.samples += 1

        let nx = framebuffer.width
        let ny = framebuffer.height
        
        // process each ray in parallel
        dispatch_apply(nx*ny, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            // generate new ray
            let x = $0 % nx
            let y = ny - ($0 / nx) - 1
            let ray = self.scene.camera.generateRay(x: x, y: y, nx: nx, ny: ny)
            
            // compute and accumulate radiance for the ray
            let radiance = self.radiance(ray)
            self.framebuffer.ptr[$0] += radiance
        }
    }
}
