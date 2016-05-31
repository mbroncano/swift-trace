//
//  Shape.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/30/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

protocol RayIntersection {
    func intersect(ray: Ray) -> Scalar
}

protocol GeometricIntersection {
    func normalAt(p: Vec) -> Vec
    func textureAt(p: Vec) -> Vec
}

protocol BBox {
    var boundingBox: Shape { get }
    var area: Scalar { get }
    var center: Vec { get }
}

protocol BBoxAndIntersection: BBox, RayIntersection { }

protocol RayIntersectionWithHit {
    func intersect(ray: Ray, inout hit: Intersection) -> Scalar
}

protocol BBoxOps: BBox {
    func union(s: Shape) -> Shape
    func overlap(s: Shape) -> Bool
}

enum ShapeError: ErrorType {
    case InvalidSet(String)
}


//typealias ShapeBVH = BVH<Shape>
typealias PrimiBVH = BVH

enum BVH: BBoxAndIntersection {

    typealias ItemType = Primi

    indirect case Leaf(ItemType)
    indirect case Node(left: BVH, right: BVH, bbox: Shape)

    init(_ list: [ItemType]) throws {
        guard list.count > 0 else { throw ShapeError.InvalidSet("The provide shape set is invalid") }

        let axis = Int(Scalar.Random() * 3.0)
        
        let sorted = list.sort({ (a, b) -> Bool in return a.center[axis] > b.center[axis] })
        
        if sorted.count >= 2 {
            let mid = sorted.count / 2
            let left = try BVH([] + sorted[0..<mid])
            let right = try BVH([] + sorted[mid..<sorted.count])
            let bbox = left.boundingBox.union(right.boundingBox)
            self = .Node(left: left, right: right, bbox: bbox)
        } else /*if sorted.count == 1*/ {
            self = .Leaf(sorted[0])
        }
    }

    var area: Scalar { get {
        return boundingBox.area
    }}
    
    var center: Vec { get {
        return boundingBox.center
    }}
    
    var boundingBox: Shape { get {
        switch self {
            case let .Leaf(s):
                return s.boundingBox
            case let .Node(_, _, bbox):
                return bbox
        }
    }}
    
    func intersect(ray: Ray) -> Scalar {
        switch self {
        case let .Leaf(p):
            return p.intersect(ray)
        case let .Node(left, right, bbox):
            return bbox.intersect(ray) != Scalar.infinity ?
                   min(left.intersect(ray), right.intersect(ray)) : Scalar.infinity
        }
    }
//}

//extension BVH { where T: RayIntersectionWithHit {
    func intersect(ray: Ray, inout hit: Intersection) -> Scalar {
    
        switch self {
        case let .Leaf(p):
            return p.intersect(ray, hit: &hit)
        case let .Node(left, right, bbox):
            guard bbox.intersect(ray) != Scalar.infinity else { return Scalar.infinity }
            
            let lbool = left.intersect(ray, hit: &hit)
            let rbool = right.intersect(ray, hit: &hit)
            
            return min(lbool, rbool)
        }
    }
}

struct World: RayIntersectionWithHit {
    let root: PrimiBVH

    init(_ s: [Primi]) throws {
        root = try PrimiBVH(s)
    }
    
    func intersect(ray: Ray, inout hit: Intersection) -> Scalar {
        return root.intersect(ray, hit: &hit)
    }
    
}

struct Primi: BBoxAndIntersection, RayIntersectionWithHit {
    let shape: Shape
    
    let material: MaterialId
    let transform: Transform

    let boundingBox: Shape
    let center: Vec
    let area: Scalar
    
/*
    init(_ s: [Shape], material m: MaterialId? = nil, transform t: Transform? = nil) throws {
        shape = Shape.Mesh(root: try ShapeBVH(s))
        boundingBox = shape.boundingBox
        center = shape.center
        area = shape.area
        material = m
        transform = t
    }
*/
    init(_ s: Shape, material m: MaterialId) {
        shape = s
        boundingBox = shape.boundingBox
        center = shape.center
        area = shape.area
        material = m
        transform = Transform()
    }
    
    func intersect(ray: Ray) -> Scalar {
        return shape.intersect(ray)
    }
    
    func intersect(ray: Ray, inout hit: Intersection) -> Scalar {
        let d = shape.intersect(ray, hit: &hit)
        
        if d == hit.d {
            hit.m = material
        }
        
        return d
    }
}

