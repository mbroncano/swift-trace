//
//  Camera.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 12/21/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

protocol GenerateRay {
    func generateRay(x x: Int, y: Int, nx: Int, ny: Int) -> Ray
}

/// Simple, axis aligned camera with antialias
public class Camera: GenerateRay {
    let o, d: Vec
    
    init(o: Vec, d: Vec) {
        self.o = o
        self.d = d
    }
    
    func generateRay(x x: Int, y: Int, nx: Int, ny: Int) -> Ray {
        let ar: Scalar = 0.5135
        let cx = Vec(Scalar(nx) * ar / Scalar(ny), 0, 0)
        let cy = cross(cx, d).norm() * ar
    
        let r1 = Scalar.Random() - 0.5
        let r2 = Scalar.Random() - 0.5
    
        let part1 = (Scalar(x) + r1) / Scalar(nx) - 0.5
        let part2 = (Scalar(y) + r2) / Scalar(ny) - 0.5
        let dir = cx * part1 + cy * part2 + d
        
        return Ray(o:o+dir*140, d:dir.norm())
    }
}

/// Simple axis aligned camera with antialias
public class SimpleCamera: GenerateRay {
    let o, d: Vec
    
    init(o: Vec, d: Vec) {
        self.o = o
        self.d = d
    }
    
    func generateRay(x x: Int, y: Int, nx: Int, ny: Int) -> Ray {
        let ar = Scalar(ny) / Scalar(nx)
        let cx = Vec(1, 0, 0)
        let cy = cross(cx, d) * ar

//        let r1 = 0.0//Random.random() - 0.5
//        let r2 = 0.0//Random.random() - 0.5
    
        let u = (Scalar(x) /*+ r1*/) / Scalar(nx-1) - 0.5
        let v = (Scalar(y) /*+ r2*/) / Scalar(ny-1) - 0.5
        let dir = d + cx * u + cy * v
        
        return Ray(o:o, d:dir.norm())
    }
}


// Complex camera with arbitrary positioning, DOF/antialias
final public class ComplexCamera: GenerateRay {
    private
    let origin: Vec
    let lowerLeftCorner: Vec
    let horizontal: Vec
    let vertical: Vec
    let lensRadius: Scalar
    let u, v, w: Vec
    
    init(lookFrom: Vec, lookAt: Vec, vecUp: Vec, fov: Scalar, aspect: Scalar, aperture: Scalar = 0.0) {
        origin = lookFrom
        let focusDist = length(lookFrom - lookAt)
        lensRadius = aperture / 2.0

        let theta = fov * Scalar(M_PI) / 180
        let halfHeight = tan(theta/2)
        let halfWidth = aspect * halfHeight
        w = (lookFrom - lookAt).norm()
        u = cross(vecUp, w).norm()
        v = cross(w, u)

        lowerLeftCorner = origin - halfWidth * u * focusDist - halfHeight * v * focusDist - w * focusDist
        horizontal = 2 * halfWidth * u * focusDist
        vertical = 2 * halfHeight * v * focusDist
    }
    
    func generateRay(x x: Int, y: Int, nx: Int, ny: Int) -> Ray {
        let lens = sampleDisk() * lensRadius
        let ofs = u * lens.x + v * lens.y
    
        let r1 = Scalar.Random() - 0.5
        let r2 = Scalar.Random() - 0.5

        let s = (Scalar(x) + r1) / Scalar(nx-1)
        let t = (Scalar(y) + r2) / Scalar(ny-1)
        let d = lowerLeftCorner +  s * horizontal + t * vertical - origin - ofs
        
        return Ray(o: origin + ofs, d: d.norm())
    }
}
