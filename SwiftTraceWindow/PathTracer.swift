//
//  PathTracer.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/17/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

typealias Vec = double3

extension Vec {
    func dot(b : Vec) -> Double { return simd.dot(self, b) }
    func norm() -> Vec { return simd.normalize(self) }
}

func %  (a:Vec, b:Vec) -> Vec  { return simd.cross(a, b) }
func == (a:Vec, b:Vec) -> Bool { return a.x==b.x && a.y==b.y && a.z==b.z }

struct Ray {
    let o, d : Vec;
}

typealias Scalar = Double

extension Scalar {
    static let epsilon : Scalar = 1e-4
}

typealias Color = double3

extension Color {
    static let Red  =  Color(1, 0, 0)
    static let Green = Color(0, 1, 0)
    static let Blue  = Color(0, 0, 1)
    static let White = Color(1, 1, 1)
    static let Black = Color(0, 0, 0)
}

typealias byte = CUnsignedChar

struct PixelRGBA {
    let a : byte
    let r : byte
    let g : byte
    let b : byte
    
    init(color: Color) {
        self.r = byte(min(color.x, 1.0) * Scalar(byte.max))
        self.g = byte(min(color.y, 1.0) * Scalar(byte.max))
        self.b = byte(min(color.z, 1.0) * Scalar(byte.max))
        self.a = 0
    }
}

class Framebuffer {
    let width:Int, height: Int
    var pixels: [Color]

    init(width: Int, height:Int) {
        self.width = width
        self.height = height
        
        pixels = Array<Color>(count: width*height, repeatedValue: Color())
    }

    subscript(x:Int, y:Int) -> Color {
        get { return pixels[y * width + x] }
        set { pixels[y * width + x] = newValue }
    }
    
    func cgImage() -> CGImage {
        let imageData : UnsafeMutablePointer<PixelRGBA> = UnsafeMutablePointer(pixels.map({ (color) -> PixelRGBA in PixelRGBA(color: color) }))
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.NoneSkipFirst.rawValue)
        let bitmapContext = CGBitmapContextCreate(imageData, width, height, 8, width * 4, CGColorSpaceCreateDeviceRGB(), bitmapInfo.rawValue)
        return CGBitmapContextCreateImage(bitmapContext)!
    }
    
    func savePNG(name: String) -> String {
        let texture_url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, name, CFURLPathStyle.CFURLPOSIXPathStyle, false)
        let dest = CGImageDestinationCreateWithURL(texture_url, kUTTypePNG, 1, nil)!
        CGImageDestinationAddImage(dest, self.cgImage(), nil)
        let ok = CGImageDestinationFinalize(dest)
        if ok {
            print("png image written to path \(texture_url)")
            return String(texture_url)
        } else {
            print("something went wrong")
            return String()
        }
    }
}


enum Refl_t { case DIFF; case SPEC; case REFR }  // material types, used in radiance()

struct Sphere {
    let rad: Scalar       // radius
    let p, e, c: Vec      // position, emission, color
    let refl: Refl_t      // reflection type (DIFFuse, SPECular, REFRactive)

    // Solve t^2*d.d + 2*t*(o-p).d + (o-p).(o-p)-R^2 = 0
    // returns distance, 0 if nohit
    func intersect(r: Ray) -> Scalar {
        let op = p - r.o
        let b = op.dot(r.d)
        let det = b*b - op.dot(op) + rad*rad
        
        if det < 0 {
            return 0
        }
        
        let det2 = sqrt(det)
        let t1 = b-det2
        if t1 > Scalar.epsilon {
            return t1
        }
        
        let t2 = b+det2
        if t2 > Scalar.epsilon {
            return t2
        }
        
        return 0
    }
}

class Scene {
    let objects : [Sphere]
    let w: Int, h: Int, cx: Vec, cy: Vec, cam: Ray;
    let framebuffer: Framebuffer;
    var total_samples : Int = 0

