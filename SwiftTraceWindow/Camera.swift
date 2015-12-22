//
//  Camera.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 12/21/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

// TODO: antialias (pixel subsampling)
// TODO: implement DOF
// TODO: non-axis aligned POV
public class Camera {
    let o, d: Vec
    
    init(o: Vec, d: Vec) {
        self.o = o
        self.d = d
    }
    
    func generateRay(x x: Int, y: Int, nx: Int, ny: Int) -> Ray {
        let ar = 0.5135
        let cx = Vec(Scalar(nx) * ar / Scalar(ny), 0, 0)
        let cy = cross(cx, d).norm() * ar
    
        let r1 = Random.random() - 0.5
        let r2 = Random.random() - 0.5
    
        let part1 = (Scalar(x) + r1) / Scalar(nx) - 0.5
        let part2 = (Scalar(y) + r2) / Scalar(ny) - 0.5
        let dir = cx * part1 + cy * part2 + d
        
        return Ray(o:o+dir*140, d:dir.norm())
    }
}
