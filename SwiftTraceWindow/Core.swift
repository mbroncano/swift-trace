//
//  Core.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 6/2/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

typealias Real = Float
extension Real {
    static let Eps = FLT_EPSILON
}

typealias Vector = simd.float3
extension Vector {
    static let Inf = Vector(Real.infinity)
}

typealias IndexType = Int
extension IndexType {
    static let Invalid = -1
}

typealias GeometryId = IndexType
typealias PrimitiveId = IndexType

enum GeometryError: ErrorType {
    case InvalidShape(String)
}

enum _SceneError: ErrorType {
    case BuildingTree(String)
}

struct _Ray {
    /// origin of the ray
    let o: Vector
    /// direction of the ray
    let d: Vector
    /// near segment
    let tmin: Real
    /// far segment
    var tmax: Real
    
    /// hit point
    var x: Vector
    /// geometric normal
    var n: Vector
    /// barycentric coordinates
    var u, v: Real
    /// geometry and primitive id
    var gid, pid: IndexType
}

struct _Scene {
    // FIXME: compare this to UnsafeMutablePointer
    typealias VectorBuffer = ContiguousArray<Vector>
    typealias PrimitiveBuffer = ContiguousArray<Primitive>
    typealias GeometryBuffer = ContiguousArray<Geometry>
    typealias BoxBuffer = ContiguousArray<Box>

    enum PrimitiveType {
        case Sphere(ic: IndexType, rad: Real)
        case Triangle(i1: IndexType, i2: IndexType, i3: IndexType)
    }
    
    enum Shape {
        case Sphere(center: Vector, radius: Real)
        case Triangle(v: [Vector], n: [Vector], t:[Vector])
        case Group(shapes: [Shape])
//        case Mesh(f: [[IndexType]], v: [Vector], vn: [Vector], vt: [Vector])
    }
    
    struct Primitive {
        let type: PrimitiveType
        let gid: GeometryId
        let pid: PrimitiveId
    }
    
    struct Geometry {
        let shape: Shape
        let material: MaterialId
    }

    struct Box {
        let a, b: Vector
        let c: Vector
        let s: Real
        
        static let empty = Box(a: Vector.Inf, b: -Vector.Inf)
        
        init(a: Vector, b: Vector) {
            let ba = b-a

            self.a = a
            self.b = b
            self.c = a + ba * 0.5
            self.s = 2 * (ba.x*ba.y + ba.x*ba.z + ba.y*ba.z)
        }
    }

    var vertexBuffer: VectorBuffer
    var primitiveBuffer: PrimitiveBuffer
    var geometryBuffer: GeometryBuffer
    var boxBuffer: BoxBuffer

    init() throws {
        vertexBuffer = VectorBuffer()
        primitiveBuffer = PrimitiveBuffer()
        geometryBuffer = GeometryBuffer()
        boxBuffer = BoxBuffer()
        
        let g = Geometry(shape: Shape.Sphere(center: Vector(0, 0, 0), radius: 10) , material:0)
        try addGeometry(g)
    }
    
    mutating func addGeometry(geometry: Geometry) throws {
        let gid = geometryBuffer.endIndex

        try addShape(geometry.shape, gid: gid)
        geometryBuffer.append(geometry)
    }