    init(w:Int, h: Int) {
        self.w = w;
        self.h = h;
        
        // Loads the Cornell scene by default
        cam = Ray(o:Vec(x:50,y:52,z:295.6), d:Vec(x:0,y:-0.042612,z:-1).norm()) // cam pos, dir

        objects = [
            Sphere(rad:1e5, p:Vec(x: 1e5+1,y:40.8,z:81.6), e:Vec(), c:Vec(x:0.75,y:0.25,z:0.25), refl:Refl_t.DIFF),//Left
            Sphere(rad:1e5, p:Vec(x:-1e5+99,y:40.8,z:81.6),e:Vec(), c:Vec(x:0.25,y:0.25,z:0.75), refl:Refl_t.DIFF),//Rght
            Sphere(rad:1e5, p:Vec(x:50,y:40.8,z: 1e5),     e:Vec(), c:Vec(x:0.75,y:0.75,z:0.75), refl:Refl_t.DIFF),//Back
            Sphere(rad:1e5, p:Vec(x:50,y:40.8,z:-1e5+170), e:Vec(), c:Vec(),            refl:Refl_t.DIFF),//Frnt
            Sphere(rad:1e5, p:Vec(x:50,y: 1e5,z: 81.6),    e:Vec(), c:Vec(x:0.75,y:0.75,z:0.75), refl:Refl_t.DIFF),//Botm
            Sphere(rad:1e5, p:Vec(x:50,y:-1e5+81.6,z:81.6),e:Vec(), c:Vec(x:0.75,y:0.75,z:0.75), refl:Refl_t.DIFF),//Top
            Sphere(rad:16.5,p:Vec(x:27,y:16.5,z:47),       e:Vec(), c:Vec(x:1,y:1,z:1)*0.999,  refl:Refl_t.SPEC),//Mirr
            Sphere(rad:16.5,p:Vec(x:73,y:16.5,z:78),       e:Vec(), c:Vec(x:1,y:1,z:1)*0.999,  refl:Refl_t.REFR),//Glas
            Sphere(rad:600, p:Vec(x:50,y:681.6-0.27,z:81.6),e:Vec(x:12,y:12,z:12),   c:Vec(),  refl:Refl_t.DIFF) //Lite
            //  Sphere(rad:1, p:Vec(x:50,y:50,z:81.6),e:Vec(x:12,y:12,z:12),   c:Vec(),  refl:Refl_t.DIFF) //Lite
        ]

        cx = Vec(x:Double(w) * 0.5135 / Double(h), y:0, z:0)
        cy = (cx % cam.d).norm()*0.5135
        framebuffer = Framebuffer(width: w, height: h)
    }
    
    func intersect(r : Ray, inout t: Double, inout id: Int) -> Bool {
        let n = objects.count
        let inf = 1e20; //Double.infinity
        t = inf
        for (var i = n-1; i >= 0; i--) {
            let d = objects[i].intersect(r)
            if (d != 0.0 && d<t){
                t=d
                id=i
            }
        }
        return t<inf
    }
    
