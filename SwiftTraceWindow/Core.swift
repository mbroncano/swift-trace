//
//  Core.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 6/2/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

public typealias Real = Double
extension Real {
    static let Eps = Real(FLT_EPSILON)
}

func clamp(n: Real) -> Real {
    return max(1, min(0, n))
}

public typealias Matrix3x3 = simd.double3x3

public typealias Vector = simd.double3
extension Vector {
    static let Inf = Vector(Real.infinity)
    
    var localFrame: simd.double3x3 { get {
        let v1 = normalize(self)
        let v2 = v1.x > v1.y ? Vector(-v1.z, 0.0, v1.x) : Vector(0.0, v1.z, -v1.y)
        let v3 = cross(normalize(v2), v1)
        return Matrix3x3([v1,v2,v3])
        }}
}

typealias IndexType = Int
extension IndexType {
    static let Invalid = -1
}

typealias GeometryId = IndexType
typealias PrimitiveId = IndexType
typealias MaterialIndex = IndexType
typealias BVHIndex = IndexType
typealias VertexIndex = IndexType
typealias TransformId = IndexType

enum GeometryError: ErrorType {
    case InvalidShape(String)
}

enum _SceneError: ErrorType {
    case BuildingTree(String)
    case InvalidMaterial(String)
    case NotImplemented(String)
}

struct _Ray {
    /// origin of the ray
    var o: Vector
    /// direction of the ray
    var d: Vector
    /// near segment
    var tmin: Real = 0
    /// far segment
    var tmax: Real = Real.infinity
    
    /// hit point
    var x: Vector = Vector()
    /// geometric normal
    var n: Vector = Vector()
    /// barycentric coordinates
    var u: Real = 0
    var v: Real = 0
    /// geometry, primitive id and material index
    var gid: GeometryId = IndexType.Invalid
    var pid: PrimitiveId = IndexType.Invalid
    var mid: MaterialIndex = IndexType.Invalid
    
    /// intersection count
    var count: Int = 0
    
    init(o: Vector, d: Vector) {
        self.o = o
        self.d = d
    }