    mutating func addShape(shape: Shape, gid: GeometryId, pid: PrimitiveId = 0) throws {
        let vi = vertexBuffer.endIndex

        switch shape {
        case let .Triangle(v, _, _):
            guard v.count == 3 else { throw GeometryError.InvalidShape("A triangle needs three vertices") }
//            guard n.count == 0 || n.count == 3 else { throw GeometryError.InvalidShape("A triangle needs three normals or none") }
//            guard t.count == 0 || t.count == 3 else { throw GeometryError.InvalidShape("A triangle needs three textcoords or none") }
            vertexBuffer += v
        
            let ptype = PrimitiveType.Triangle(i1: vi, i2: vi+1, i3: vi+2)
            primitiveBuffer.append(Primitive(type: ptype, gid: gid, pid: pid))
            
            boxBuffer.append(Box(a: min(min(v[0], v[1]), v[2]), b: max(max(v[0], v[1]), v[2])))
        
        case let .Sphere(center, radius):
            vertexBuffer += [center]

            let ptype = PrimitiveType.Sphere(ic: vi, rad: radius)
            primitiveBuffer.append(Primitive(type: ptype, gid: gid, pid: pid))
            
            boxBuffer.append(Box(a: center-Vector(radius), b: center+Vector(radius)))
        
        case let .Group(shapes):
            try shapes.enumerate().forEach({ (index, shape) in
                if case .Group = shape { throw GeometryError.InvalidShape("Nesting shape groups not supported") }
                try addShape(shape, gid: gid, pid: index)
            })
        }
    }
    
    /// BVH root node
    var bvh: BVH? = nil

    /// BVH building
    mutating func build() throws {
        let list = primitiveBuffer.indices
        let boxes = list.map({ BVH.NodeBox(box: boxBuffer[$0], global:$0) })
    
        bvh = try BVH(boxes)
    }
    
    /// AABB intersection
    static func boxIntersect(a a: Vector, b: Vector, inout ray: _Ray) -> Bool {
        // SIMD version of the slabs method
        // This is *not* numerically stable
        let inv = recip(ray.d)
        let t1: Vector = (a - ray.o) * inv
        let t2: Vector = (b - ray.o) * inv
        
        let tmin = reduce_max(min(t1, t2))
        let tmax = reduce_min(max(t1, t2))
        
        guard tmax >= tmin else { return false }
        
        // update ray
        ray.tmax = tmin
        
        return true
    }
    
    /// Sphere intersection
    static func sphereIntersect(pos pos: Vector, rad: Real, inout ray: _Ray) -> Bool {
        // solve the quadratic equation
        let po = ray.o - pos
        let b = dot(ray.d, po)
        let c = dot(po, po) - (rad * rad)
        let t = b*b - c
        
        // if the determinant is negative, there are not solutions
        guard (t > 0) else { return false }
        
        // compute the distance
        let s = sqrt(t)
        let d = (b < 0) ? (-b-s) : (-b+s)
        
        // check that the distance fits the ray boundaries
        guard d > ray.tmin && d < ray.tmax else { return false }
        
        // update ray
        ray.tmax = d
        ray.x = ray.o+ray.d*d - pos
        ray.n = normalize(ray.x-pos)
        ray.u = 0.5 + atan2(ray.n.z, ray.n.x) / Real(2*M_PI)
        ray.v = 0.5 - asin(ray.n.y) / Real(M_PI)
        
        return true
    }
    
    /// Triangle intersection
    static func triangleIntersect(v1 v1: Vector, v2: Vector, v3: Vector, inout ray: _Ray) -> Bool {
        // calculate edges
        let edge1 = v2-v1
        let edge2 = v3-v1
        
        // begin calculating determinant - also used to calculate u parameter
        let p = cross(ray.d, edge2)
        
        // compute the determinant
        let det = dot(edge1, p)
        
        // the triangle is degenerate (i.e. lies on the plane of triangle)
        if (det > -Real.Eps && det < Real.Eps) { return false }
        
        // we will use the inverse from now on
        let inv_det = 1.0 / det;
        
        // calculate distance from the first vertex to ray origin
        let t = ray.o - v1
        
        // calculate u parameter and test bound
        let u = dot(t, p) * inv_det
        
        //The intersection lies outside of the triangle
        if (u < 0.0 || u > 1.0) { return false }
        
        // prepare to test v parameter
        let q = cross(t, edge1)
        
        // calculate v parameter and test bound
        let v = dot(ray.d, q) * inv_det;
        
        // the intersection lies outside of the triangle
        if v < 0.0 || (u+v) > 1.0 { return false }
        
        // compute distance
        let d = dot(edge2, q) * inv_det;
        
        // check that the distance fits the ray boundaries
        guard d > ray.tmin && d < ray.tmax else { return false }

        // update the ray
        ray.tmax = d
        ray.u = u
        ray.v = v
        ray.x = v1 + edge1*u + edge2*v
        ray.n = normalize(cross(edge1, edge2))
        
        return true
    }