    func radiance(r: Ray, depthIn: Int, Xi : drand) -> Vec {
        var t : Double = 0                               // distance to intersection
        var id : Int = 0                             // id of intersected object
        if (!intersect(r, t: &t, id: &id)) {return Vec() } // if miss, return black
        let obj = objects[id]        // the hit object
        let x=r.o+r.d*t
        let n=(x-obj.p).norm()
        let nl = (n.dot(r.d) < 0) ? n : n * -1
        var f=obj.c
        let p = f.x > f.y && f.x > f.z ? f.x : f.y > f.z ? f.y : f.z; // max refl
        let depth = depthIn+1
        // Russian Roulette:
        if (depth>5) {
            // Limit depth to 150 to avoid stack overflow.
            if (depth < 150 && Xi.next()<p) {
                f=f*(1/p)
            } else {
                return obj.e
            }
        }
        switch (obj.refl) {
        case Refl_t.DIFF:                  // Ideal DIFFUSE reflection
            let r1=2*M_PI*Xi.next(), r2=Xi.next(), r2s=sqrt(r2);
            let w = nl
            let u = ((fabs(w.x)>0.1 ? Vec(x:0, y:1, z:0) : Vec(x:1, y:0, z:0)) % w).norm()
            let v = w % u
            
            let d1 = u*cos(r1)*r2s
            let d = (d1 + v*sin(r1)*r2s + w*sqrt(1-r2)).norm()
            
            
            return obj.e + f * radiance(Ray(o: x, d:d), depthIn: depth, Xi: Xi)
        case Refl_t.SPEC: // Ideal SPECULAR reflection
            return obj.e + f * (radiance(Ray(o:x, d:r.d-n*2*n.dot(r.d)), depthIn: depth, Xi: Xi))
        case Refl_t.REFR:
            let reflRay = Ray(o:x, d:r.d-n*2*n.dot(r.d))    // Ideal dielectric REFRACTION
            let into = n.dot(nl)>0                // Ray from outside going in?
            let nc = 1, nt=1.5
            let nnt = into ? Double(nc) / nt : nt / Double(nc)
            let ddn = r.d.dot(nl)
            let cos2t=1-nnt*nnt*(1-ddn*ddn)
            if (cos2t<0) {    // Total internal reflection
                return obj.e + f * radiance(reflRay, depthIn: depth, Xi: Xi)
            }
            let tdir = (r.d * nnt - n * ((into ? 1 : -1)*(ddn*nnt+sqrt(cos2t)))).norm()
            let a = nt-Double(nc), b = nt+Double(nc), R0 = a*a/(b*b), c = 1-(into ? -ddn : tdir.dot(n))
            let Re=R0+(1-R0)*c*c*c*c*c,Tr=1-Re,P=0.25+0.5*Re,RP=Re/P,TP=Tr/(1-P)
            return obj.e + f * (depth>2 ? (Xi.next()<P ?   // Russian roulette
                radiance(reflRay,depthIn: depth,Xi: Xi) * RP : radiance(Ray(o: x, d: tdir),depthIn: depth,Xi: Xi)*TP) :
                radiance(reflRay,depthIn: depth,Xi: Xi) * Re + radiance(Ray(o: x, d: tdir),depthIn: depth,Xi: Xi)*Tr);
        }
    }
    
    func raytrace(r:Ray, depthIn:Int) -> Vec {
        var t : Double = 0                               // distance to intersection
        var id : Int = 0                             // id of intersected object
        if (!intersect(r, t: &t, id: &id)) {return Vec() } // if miss, return black
        let obj = objects[id]        // the hit object
        let x=r.o+r.d*t // the hit point?
        let n=(x-obj.p).norm() // the hit normal
        let nl = (n.dot(r.d) < 0) ? n : n * -1
        
        if (depthIn > 5) {
            return Vec()
        }
        
        switch (obj.refl) {
        case Refl_t.DIFF:
            var f = Vec()
            for (var i = 0; i < objects.count; i++) {
                let light = objects[i]
                if light.e == Vec() { continue }
                let shadow_ray = Ray(o:x, d:(light.p-x).norm())
                var t2 : Double = 0                               // distance to intersection
                var id2 : Int = 0
                if (intersect(shadow_ray, t: &t2, id: &id2)) { // it shouldn't fail
                    if (i == id2) {
                        let int = max(0, -n.dot(shadow_ray.d)) * 0.2
                        f = f + light.e * int // lambertian
                    }
                } else {
                    print("it shouldnt fail")
                }
            }
            return obj.c * f + obj.c
            
        case Refl_t.SPEC: // Ideal SPECULAR reflection
            let reflected = Ray(o: x, d: r.d-n*2*n.dot(r.d))
            return obj.c * raytrace(reflected, depthIn: (depthIn+1)) * max(0, reflected.d.dot(n))
        case Refl_t.REFR:
            let reflRay = Ray(o:x, d:r.d-n*2*n.dot(r.d))    // Ideal dielectric REFRACTION
            let into = n.dot(nl)>0                // Ray from outside going in?
            let nc = 1, nt=1.5
            let nnt = into ? Double(nc) / nt : nt / Double(nc)
            let ddn = r.d.dot(nl)
            let cos2t=1-nnt*nnt*(1-ddn*ddn)
            if (cos2t<0) {    // Total internal reflection
                return obj.c * raytrace(reflRay, depthIn: depthIn+1)
            }
            let tdir = (r.d * nnt - n * ((into ? 1 : -1)*(ddn*nnt+sqrt(cos2t)))).norm()
            let a = nt-Double(nc), b = nt+Double(nc), R0 = a*a/(b*b), c = 1-(into ? -ddn : tdir.dot(n))
            let Re=R0+(1-R0)*c*c*c*c*c//,Tr=1-Re,P=0.25+0.5*Re,RP=Re/P,TP=Tr/(1-P)
            return obj.c * raytrace(reflRay,depthIn: depthIn+1) * Re + raytrace(Ray(o: x, d: tdir),depthIn: depthIn+1);
        }
    }
    