    init(o: Vector, d: Vector, tmin: Real, tmax: Real) {
        self.o = o
        self.d = d
        self.tmin = tmin
        self.tmax = tmax
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
    /// Primitives that are part of the scene
    enum PrimitiveType {
        /// A sphere
        case Sphere(ic: VertexIndex, rad: Real)
        /// A single triangle
        case Triangle(i1: VertexIndex, i2: VertexIndex, i3: VertexIndex)
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
        /// the material index for the primitive
        let mid: MaterialIndex
        /// the transform index for the primitive
        let tid: TransformId
    }
    
    /// A geometry contains shape(s) with a particular material
    struct Geometry {
        /// a shape that will be converted into primitives
        let shape: Shape
        /// the material identifier
        let material: MaterialId
        /// the geometry transform
        let transform: Transform?
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

    /// contains the camera
    let camera: _Camera
    
    /// BVH root node
    let bvhRoot: BVHIndex

    /// Convenience aliases for the different buffers
    typealias VertexBuffer = ContiguousArray<Vector>
    typealias PrimitiveBuffer = ContiguousArray<Primitive>
    typealias GeometryBuffer = ContiguousArray<Geometry>
    typealias BoxBuffer = ContiguousArray<Box>
    typealias BVHBuffer = ContiguousArray<BVH>
    typealias MaterialBuffer = ContiguousArray<_Material>
    typealias IndexBuffer = ContiguousArray<GeometryId>
    typealias TransformBuffer = ContiguousArray<Transform>

    /// The different buffers used in the scene
    struct BufferSOA {
        /// contains the vertices for the scene primitives
        var vertex = VertexBuffer()
        /// contains the scene primitives
        var primitive = PrimitiveBuffer()
        /// contains the geometries in the scene
        var geometry = GeometryBuffer()
        /// contains the subset of the geometries that emit light
        var light = IndexBuffer()
        /// contains the aabb for the scene primitives
        var box = BoxBuffer()
        /// contains the nodes for the bvh
        var bvh = BVHBuffer()
        /// contains the materials
        var material = MaterialBuffer()
        /// contains the transforms
        var transform = TransformBuffer()
    }

    /// Index for the root bvh node
    let buffer: BufferSOA

    /// Create the scene for a set of geometries and a camera
    init(camera: _Camera, geometry: [Geometry], material: [_Material]) throws {
        var buffer = BufferSOA()
    
        // add materials
        for m in material { buffer.material.append(m) }
    
        // add primitives
        for g in geometry { try _Scene.addGeometry(g, buffer: &buffer) }
        
        // precompute node boxes for primitives
        let boxes = buffer.primitive.indices.map({ BVH.NodeBox(box: buffer.box[$0], global:$0) })

        // build bvh
        print("building the bvh tree ...")
        let root = try BVH(boxes, nodes: &buffer.bvh)
        buffer.bvh.append(root)
        
        // initialize members
        self.camera = camera
        self.buffer = buffer
        self.bvhRoot = buffer.bvh.endIndex - 1
    }
    
    /// Inserts a geometry into the scene
    static func addGeometry(geometry: Geometry, inout buffer: BufferSOA) throws {
        let gid = buffer.geometry.endIndex
        let mid = buffer.material.enumerate().reduce(IndexType.Invalid, combine:
            { return geometry.material == $1.1.name ? $1.0 : $0 })

        guard mid != IndexType.Invalid else { throw _SceneError.InvalidMaterial("material not found") }
        
        try addShape(geometry.shape, gid: gid, pid: 0, mid: mid, buffer: &buffer, transform: geometry.transform)

        buffer.geometry.append(Geometry(shape: geometry.shape, material: geometry.material, transform: geometry.transform))
    }
    
    /// Inserts a new bounding box for a primitive
    static func addBox(box: Box, inout buffer: BufferSOA, transform: Transform? = nil) {
        var box = box

        // apply transform to bounding box
        if transform != nil {
            let a = transform!.apply(point: box.a)
            let b = transform!.apply(point: box.b)
            box = Box(a: a, b: b)
        }
        
        buffer.box.append(box)
    }
    
    static func addPrimitive(ptype: _Scene.PrimitiveType, gid: GeometryId, pid: PrimitiveId, mid: MaterialIndex, box: Box, inout buffer: BufferSOA, transform: Transform? = nil) {
        // if the primitive belongs to a light, add it to the light array
        if buffer.material[mid].isLight {
            buffer.light.append(buffer.primitive.endIndex)
        }

        // if there's a transform, add it and apply transform to bounding box
        var box = box
        var tid = TransformId.Invalid
        if transform != nil {
            tid = buffer.transform.endIndex
            buffer.transform.append(transform!)
        
            let a = transform!.apply(point: box.a)
            let b = transform!.apply(point: box.b)
            box = Box(a: a, b: b)
        }
        
        buffer.box.append(box)

        let primitive = Primitive(type: ptype, gid: gid, pid: pid, mid: mid, tid:tid)
        buffer.primitive.append(primitive)
    }

    /// Inserts a shape into the scene
    static func addShape(shape: Shape, gid: GeometryId, pid: PrimitiveId, mid: MaterialIndex, inout buffer: BufferSOA, transform: Transform? = nil) throws {
        let vi = buffer.vertex.endIndex

        switch shape {
        case let .Triangle(v, _, _):
            guard v.count == 3 else { throw GeometryError.InvalidShape("A triangle needs three vertices") }
//            guard n.count == 0 || n.count == 3 else { throw GeometryError.InvalidShape("A triangle needs three normals or none") }
//            guard t.count == 0 || t.count == 3 else { throw GeometryError.InvalidShape("A triangle needs three textcoords or none") }

            // add vertices and create primitive
            buffer.vertex += v
            let ptype = PrimitiveType.Triangle(i1: vi, i2: vi+1, i3: vi+2)
            let box = Box(a: min(min(v[0], v[1]), v[2]), b: max(max(v[0], v[1]), v[2]))
     
            addPrimitive(ptype, gid: gid, pid: pid, mid: mid, box: box, buffer: &buffer, transform: transform)
        
        case let .Sphere(center, radius):

            // add vertices and create primitive
            buffer.vertex += [center]
            let ptype = PrimitiveType.Sphere(ic: vi, rad: radius)
            let box = Box(a: center-Vector(radius), b: center+Vector(radius))
            
            addPrimitive(ptype, gid: gid, pid: pid, mid: mid, box: box, buffer: &buffer, transform: transform)
        
        case let .Group(shapes):
            try shapes.enumerate().forEach({ (index, shape) in
                if case .Group = shape { throw GeometryError.InvalidShape("Nesting shape groups not supported") }
                try addShape(shape, gid: gid, pid: index, mid: mid, buffer: &buffer, transform: transform)
            })
        }
    }
    
    func background(ray: _Ray) -> Vector {
        // FIXME: implement infinity sphere
        return Vector(0.1, 0.1, 0.1) // some greish color
    }
    
    func material(mid: MaterialIndex) -> _Material {
        return buffer.material[mid]
    }
    
            
    static func cosineSampleHemisphere(u1: Real, _ u2: Real, _ n: Vector) -> (Real, Vector) {
        let r = sqrt(u1)
        let theta = 2 * M_PI * u2
        
        let x = r * cos(theta)
        let y = r * sin(theta)
        let z = sqrt(max(0.0, 1 - u1))
        
        let u = cross(n.x > 0 ? Vector(0, 1, 0) : Vector(1, 0, 0), n)
        let v = cross(n, u)
        
        let d = u*x + v*y + v*z
        
        return (M_2_PI, d)
    }
    
    func sampleLight(pid: PrimitiveId, ray: _Ray) throws -> (Real, Vector, MaterialId) {
        let p = buffer.primitive[pid]
        
        // transform hit point from world to object
        var hit = ray.x
        if p.tid != TransformId.Invalid {
            let t = buffer.transform[p.tid].reverse()
            hit = t.apply(point: ray.x)
        }
        
        // check the intersection with the primitive
        switch p.type {
        case let .Sphere(ic, r):
            let center = buffer.vertex[ic]
            // generate the sample, rotated toward the hit point
            let (pdf, sample) = _Scene.cosineSampleHemisphere(Real(drand48()), Real(drand48()), normalize(hit - center))

            // compute the point on the sphere
            var tsample = center + r * sample
            
            // transform from local back to world
            if p.tid != TransformId.Invalid {
                let t = buffer.transform[p.tid]
                tsample = t.apply(point: tsample)
            }
            
            return (pdf, tsample, p.mid)
        default:
//        case let .Triangle(i1, i2, i3):
//            let v1 = buffer.vertex[i1]
//            let v2 = buffer.vertex[i2]
//            let v3 = buffer.vertex[i3]
            throw _SceneError.NotImplemented("sampling not implemented for this shape")
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
        ray.count += 1    
        let node = buffer.bvh[ni]

        switch node.type {
        case let .Leaf(i):
            let p = buffer.primitive[i]
            let g = buffer.geometry[p.gid]
            let result: Bool
            
            // check if the geometry contains a transform
            var tray = ray
            if p.tid != TransformId.Invalid {
                let t = buffer.transform[p.tid].reverse()
                tray.o = t.apply(point: ray.o)
                tray.d = t.apply(vector: ray.d)
            }
            
            // check the intersection with the primitive
            switch p.type {
            case let .Triangle(i1, i2, i3):
                let v1 = buffer.vertex[i1]
                let v2 = buffer.vertex[i2]
                let v3 = buffer.vertex[i3]
                result = _Scene.triangleIntersect(v1: v1, v2: v2, v3: v3, ray: &tray)
                
            case let .Sphere(ic, r):
                let center = buffer.vertex[ic]
                result = _Scene.sphereIntersect(pos: center, rad: r, ray: &tray)
            }
            
            // reverse the transform and recover the original ray
            if g.transform != nil {
                tray.o = ray.o
                tray.d = ray.d
            }
            ray = tray
            
            // update ray with the primitive information
            if result {
                ray.gid = p.gid
                ray.pid = p.pid
                ray.mid = p.mid
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

typealias MaterialId = Int
extension MaterialId {
    static let None = MaterialId("__None")
    init(material: String) { self.init(material.hashValue) }
}

/// Lambertian material
struct _Material {
    // id
    let name: MaterialId
    // diffuse
    let Kd: Vector
    // emission
    let Ke: Vector
    
    var isLight: Bool { get { return reduce_max(Ke) > 0 } }
    
    func color(ray: _Ray) -> Vector {
        return Kd
    }
    
    func eval(ray: _Ray, n: Vector, wi: Vector) -> Vector {
        return color(ray) * (M_1_PI) * clamp(dot(wi, n))
    }
    
    func sample(ray: _Ray) -> (Real, Vector) {
        // cosine weighted sampling
        let r1 = Real(2*M_PI) * Real(drand48())
        let r2 = Real(drand48())
        let r2s = sqrt(r2)

        // corrected normal (always exterior)
        let w = dot(ray.n, ray.d) < 0 ? ray.n: ray.n * -1
        
        // normal frame
        let u = normalize(cross((fabs(w.x) > 0 ? Vector(0, 1, 0) : Vector(1, 0, 0)), w))
        let v = cross(w, u)
        
        // compute the coordinates
        let x = u * cos(r1) * r2s
        let y = v * sin(r1) * r2s
        let z = w * sqrt(1 - r2)
        
        let d = normalize(x + y + z)

        return (M_2_PI, d)
    }
}