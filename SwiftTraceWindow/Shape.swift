//
//  Shape.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/30/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

enum ShapeError: ErrorType {
    case InvalidSet(String)
}

protocol RayIntersection {
    func intersect(ray: Ray) -> Scalar
}

protocol Transformable {
    func apply(t: Transform) throws -> Self
}

protocol BBox {
    var boundingBox: Shape { get }
    var area: Scalar { get }
    var center: Vec { get }
}

protocol BBoxOps: BBox {
    func union(s: Shape) -> Shape
    func overlap(s: Shape) -> Bool
}

protocol RayIntersectionWithHit {
    func intersect(ray: Ray, inout hit: Intersection) -> Scalar
}

protocol BBoxAndIntersection: BBox, RayIntersection, RayIntersectionWithHit { }

typealias ShapeBVH = BVH<Shape>
typealias PrimiBVH = BVH<Primi>

final class BVHEnumNode<ItemType: BBoxAndIntersection>: BBoxAndIntersection {
    let node: BVH<ItemType>
    
    let area: Scalar
    let center: Vec
    let boundingBox: Shape
    
    init(node: BVH<ItemType>) {
        self.node = node
        self.area = node.area
        self.center = node.center
        self.boundingBox = node.boundingBox
    }
    
    func intersect(ray: Ray) -> Scalar {
        return node.intersect(ray)
    }

    func intersect(ray: Ray, inout hit: Intersection) -> Scalar {
        return node.intersect(ray, hit: &hit)
    }
}

func sum<T: SequenceType where T.Generator.Element == Int>(list: T) -> Int {
    return list.reduce(0, combine: { (acc, e) in
        return acc + e
    })
}

    
struct SAHNode<ItemType: BBox> {
    let item: ItemType
    
    let area: Scalar
    let center: Vec
    let boundingBox: Shape
    
    init(item: ItemType) {
        self.item = item
        area = item.area
        center = item.center
        boundingBox = item.boundingBox
    }
}

struct box {
    let a, b: Vec
    let area: Scalar
    let center: Vec
    
    static let empty = box(a: Vec(Scalar.infinity), b: Vec(-Scalar.infinity))
    
    init(_ bbox: Shape) {
        if case Shape.BoundingBox(let a, let b) = bbox {
            self.init(a: a, b: b)
        } else {
            self.init(a: Vec(Scalar.infinity), b: Vec(-Scalar.infinity))
        }
    }
    
    init(a: Vec, b: Vec) {
        self.a = a
        self.b = b
        let c = b-a
        self.area = 2 * (c.x*c.y + c.x*c.z + c.y*c.z)
        self.center = a + c * 0.5
    }
}

func + (lhs: box, rhs: box) -> box { return box(a: min(lhs.a, rhs.a), b: max(lhs.b, rhs.b)) }

func sah(list: [box]) -> (Int, Scalar) {
    var min = Scalar.infinity
    var index = -1
    let Ct = 1.0
    let Ci = 4.0
    
    print("sah: num \(list.count)")
    for i in list.indices {
        let left = list[0..<i].reduce(box.empty, combine: +)
        let right = list[i..<list.count].reduce(box.empty, combine: +)
        let rootArea = (left + right).area
        let leftArea = left.area * Scalar(i)
        let rightArea = right.area * Scalar(list.count - i)
        let ret = Ct + Ci * (leftArea + rightArea) / rootArea
        if ret < min {
            min = ret
            index = i
        }
    }
    print("sah: result \(index),\(min)")
    return (index, min)
}


enum BVH<ItemType: BBoxAndIntersection>: BBoxAndIntersection {
    indirect case Leaf(ItemType)
    indirect case Node(left: BVH, right: BVH, bbox: Shape)

