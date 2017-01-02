//
//  RayTracer.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 12/23/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

enum RendererError: Error {
    case invalidSample(String)
    case invalidGeometry(String)
}

/// Implements an integrator
protocol Integrator {
    /// Computes the radiance (Li) for a given ray
    static func radiance(_ scene: _Scene, ray: inout _Ray) throws -> Vector
}

/// Implements a generic scene renderer
struct Renderer {
    let scene: _Scene
    let integrator: Integrator

    init(scene: _Scene, w: Int, h: Int, integrator: Integrator) {
        self.scene = scene
        self.integrator = integrator
    }

    /// Renders a frame in parallel, dispatching pixels
    func render(_ framebuffer: inout Framebuffer) {
        let nx = framebuffer.width
        let ny = framebuffer.height
        
        framebuffer.samples += 1

        // first compute the ray
        DispatchQueue.concurrentPerform(iterations: framebuffer.length) {
            let x = $0 % nx
            let y = ny - ($0 / nx) - 1
            let c = self.scene.camera
            let r = c.generateRay(x: x, y: y, nx: nx, ny: ny)
            framebuffer.ray[$0] = r
        }

        // now compute the samples
        DispatchQueue.concurrentPerform(iterations: framebuffer.length) {
            do {
                let ray = framebuffer.ray.advanced(by: $0)
                let li = try PathTracer.radiance(self.scene, ray: &ray.pointee)
                
                // check that the sample is correct
                guard !(li.x.isNaN || li.y.isNaN || li.z.isNaN) else {
                    throw RendererError.invalidSample("an invalid sample was generated")
                }
        
                framebuffer.ptr[$0] += li
            } catch {
                print(error)
            }
        }

    }
    
    /// Renders a frame in parallel, dispatching tiles
    func renderTile(size: Int = 16) {
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
