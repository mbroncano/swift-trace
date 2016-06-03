//
//  Core.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 6/2/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import Decodable
import simd

public typealias Real = Double
extension Real {
    static let Eps = Real(FLT_EPSILON)
}

public typealias Vector = simd.double3
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
    case InvalidMaterial(String)
}

struct _Ray {
    /// origin of the ray
    var o: Vector
    /// direction of the ray
    var d: Vector
    /// near segment
    let tmin: Real = 0
    /// far segment
    var tmax: Real = Real.infinity
    
    /// hit point
    var x: Vector = Vector()
    /// geometric normal
    var n: Vector = Vector()
    /// barycentric coordinates
    var u: Real = 0
    var v: Real = 0
    /// geometry and primitive id
    var gid: IndexType = IndexType.Invalid
    var pid: IndexType = IndexType.Invalid
    
    /// intersection count
    var count: Int = 0
    
    init(o: Vector, d: Vector) {
        self.o = o
        self.d = d
    }
    
    // resets direction and some hit information for the ray
    mutating func reset(o o: Vector, d: Vector) {
        self.o = o
        self.d = d
        tmax = Real.infinity
        gid = IndexType.Invalid
    }
}

struct _Scene {
    // FIXME: compare this to UnsafeMutablePointer
    typealias VertexBuffer = ContiguousArray<Vector>
    typealias PrimitiveBuffer = ContiguousArray<Primitive>
    typealias GeometryBuffer = ContiguousArray<Geometry>
    typealias BoxBuffer = ContiguousArray<Box>

    /// Primitives that are part of the scene
    enum PrimitiveType {
        /// A sphere
        case Sphere(ic: IndexType, rad: Real)
        /// A single triangle
        case Triangle(i1: IndexType, i2: IndexType, i3: IndexType)
    }
    
    /// Geometry shapes
    enum Shape {
        /// A sphere
        case Sphere(center: Vector, radius: Real)
        /// A single triangle with optional normals and texture coordinates
        case Triangle(v: [Vector], n: [Vector], t:[Vector])
        /// A group of shapes (note: only a single depth level allowed)
        case Group(shapes: [Shape])
//        case Mesh(f: [[IndexType]], v: [Vector], vn: [Vector], vt: [Vector])
    }
    
    
    /// A scene contains a set of primitives derives from the geometries
    struct Primitive {
        /// the particular primitive type
        let type: PrimitiveType
        /// the geometry identifier
        let gid: GeometryId
        /// the particular primitive within the geometry
        let pid: PrimitiveId
    }
    
    /// A geometry contains shape(s) with a particular material
    struct Geometry {
        /// a shape that will be converted into primitives
        let shape: Shape
        /// the material identifier
        let material: MaterialId
    }

    /// AABB for a 3d primitve
    struct Box {
        /// the opposed sqaures of the box
        let a, b: Vector
        /// the geometric center of the box
        let c: Vector
        /// the surface area of the box
        let s: Real
        
        /// the empty box (degenerate)
        static let empty = Box(a: Vector.Inf, b: -Vector.Inf)
        
        init(a: Vector, b: Vector) {
            let ba = b-a

            self.a = a
            self.b = b
            self.c = a + ba * 0.5
            self.s = 2 * (ba.x*ba.y + ba.x*ba.z + ba.y*ba.z)
        }
    }

    /// contains the vertices for the scene primitives
    let vertexBuffer: VertexBuffer
    /// contains the scene primitives
    let primitiveBuffer: PrimitiveBuffer
    /// contains the geometries in the scene
    let geometryBuffer: GeometryBuffer
    /// contains the aabb for the scene primitives
    let boxBuffer: BoxBuffer
    /// contains the camera
    let camera: _Camera
    
    func background(ray: _Ray) -> Vector {
        // FIXME: implement infinity sphere
        return Vector(0.5, 0.5, 0.5) // some blueish color
    }
    
    let materials: [MaterialId: _Material] = [
        MaterialId("Red")       : _Material(Kd:Vector(0.75, 0.25, 0.25), Ke: Vector()),  // Red diffuse
        MaterialId("Green")     : _Material(Kd:Vector(0.25, 0.75, 0.25), Ke: Vector()),  // Green diffuse
        MaterialId("Blue")      : _Material(Kd:Vector(0.25, 0.25, 0.75), Ke: Vector()),  // Blue diffuse
        MaterialId("White")     : _Material(Kd:Vector(0.75, 0.75, 0.75), Ke: Vector()),  // White diffuse
        MaterialId("Black")     : _Material(Kd:Vector(0.05, 0.05, 0.05), Ke: Vector()),  // Black
        MaterialId("Lite")      : _Material(Kd:Vector(0.05, 0.05, 0.05), Ke: Vector(8)), // Lite
    ]
    