enum Shape: BBoxAndIntersection {
    case BoundingBox(a: Vec, b: Vec)
    case Sphere(pos: Vec, rad: Scalar)
    case Triangle(v1: Vec, v2: Vec, v3: Vec)
//    case Mesh(root: ShapeBVH)
}

extension Shape: RayIntersectionWithHit {
    /// Returns the intersection with a ray or infinity
    func intersect(ray: Ray, inout hit: Intersection) -> Scalar {
        switch self {
//        case let .Mesh(root):
//            return root.intersect(ray, hit: &hit)
        case let .Triangle(v1, v2, v3):
            let d: Scalar
            let t: Vec
            (d, t) = triangleIntersect(v1: v1, v2: v2, v3: v3, ray: ray)
            
            if d < hit.d {
                hit.d = d
                hit.x = ray.o + ray.d * d
                hit.n = normalAt(hit.x)
                
                // default texture coordinates
                let t0 = Vec(0, 0, 0)
                let t1 = Vec(0, 1, 0)
                let t2 = Vec(1, 0, 0)
                
                hit.uv = t0 * t.z + t1 * t.x + t2 * t.y
            }
            return d
            
        case .Sphere, .BoundingBox:
            let d = intersect(ray)
            if d < hit.d {
                hit.d = d
                hit.x = ray.o + ray.d * d
                hit.n = normalAt(hit.x)
                hit.uv = textureAt(hit.x)
            }
            return d
        }
    }
}

extension Shape: GeometricIntersection {
    /// Returns the geometric (vs shading) normal at a point
    func normalAt(p: Vec) -> Vec {
        switch self {
            case let .Sphere(pos, _):
                return (p-pos).norm()
            case let .Triangle(v1, v2, v3):
                return ((v3-v1) % (v2-v1)).norm()
            default:
                // FIXME: undefined for the rest of the shapes
                return Vec.Zero
        }
    }
    
    func textureAt(p: Vec) -> Vec {
        switch self {
            case .Sphere:
                let n = normalAt(p)
                let u = 0.5 + atan2(n.z, n.x) / Scalar.pi2
                let v = 0.5 - asin(n.y) / Scalar.pi
                return Vec(u, v, 0)
            case let .Triangle(v1, v2, v3):
                // compute u,v over the edges
                let v0 = (p-v1)
                let e1 = (v2-v1)
                let e2 = (v3-v1)
                let u = dot(v0, e1)
                let v = dot(v0, e2)
                // default texture coordinates
                let t1 = Vec(0, 0, 0)
                let t2 = Vec(0, 1, 0)
                let t3 = Vec(1, 0, 0)
                let tu = abs(t2 - t1)
                let tv = abs(t3 - t1)
                
                return tu * u + tv * v
            default:
                // FIXME: undefined for the rest of the shapes
                return Vec.Zero
        }
    }
}

extension Shape: BBoxOps {
    /// Returns the bounding box union with another shape's
    func union(s: Shape) -> Shape {
        switch (self, s) {
        case (let .BoundingBox(amin, amax), let BoundingBox(bmin, bmax)):
            return .BoundingBox(a: min(amin, bmin), b:max(amax, bmax))
        case (.BoundingBox, _):
            return union(s.boundingBox)
        default:
            return self.boundingBox.union(s.boundingBox)
        }
    }

    /// Returns whether the shape bounding box overlaps with another one's
    func overlap(s: Shape) -> Bool {
        switch (self, s) {
        case (let .BoundingBox(amin, amax), let BoundingBox(bmin, bmax)):
            return (amin.x <= bmax.x && amax.x >= bmin.x) &&
                   (amin.y <= bmax.y && amax.y >= bmin.y) &&
                   (amin.z <= bmax.z && amax.z >= bmin.z)
        case (.BoundingBox, _):
            return overlap(s.boundingBox)
        default:
            return self.boundingBox.overlap(s.boundingBox)
        }
    }
}

extension Shape: RayIntersection {
    /// Returns the intersection with a ray or infinity
    func intersect(ray: Ray) -> Scalar {
        switch self {
        case let .BoundingBox(a, b):
            return boundingBoxIntersect(a: a, b: b, ray: ray)
        case let .Sphere(pos, rad):
            return sphereIntersect(pos: pos, rad: rad, ray: ray)
        case let .Triangle(v1, v2, v3):
            let d: Scalar
            (d, _) = triangleIntersect(v1: v1, v2: v2, v3: v3, ray: ray)
            return d
//        case let .Mesh(root):
//            return root.intersect(ray)
        }
    }
}