    /// BVH traversal
    func intersect(node: BVH, inout ray: _Ray) -> Bool {
        // FIXME: somehow I mistrust this line below
        guard _Scene.boxIntersect(a: node.box.a, b: node.box.b, ray: &ray) else { return false }

        switch node.type {
        case let .Leaf(i):
            let p = primitiveBuffer[i]
            let result: Bool
            
            // check the intersection with the primitive
            switch p.type {
            case let .Triangle(i1, i2, i3):
                let v1 = vertexBuffer[i1]
                let v2 = vertexBuffer[i2]
                let v3 = vertexBuffer[i3]
                result = _Scene.triangleIntersect(v1: v1, v2: v2, v3: v3, ray: &ray)
                
            case let .Sphere(ic, r):
                let center = vertexBuffer[ic]
                result = _Scene.sphereIntersect(pos: center, rad: r, ray: &ray)
            }
            
            // update ray with the primitive information
            if result {
                ray.gid = p.gid
                ray.pid = p.pid
            }
            
            return result
        
        // check the intersection with both children
        case let .Node(l, r):
            let lbool = intersect(l, ray: &ray)
            let rbool = intersect(r, ray: &ray)
            
            return lbool || rbool
        }
    }
    
    /// Contains the BVH tree
    struct BVH {
        /// We use this structure only when building the tree
        struct NodeBox {
            /// Encapsulates the AABB of the node
            let box: Box
            /// The id used to retrieve the primitive from the scene buffer
            let global: IndexType
        }
        
        indirect enum NodeType {
            case Leaf(i: IndexType)
            case Node(l: BVH, r: BVH)
        }

        let type: NodeType
        let box: Box

        /// Returns the union of two AABB
        static func merge(lhs: Box, _ rhs: Box) -> Box { return Box(a: min(lhs.a, rhs.a), b: max(lhs.b, rhs.b)) }

        init(_ list: [NodeBox]) throws {
            guard list.count > 0 else { throw _SceneError.BuildingTree("BVH Node needs at least one node") }
            guard list.count > 1 else {
                type = .Leaf(i: list[0].global)
                box = list[0].box
                return
            }
            
            // constants for the sah score (cost traversal and cost intersection)
            let Ct: Real = 1.0
            let Ci: Real = 4.0

            // compute the bounding box for this node
            let p: Box = list.reduce(Box.empty, combine: { BVH.merge($0, $1.box) })
            let t = list.count

            // choose an random axis and sort over it
            // FIXME: compute the sah score over the three axis and choose the smallest
            let axis = Int(drand48() * 3)
            let sorted = list.sort({ $0.box.c[axis] < $1.box.c[axis] })

            // iterate over all possible paritions in this axis
            let (_, index) = sorted.indices.reduce((Real(0), IndexType.Invalid), combine: {
                let l: Box = sorted[0..<$1].reduce(Box.empty, combine: { BVH.merge($0, $1.box) })
                let r: Box = sorted[$1..<t].reduce(Box.empty, combine: { BVH.merge($0, $1.box) })
                
                // compute sah for this partition
                let ls = l.s * Real($1)
                let rs = r.s * Real(t - $1)
                let sah = Ct + Ci * (ls + rs) / p.s
                let min: Real = 0.0
            
                return sah < min ? (sah, $1) : $0
            })
            
            // split the array in two
            let left  = []+sorted[0..<index]
            let right = []+sorted[index..<t]
            
            // initialize the node
            type = .Node(l: try BVH(left), r: try BVH(right))
            box = p
        }
    }
}
