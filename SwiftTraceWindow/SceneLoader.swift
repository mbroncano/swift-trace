//
//  SceneLoader.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 6/3/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import Decodable

//extension Float: Castable {}

extension Vector: Decodable {
    public static func decode(_ json: Any) throws -> Vector {
        return try Vector(v: json as! [Real])
    }

    init(v: [Real]) throws {
        switch v.count {
        case 0: self.init(0)
        case 1: self.init(Real(v[0]))
        case 3: self.init(Real(v[0]), Real(v[1]), Real(v[2]))
        default:
            throw GeometryError.invalidShape("Vector can only have 0, 1 or 3 elements")
        }
    }
}

extension _Scene.Shape: Decodable {
    internal static func decode(_ json: Any) throws -> _Scene.Shape {
        let type = try json => "type" as String
        switch type {
        case "s": return _Scene.Shape.sphere(center: try json => "p", radius: try json => "r")
        case "t": return _Scene.Shape.triangle(v: try json => "v" as [Vector], n: [], t: [])
        case "g": return _Scene.Shape.group(name: "group", shapes: try json => "l")
        default:
            throw GeometryError.invalidShape("The shape type is invalid: \(type)")
        }
    }
}

extension _Scene.Geometry: Decodable {
    internal static func decode(_ json: Any) throws -> _Scene.Geometry {
        return _Scene.Geometry(
            shape: try _Scene.Shape.decode(json),
            material: MaterialId(material: try json => "m"),
            transform: try json =>? "transform")
    }
}

extension _Material: Decodable {
    internal static func decode(_ json: Any) throws -> _Material {
        return _Material(
            name: MaterialId(material: try json => "name" as String),
            Kd: try json => "Kd",
            Ke: try json => "Ke",
            Ks: try json => "Ks")
    }
}

extension ObjectLibrary: Decodable {
    internal static func decode(_ json: Any) throws -> ObjectLibrary {
        return try ObjectLibrary(
            name: try json => "file",
            transform: try json =>? "transform")
    }
}

extension _Scene: Decodable {
    internal static func decode(_ json: Any) throws -> _Scene {
        return try _Scene(
            camera: try json => "camera",
            geometry: try json =>? "geometry",
            material: try json =>? "material",
            object: try json =>? "object")
    }
}

extension _Camera: Decodable {
    static func decode(_ json: Any) throws -> _Camera {
        return try _Camera(
            lookFrom: json => "look_from",
            lookAt: json => "look_at",
            vecUp: json => "vec_up",
            fov: json => "fov",
            aspect: json => "aspect",
            aperture: json => "aperture"
        )}
}

extension Transform: Decodable {
    internal static func decode(_ json: Any) throws -> Transform {
    
        var transform = Transform.Identity
    
        if let scale: Vector = try json =>? "scale" {
            transform = transform + Transform(scale: scale)
        }

        if let translate: Vector = try json =>? "translate" {
            transform = transform + Transform(translate: translate)
        }
        
        return transform
        }
}