extension Shape: BBox {
    /// Returns the are for the shape
    var area: Scalar { get {
        switch self {
        case let .BoundingBox(a, b):
            return (b - a).len2() * 2
        case let .Sphere(_, rad):
            return Scalar.pi4 * (rad * rad)
        case let .Triangle(v1, v2, v3):
            return (v3-v1).len() * (v2-v1).len() * 0.5
//        case let .Mesh(root):
//            return root.area
        }
    }}
    
    /// Returns the center of the shape
    var center: Vec { get {
        switch self {
        case let .BoundingBox(a, b):
            return (b - a) * 0.5
        case let .Sphere(pos, _):
            return pos
        case let .Triangle(v1, v2, v3):
            return ((v3-v1) + (v2-v1)) * 0.5 // (v3+v2) * 0.5 - v1
//        case let .Mesh(root):
//            return root.center
        }
    }}
    
    /// Returns the bounding box of the shape
    var boundingBox: Shape { get {
        switch self {
        case .BoundingBox:
            return self
        case let .Sphere(pos, rad):
            return Shape.BoundingBox(a: pos - Vec(rad), b: pos + Vec(rad))
        case let .Triangle(v1, v2, v3):
            return Shape.BoundingBox(a: min(min(v1, v2), min(v2, v3)), b: max(max(v1, v2), max(v2, v3)))
//        case let .Mesh(root):
//            return root.boundingBox
        }
    }}
}

func boundingBoxIntersect(a a: Vec, b: Vec, ray: Ray) -> Scalar {
    let t1: Vec = (a - ray.o) * ray.inv
    let t2: Vec = (b - ray.o) * ray.inv
    
    let tmin = reduce_max(min(t1, t2))
    let tmax = reduce_min(max(t1, t2))
    
    return tmax >= tmin ? tmin : Scalar.infinity
}

func sphereIntersect(pos pos: Vec, rad: Scalar, ray: Ray) -> Scalar {
    // solve the quadratic equation
    let po = ray.o - pos
    let b = dot(ray.d, po)
    let c = dot(po, po) - (rad * rad)
    let t = b*b - c
    
    // if the determinant is negative, there are not solutions
    guard (t > 0) else { return Scalar.infinity }
    
    // compute the distance
    let s = sqrt(t)
    let d = (b < 0) ? (-b-s) : (-b+s)
    
    // check that the distance fits the ray boundaries
    guard d > ray.tmin && d < ray.tmax else { return Scalar.infinity }
    
    return d
}

func triangleIntersect(v1 v1: Vec, v2: Vec, v3: Vec, ray: Ray) -> (Scalar, Vec) {
    // default ret
    let ret = (Scalar.infinity, Vec.Zero)

    // calculate edges
    let edge1 = v2-v1
    let edge2 = v3-v1

    // begin calculating determinant - also used to calculate u parameter
    let p = cross(ray.d, edge2)
    
    // compute the determinant
    let det = dot(edge1, p)
    
    // the triangle is degenerate (i.e. lies on the plane of triangle)
    if (det > -Scalar.epsilon && det < Scalar.epsilon) { return ret }
    
    // we will use the inverse from now on
    let inv_det = 1.0 / det;
    
    // calculate distance from the first vertex to ray origin
    let t = ray.o - v1
    
    // calculate u parameter and test bound
    let u = dot(t, p) * inv_det
    
    //The intersection lies outside of the triangle
    if (u < 0.0 || u > 1.0) { return ret }
    
    // prepare to test v parameter
    let q = cross(t, edge1)
    
    // calculate v parameter and test bound
    let v = dot(ray.d, q) * inv_det;
    
    // the intersection lies outside of the triangle
    if v < 0.0 || (u+v) > 1.0 { return ret }
    
    // compute distance
    let d = dot(edge2, q) * inv_det;
    
    // check that the distance fits the ray boundaries
    guard d > ray.tmin && d < ray.tmax else { return ret }
    
    // return the distance and
    return (d, Vec(u, v, 1-u-v))
}