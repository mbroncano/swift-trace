//
//  RayTracer.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 12/23/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

typealias ColorPointer = UnsafeMutablePointer<Color>
typealias IntersectionPointer = UnsafeMutablePointer<Intersection>
typealias RayPointer = UnsafeMutablePointer<Ray>
typealias MaterialPointer = UnsafeMutablePointer<Material>

/// Implements a ray tracer
protocol RayTracer {
    /// Computes the radiance (Li) for a given ray
    func radiance(ray ray: RayPointer, hit: IntersectionPointer) -> Color
}

/// Implements a generic scene renderer
protocol Renderer {
    var scene: Scene { get }
    var framebuffer: Framebuffer { get }
    
    func render()
    func renderTile(size size: Int)
}

extension Renderer where Self: RayTracer {
    /// Renders a frame in parallel, dispatching pixels
    func render() {
        let nx = framebuffer.width
        let ny = framebuffer.height

        framebuffer.samples += 1

        dispatch_apply(framebuffer.length, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let x = $0 % nx
            let y = ny - ($0 / nx) - 1
            let r = self.scene.camera.generateRay(x: x, y: y, nx: nx, ny: ny)
            self.framebuffer.ray[$0] = r
        }

        dispatch_apply(framebuffer.length, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let ray = self.framebuffer.ray.advancedBy($0)
            let hit = self.framebuffer.hit.advancedBy($0)
            let li = self.radiance(ray: ray, hit: hit)
            self.framebuffer.ptr[$0] += li
        }

    }
    
    /// Renders a frame in parallel, dispatching tiles
    func renderTile(size size: Int = 16) {
    /*
        framebuffer.samples += 1

        let nx = framebuffer.width
        let ny = framebuffer.height
        
        // number of tiles in each coordinate
        let tx = (nx + size - 1) / size // int div round up
        let ty = (ny + size - 1) / size
        
        // process each ray in parallel, tiled, waits till it finishes
        dispatch_apply(tx*ty, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let x = ($0 % tx) * size
            let y = ($0 / tx) * size

            let sizex = min((nx-x), size)
            let sizey = min((ny-y), size)

            for i in 0..<sizex*sizey {
                // generate new ray
                let xi = x + (i % sizex)
                let yi = y + (i / sizex)
                let ray = self.scene.camera.generateRay(x: xi, y: yi, nx: nx, ny: ny)
                
                // compute and accumulate radiance for the ray
                let radiance = self.radiance(ray)
                self.framebuffer.ptr[(ny-yi-1)*nx+xi] += radiance
            }
        }
        */
    }
}