    func pathtrace(x:Int, y: Int, inout r: Vec, samps: Int, Xi: drand) {
        for (var sy=0; sy<2; sy++) {     // 2x2 subpixel rows
            for (var sx=0; sx<2; sx++) {        // 2x2 subpixel cols
                for (var s=0; s < samps; s++) {
                    let r1=2*Xi.next(), dx=r1<1 ? sqrt(r1)-1: 1-sqrt(2-r1)
                    let r2=2*Xi.next(), dy=r2<1 ? sqrt(r2)-1: 1-sqrt(2-r2)
                    let part1 = ( ( (Double(sx)+0.5 + Double(dx))/2 + Double(x))/Double(w) - 0.5)
                    let part2 =  ( ( (Double(sy)+0.5 + Double(dy))/2 + Double(y))/Double(h) - 0.5)
                    let d = cx * part1
                        + cy * part2
                        + cam.d
                    let rr = radiance(Ray(o:cam.o+d*140, d:d.norm()), depthIn: 0, Xi: Xi)
                    r = r + rr * (1.0 / Double(samps))
                } // Camera rays are pushed ^^^^^ forward to start in interior
            }
        }
    }
    
    func raytrace(x:Int, y: Int, inout r: Vec) {
        let part1 = Double(x)/Double(w) - 0.5
        let part2 = Double(y)/Double(h) - 0.5
        let d = cx * part1 + cy * part2 + cam.d
        r = raytrace(Ray(o:cam.o+d*140, d:d.norm()), depthIn: 0)
    }
    
    func render() {
        let samps = 1
        total_samples += samps
        let Xi = drand(a:UInt16(0xffff & (total_samples)))
        let globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        dispatch_apply(Int(h), globalQueue) {
            let y = Int($0)
        //for (var y = 0; y < h; y++) {
            for (var x = 0; x < self.w; x++) {   // Loop cols
                var r = Vec()
                
                self.pathtrace(x, y: y, r: &r, samps: samps, Xi: Xi);
                let result = r*0.25 // gamma correction
                
                let ratio : Double = (1/Double(self.total_samples))
                let old = self.framebuffer[x, (self.h-y-1)]
                let sample = Color(result.x, result.y, result.z)
                self.framebuffer[x, (self.h-y-1)] = sample * ratio + old * (1 - ratio)
                
                
                //raytrace(x, y: y, r: &r)
                
                //let result = r*0.25 // gamma correction
                
                //framebuffer[x, (h-y-1)] = Color(red: result.x, green: result.y, blue: result.z)
            }
        }
    }
}

struct drand {
  let pbuffer = UnsafeMutablePointer<UInt16>.alloc(3)
  init(a : UInt16) {
    pbuffer[2] = a
  }
  func next() -> Double { return erand48(pbuffer) }
}