    init(_ list: [ItemType]) throws {
        guard list.count > 0 else { throw ShapeError.InvalidSet("The provide shape set is invalid") }
        guard list.count > 1 else { self = .Leaf(list[0]); return }

//        let axis = Int(Scalar.Random() * 3.0)
        
        let sorted = (0...2).map({ axis in list.sort({ $0.center[axis] > $1.center[axis] }) })
        let boxes = sorted.map({ $0.map({ box($0.boundingBox) }) })
        
//        print("sah: \(boxes.count)")
        let sahAxis = boxes.map({ sah($0) })
        let (_, cx) = sahAxis[0]
        let (_, cy) = sahAxis[1]
        let (_, cz) = sahAxis[2]
        var a: Int
        if cx < cy { if cx < cz { a = 0 } else { a = 2 } } else { if cy < cz { a = 1 } else { a = 2 } }
        let (mid, _) = sahAxis[a]

        let left = try BVH([] + sorted[a][0..<mid])
        let right = try BVH([] + sorted[a][mid..<sorted.count])
        let bbox = left.boundingBox.union(right.boundingBox)
        self = .Node(left: left, right: right, bbox: bbox)
    }

    var leaves: Array<ItemType> { get {
        switch self {
        case let .Leaf(leaf):
            return [leaf]
        case let .Node(left, right, _):
            return left.leaves + right.leaves
        }
        }}

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

/// Contains a set of primitives
struct World: RayIntersectionWithHit {
    let root: PrimiBVH

    init(_ s: [Primi]) throws {
        root = try PrimiBVH(s)
    }
    
    func intersect(ray: Ray, inout hit: Intersection) -> Scalar {
        let d = root.intersect(ray, hit: &hit)
//        if hit.count > 30 {
//            print("x")
//        }
        return d
    }
}

/// Contains a set of shapes that share a material
struct Primi: BBoxAndIntersection, RayIntersectionWithHit {
    let bvh: ShapeBVH
    
    let material: MaterialId
    let transform: Transform

    let boundingBox: Shape
    let center: Vec
    let area: Scalar
    
    init(shape: Shape, material m: MaterialId, transform t: Transform = Transform.Identity) throws {
        let tshape = try shape.apply(t)
        
        bvh = try ShapeBVH(tshape.all)
    
        boundingBox = bvh.boundingBox
        center = bvh.center
        area = bvh.area
        
        transform = t
        material = m
    }
    
    func intersect(ray: Ray) -> Scalar { return bvh.intersect(ray) }
    
    func intersect(ray: Ray, inout hit: Intersection) -> Scalar {
//        let ray = transform.isIdentity ? ray : transform.reverse().apply(ray: ray)
        let d = bvh.intersect(ray, hit: &hit)
        if d == hit.d { hit.m = material }
        return d
    }
}




enum Shape: BBoxAndIntersection {
    case BoundingBox(a: Vec, b: Vec)
    case Sphere(pos: Vec, rad: Scalar)
    case Triangle(v1: Vec, v2: Vec, v3: Vec, t1: Vec, t2: Vec, t3: Vec)
    case BVH(root: ShapeBVH)
    case List(shapes: [Shape])
    
