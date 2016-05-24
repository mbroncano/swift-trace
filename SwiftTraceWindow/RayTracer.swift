//
//  RayTracer.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 12/23/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

/// Implements a ray tracer
protocol RayTracer {
    func radiance(r: Ray) -> Color
}

/// Implements a generic scene renderer
protocol Renderer {
    var scene: Scene { get }
    var framebuffer: Framebuffer { get }
    
    func render()
    func renderTile()
}

extension Renderer where Self: RayTracer {
    /// Renders a frame, dispatching pixels
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
    
    /// Renders a frame, dispatching tiles
    func renderTile() {
        framebuffer.samples += 1

        let nx = framebuffer.width
        let ny = framebuffer.height
        
        let size = 512                   // seems to be fair
        let tx = (nx + size - 1) / size // int div round up
        let ty = (ny + size - 1) / size
        
        // process each ray in parallel, tiled
        dispatch_apply(tx*ty, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let x = ($0 % tx) * size
            let y = ($0 / tx) * size

            let sizex = min((nx-x), size)
            let sizey = min((ny-y), size)

            for i in 0..<sizex*sizey {
                let xi = x + (i % sizex)
                let yi = y + (i / sizex)
                let ray = self.scene.camera.generateRay(x: xi, y: yi, nx: nx, ny: ny)
                let radiance = self.radiance(ray)
                self.framebuffer.ptr[(ny-yi-1)*nx+xi] += radiance
            }
        }
    }
}

// http://artis.inrialpes.fr/Enseignement/TRSA/CookDistributed84.pdf
class DistributedRayTracer: Renderer, RayTracer {
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
            guard
                scene.root.intersectWithRay(r, hit: &hit),
//                let obj = hit.o,
                let mid = hit.m,
                let material = scene.materials[mid]
                else {
                    color = color * scene.skyColor(r);
                    break
            }
            
            
            // if the surface is emissive (i.e. does not have measurable albedo), just return the emission
            if material.isLight() {
                color = color * material.emission
                break
            }
            
            // compute hitpoint, normal
//            let x = r.o + r.d * hit.d           // hit point
//            var n = obj.normalAtPoint(x)    // normal at hitpoint
            let x = hit.x
            var normal = hit.n
            if (dot(r.d, normal) > 0) {          // correct normal direction
                normal = normal * -1
            }
            
            // compute scatterred ray
            let wo: Vec
            (_, wo) = material.sample(r.d, normal: normal)
            
            r = Ray(o: x, d: wo)
            depth = depth - 1
            color = color * material.colorAtTextCoord(hit.uv)
            hit.reset()
        }
        
        return color
    }


}