    func material(gid: GeometryId) throws -> _Material {
        guard let material = materials[geometryBuffer[gid].material]
        else { throw _SceneError.InvalidMaterial("material or geometry not found") }

        return material
    }
    
    /// BVH root node
    typealias BVHBuffer = ContiguousArray<BVH>
    typealias BVHIndex = IndexType
    let bvhBuffer: BVHBuffer
    let bvhRoot: BVHIndex


    init(camera: _Camera, geometry: [Geometry]) throws {
        self.camera = camera
        // FIXME: create SOA for this
        var vBuffer = VertexBuffer()
        var pBuffer = PrimitiveBuffer()
        var gBuffer = GeometryBuffer()
        var bBuffer = BoxBuffer()
        var tBuffer = BVHBuffer()
        
        // add primitives
        for g in geometry { try _Scene.addGeometry(g, gBuffer: &gBuffer, vBuffer: &vBuffer, pBuffer: &pBuffer, bBuffer: &bBuffer) }

        // build bvh
        // precompute boxes for primitives
        let list = pBuffer.indices
        let boxes = list.map({ BVH.NodeBox(box: bBuffer[$0], global:$0) })
        let root = try BVH(boxes, nodes: &tBuffer)
        tBuffer.append(root)
        
        // initialize members
        self.vertexBuffer = vBuffer
        self.primitiveBuffer = pBuffer
        self.geometryBuffer = gBuffer
        self.boxBuffer = bBuffer
        self.bvhBuffer = tBuffer
        self.bvhRoot = tBuffer.endIndex - 1
    }
    
    /// Inserts a geometry into the scene
    static func addGeometry(geometry: Geometry, inout gBuffer: GeometryBuffer, inout vBuffer: VertexBuffer, inout pBuffer: PrimitiveBuffer, inout bBuffer: BoxBuffer) throws {
        let gid = gBuffer.endIndex

        try addShape(geometry.shape, gid: gid, pid: 0, vBuffer: &vBuffer, pBuffer: &pBuffer, bBuffer: &bBuffer)
        gBuffer.append(geometry)
    }