    /// Convenience for triangles w/out texture vertices
    init(v1: Vec, v2: Vec, v3: Vec) {
        self = .Triangle(v1: v1, v2: v2, v3: v3, t1: Vec(0, 1, 0), t2: Vec(1, 0, 0), t3: Vec(0, 0, 0))
    }
}

extension Shape {
    var all: [Shape] { get {
        switch self {
        case .BoundingBox: fallthrough
        case .Sphere: fallthrough
        case .Triangle:
            return [self]
        case let .BVH(root):
            return root.leaves
        case let .List(shapes):
            return shapes.reduce([], combine: { $0 + $1.all })
        }
    }}
}

extension Shape: Transformable {
    func apply(t: Transform) throws -> Shape {
        switch self {
        case let .BoundingBox(a, b):
            return Shape.BoundingBox(
                a: t.apply(vector: a),
                b: t.apply(vector: b))
        case let .Sphere(pos, rad):
            return Shape.Sphere(
                pos: t.apply(point: pos),
                rad: rad)
        case let .Triangle(v1, v2, v3, t1, t2, t3):
            return Shape.Triangle(
                v1: t.apply(point: v1),
                v2: t.apply(point: v2),
                v3: t.apply(point: v3),
                t1: t1, t2: t2, t3: t3)
        case let .BVH(root):
            return Shape.BVH(root: try ShapeBVH(root.leaves.map({ try $0.apply(t) })))
        case let .List(shapes):
            return Shape.List(shapes: try shapes.map({ try $0.apply(t) }))
        }
    }
}

extension Shape: RayIntersectionWithHit {
    /// Returns the intersection with a ray or infinity
    func intersect(ray: Ray, inout hit: Intersection) -> Scalar {
        hit.count += 1
        switch self {
        case let .Triangle(v1, v2, v3, t1, t2, t3):
            let ret = triangleIntersect(v1: v1, v2: v2, v3: v3, ray: ray)
            let d: Scalar = ret.x
            let t: Vec = Vec(ret.y, ret.z, 1-ret.y-ret.z)
            
            if d < hit.d {
                hit.d = d
                hit.x = ray.o + ray.d * d
                hit.n = ((v3-v1) % (v2-v1)).norm()
                
                // default texture coordinates
//                let t0 = Vec(0, 0, 0)
//                let t1 = Vec(0, 1, 0)
//                let t2 = Vec(1, 0, 0)
                
                hit.uv = t3 * t.z + t1 * t.x + t2 * t.y
            }
            return d
        case let .Sphere(pos, _):
            let d = intersect(ray)
            if d < hit.d {
                hit.d = d
                hit.x = ray.o + ray.d * d
                hit.n = (hit.x-pos).norm()
                let u = 0.5 + atan2(hit.n.z, hit.n.x) / Scalar.pi2
                let v = 0.5 - asin(hit.n.y) / Scalar.pi
                hit.uv = Vec(u, v, 0)
            }
            return d
        case let .BVH(root):
            return root.intersect(ray, hit: &hit)
        case .BoundingBox:
            return intersect(ray)
        case let .List(shapes):
            return shapes.reduce(Scalar.infinity, combine: { min($0, $1.intersect(ray, hit: &hit))})
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
        case let .Triangle(v1, v2, v3, _, _, _):
            let d = triangleIntersect(v1: v1, v2: v2, v3: v3, ray: ray)
            return d.x
        case let .BVH(root):
            return root.intersect(ray)
        case let .List(shapes):
            return shapes.reduce(Scalar.infinity, combine: { min($0, $1.intersect(ray))})
        }
    }
}

extension Shape: BBox {
    /// Returns the area for the shape
    var area: Scalar { get {
        switch self {
        case let .BoundingBox(a, b):
            let ba = b - a
            return 2*(ba.x*ba.y + ba.x*ba.z + ba.y*ba.z)
        case let .Sphere(_, rad):
            return Scalar.pi4 * (rad * rad)
        case let .Triangle(v1, v2, v3, _, _, _):
            return (v3-v1).len() * (v2-v1).len() * 0.5
        case let .BVH(root):
            return root.area
        case let .List(shapes):
            return shapes.reduce(0, combine: { $0 + $1.area })
        }
    }}
    
    /// Returns the center of the shape
    var center: Vec { get {
        switch self {
        case let .BoundingBox(a, b):
            return (b - a) * 0.5
        case let .Sphere(pos, _):
            return pos
        case let .Triangle(v1, v2, v3,  _, _, _):
            return ((v3-v1) + (v2-v1)) * 0.5 // (v3+v2) * 0.5 - v1
        case let .BVH(root):
            return root.center
        case .List:
            // FIXME: do we need anything better?
            return boundingBox.center
        }
    }}
    
    /// Returns the bounding box of the shape
    var boundingBox: Shape { get {
        switch self {
        case .BoundingBox:
            return self
        case let .Sphere(pos, rad):
            return Shape.BoundingBox(a: pos - Vec(rad), b: pos + Vec(rad))
        case let .Triangle(v1, v2, v3, _, _, _):
            return Shape.BoundingBox(a: min(min(v1, v2), min(v2, v3)), b: max(max(v1, v2), max(v2, v3)))
        case let .BVH(root):
            return root.boundingBox
        case let .List(shapes):
            return shapes.reduce(Shape.BoundingBox(a: Vec(Scalar.infinity), b: Vec(-Scalar.infinity)), combine: { $0.union($1)})
        }
    }}
}

func boundingBoxIntersect(a a: Vec, b: Vec, ray: Ray) -> Scalar {
    // SIMD version of the slabs method
    // This is *not* numerically stable
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

func triangleIntersect(v1 v1: Vec, v2: Vec, v3: Vec, ray: Ray) -> Vec {
    // default ret
    let ret = Vec(Scalar.infinity, 0, 0)

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
    
    // return the distance and texture coordinates
    return Vec(d, u, v)
}