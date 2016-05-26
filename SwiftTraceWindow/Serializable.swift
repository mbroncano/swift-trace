//
//  Serializable.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/25/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import Decodable
import simd

extension Vec: Decodable {
    init(v: [Double]) { self.init(v[0], v[1], v[2]) }
    
    public static func decode(json: AnyObject) throws -> Vec {
        return Vec(v: json as! [Double])
    }
}

extension ComplexCamera: Decodable {
    public static func decode(json: AnyObject) throws -> ComplexCamera {
        return try ComplexCamera(
            lookFrom: json => "look_from",
            lookAt: json => "look_at",
            vecUp: json => "vec_up",
            fov: json => "fov",
            aspect: json => "aspect",
            aperture: json => "aperture"
        )}
}

extension Sphere: Decodable {
    internal static func decode(json: AnyObject) throws -> Sphere {
        return try Sphere(
            rad: json => "r",
            p: json => "p",
            material: json => "m"
        )}
}

extension Triangle: Decodable {
    internal static func decode(json: AnyObject) throws -> Triangle {
        return try Triangle(
            p1: json => "p1",
            p2: json => "p2",
            p3: json => "p3",
            material: json => "m"
        )}
}

extension Scene: Decodable {
    public static func decode(json: AnyObject) throws -> Scene {
    
        // WTF!!
        let spheres: [Sphere] = try json => "primitives" => "spheres"
        let triangles: [Triangle] = try json => "primitives" => "triangles"
        var objects: [Primitive] = []
        triangles.forEach { (t) in
            objects.append(t)
        }
        spheres.forEach { (s) in
            objects.append(s)
        }
    
        return try Scene(
            camera: json => "camera",
            objects: objects
        )}
}