    /// Inserts a shape into the scene
    static func addShape(shape: Shape, gid: GeometryId, pid: PrimitiveId, inout vBuffer: VertexBuffer, inout pBuffer: PrimitiveBuffer, inout bBuffer: BoxBuffer) throws {
        let vi = vBuffer.endIndex

        switch shape {
        case let .Triangle(v, _, _):
            guard v.count == 3 else { throw GeometryError.InvalidShape("A triangle needs three vertices") }
//            guard n.count == 0 || n.count == 3 else { throw GeometryError.InvalidShape("A triangle needs three normals or none") }
//            guard t.count == 0 || t.count == 3 else { throw GeometryError.InvalidShape("A triangle needs three textcoords or none") }
            vBuffer += v
        
            let ptype = PrimitiveType.Triangle(i1: vi, i2: vi+1, i3: vi+2)
            pBuffer.append(Primitive(type: ptype, gid: gid, pid: pid))
            
            bBuffer.append(Box(a: min(min(v[0], v[1]), v[2]), b: max(max(v[0], v[1]), v[2])))
        
        case let .Sphere(center, radius):
            vBuffer += [center]

            let ptype = PrimitiveType.Sphere(ic: vi, rad: radius)
            pBuffer.append(Primitive(type: ptype, gid: gid, pid: pid))
            
            bBuffer.append(Box(a: center-Vector(radius), b: center+Vector(radius)))
        
        case let .Group(shapes):
            try shapes.enumerate().forEach({ (index, shape) in
                if case .Group = shape { throw GeometryError.InvalidShape("Nesting shape groups not supported") }
                try addShape(shape, gid: gid, pid: index, vBuffer: &vBuffer, pBuffer: &pBuffer, bBuffer: &bBuffer)
            })
        }
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

    func intersect(inout ray: _Ray) throws -> Bool {
        return intersect(bvhRoot, ray: &ray)
    }

    /// BVH traversal
    private func intersect(ni: BVHIndex, inout ray: _Ray) -> Bool {
//        ray.count += 1    
        let node = bvhBuffer[ni]

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
            guard _Scene.boxIntersect(a: node.box.a, b: node.box.b, ray: &ray) else { return false }

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
        
        enum NodeType {
            case Leaf(i: IndexType)
            case Node(l: BVHIndex, r: BVHIndex)
        }

        let type: NodeType
        let box: Box

        /// Returns the union of two AABB
        static func merge(lhs: Box, _ rhs: Box) -> Box { return Box(a: min(lhs.a, rhs.a), b: max(lhs.b, rhs.b)) }

        init(_ list: [NodeBox], inout nodes: ContiguousArray<BVH>) throws {
            guard list.count > 0 else { throw _SceneError.BuildingTree("BVH Node needs at least one node") }
            guard list.count > 1 else {
                type = .Leaf(i: list[0].global)
                box = list[0].box
                nodes.append(self)
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
            let (_, index) = sorted.indices.reduce((Real.infinity, IndexType.Invalid), combine: {
                // skip the first and last iteration
                guard $1>0 && $1<t else { return $0 }
            
                let l: Box = sorted[0..<$1].reduce(Box.empty, combine: { BVH.merge($0, $1.box) })
                let r: Box = sorted[$1..<t].reduce(Box.empty, combine: { BVH.merge($0, $1.box) })
                
                // compute sah for this partition
                let ls = l.s * Real($1)
                let rs = r.s * Real(t - $1)
                let sah = Ct + Ci * (ls + rs) / p.s
            
                return sah < $0.0 ? (sah, $1) : $0
            })
            
            // split the array in two
            let left  = []+sorted[0..<index]
            let right = []+sorted[index..<t]
            
            // insert the two nodes
            let ln = try BVH(left, nodes: &nodes)
            let li = nodes.endIndex
            nodes.append(ln)
            let rn = try BVH(right, nodes: &nodes)
            let ri = nodes.endIndex
            nodes.append(rn)
            
            // initialize the node
            type = .Node(l: li, r: ri)
            box = p
        }
    }
    
    // FIXME: this should incorporate the data and return the gid
    static func importObject(obj: ObjectLibrary) throws -> _Scene.Shape {
        
        var ret = [Shape]()
        
        try obj.faces.forEach { face in
            guard face.elements[0].type != nil else { throw ObjectLoaderError.InvalidFace("Invalid type for face") }
        
            for index in 2..<face.elements.count {
                let slice = face.elements[(index-2)...index]
        
                var p = [Vector]()
                var t = [Vector]()
                var n = [Vector]()
                
                for element in slice {
                    guard let pi = obj.vertices[index: element.vi]
                    else { throw ObjectLoaderError.InvalidFace("invalid vertex index") }
                    
                    p.append(Vector(pi))
                    
                    // FIXME: this won't detect whether the index is out of bouds or zero
                    if let ti = obj.textvert[index: element.ti] { t.append(Vector(ti)) }
                    if let ni = obj.normals[index: element.ni] { n.append(Vector(ni)) }
                }
                
                ret += [_Scene.Shape.Triangle(v: p, n: n, t: t)]
            }
        }
        
        return _Scene.Shape.Group(shapes: ret)
    }
}

extension Float: Castable {}

extension Vector: Decodable {
    init(v: [Real]) throws {
        if v.count == 0 {
            self.init(0, 0, 0)
        } else if v.count == 1 {
            self.init(Real(v[0]), Real(v[0]), Real(v[0]))
        } else if v.count == 3 {
            self.init(Real(v[0]), Real(v[1]), Real(v[2]))
        } else {
            throw GeometryError.InvalidShape("Vector can only have 0, 1 or 3 elements")
        }
    }
    
    public static func decode(json: AnyObject) throws -> Vector {
        return try Vector(v: json as! [Real])
    }
}

extension _Scene.Shape: Decodable {
    internal static func decode(json: AnyObject) throws -> _Scene.Shape {
        let type = try json => "type" as String
        switch type {
        /// sphere
        case "s":
            return _Scene.Shape.Sphere(center: try json => "p", radius: try json => "r")
        /// triangle
        case "t":
            let p1 = try json => "p1" as Vector
            let p2 = try json => "p2" as Vector
            let p3 = try json => "p3" as Vector
            return _Scene.Shape.Triangle(v: [p1, p2, p3], n: [], t: [])
        /// group
        case "m":
            return _Scene.Shape.Group(shapes: try json => "l")
        /// object
        case "o":
            // FIXME: please note this ignores the material in the file
            let obj = try ObjectLibrary(name: try json => "file")
            return try _Scene.importObject(obj)
        default:
            throw GeometryError.InvalidShape("The shape type is invalid: \(type)")
        }
    }
}

extension _Scene.Geometry: Decodable {
    internal static func decode(json: AnyObject) throws -> _Scene.Geometry {
        let material = try json => "m" as String
        let shape = try _Scene.Shape.decode(json)
        
        return _Scene.Geometry(shape: shape, material: material.hashValue)
    }
}

extension _Scene: Decodable {
    internal static func decode(json: AnyObject) throws -> _Scene {
        return try _Scene(camera: try json => "camera", geometry: try json => "primi")
    }
}

struct Sampler {
    /// Sample point in unit disk
    static func sampleDisk() -> Vector {
        var v: Vector
        repeat {
            v = 2.0 * Vector(Real(drand48()), Real(drand48()), 0) - Vector(1, 1, 0)
        } while (dot(v, v) >= 1.0)
        return v
    }
}

// Complex camera with arbitrary positioning, DOF/antialias
struct _Camera {
    private
    let origin: Vector
    let lowerLeftCorner: Vector
    let horizontal: Vector
    let vertical: Vector
    let lensRadius: Real
    let u, v, w: Vector
    
    init(pos: Vector, dir: Vector, up: Vector, focalLenght: Real, width: Real, height: Real) {
        self.init(lookFrom: pos,
                  lookAt: pos+dir*(1/focalLenght),
                  vecUp: up,
                  fov: 180*asin(width * focalLenght) / Real(M_PI),
                  aspect: 0)
    }
    
    init(lookFrom: Vector, lookAt: Vector, vecUp: Vector, fov: Real, aspect: Real, aperture: Real = 0.0) {
        origin = lookFrom
        let focusDist = length(lookFrom - lookAt)
        lensRadius = aperture / 2.0

        let theta = fov * Real(M_PI) / 180
        let halfHeight = tan(theta/2)
        let halfWidth = aspect * halfHeight
        w = normalize(lookFrom - lookAt)
        u = normalize(cross(vecUp, w))
        v = cross(w, u)

        lowerLeftCorner = origin - halfWidth * u * focusDist - halfHeight * v * focusDist - w * focusDist
        horizontal = 2 * halfWidth * u * focusDist
        vertical = 2 * halfHeight * v * focusDist
    }
    
    func generateRay(x x: Int, y: Int, nx: Int, ny: Int) -> _Ray {
        // depth of field
        let lens = Sampler.sampleDisk() * lensRadius
        let ofs = u * lens.x + v * lens.y
    
        // antialias
        let r1 = Real(drand48()) - 0.5
        let r2 = Real(drand48()) - 0.5

        // ray direction
        let s = (Real(x) + r1) / Real(nx-1)
        let t = (Real(y) + r2) / Real(ny-1)
        let d = lowerLeftCorner +  s * horizontal + t * vertical - origin - ofs
        
        return _Ray(o: origin + ofs, d: normalize(d))
    }
}

extension _Camera: Decodable {
    static func decode(json: AnyObject) throws -> _Camera {
        return try _Camera(
            lookFrom: json => "look_from",
            lookAt: json => "look_at",
            vecUp: json => "vec_up",
            fov: json => "fov",
            aspect: json => "aspect",
            aperture: json => "aperture"
        )}
}


typealias MaterialId = Int
extension MaterialId {
    static let None = MaterialId("__None")
    init(_ s: String) { self.init(s.hashValue) }
}

struct _Material {
    // diffuse
    let Kd: Vector
    // emission
    let Ke: Vector
    
    func color(ray: _Ray) -> Vector {
        return Kd
    }
    
    func sample(ray: _Ray) -> (Real, Vector) {
        // cosine weighted sampling
        // see: http://mathworld.wolfram.com/SpherePointPicking.html
        
        let r1 = Real(2*M_PI) * Real(drand48())
        let r2 = Real(drand48())
        let r2s = sqrt(r2)
        let w = dot(ray.n, ray.d) < 0 ? ray.n: ray.n * -1 // corrected normal (always exterior)
        let u = normalize(cross((fabs(w.x)>Real.Eps ? Vector(0, 1, 0) : Vector(1, 0, 0)), w))
        let v = cross(w, u)
        
        let d1 = u * cos(r1) * r2s
        let d = normalize((d1 + v * sin(r1) * r2s + w * sqrt(1 - r2)))

        return (1.0, d)
    }
}