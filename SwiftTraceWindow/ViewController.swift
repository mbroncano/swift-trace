//
//  ViewController.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/15/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var hitImageView: NSImageView!
    @IBOutlet weak var hitsPerSecond: NSTextField!
    @IBOutlet weak var profilerTextField: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadScene()
    }

    func loadScene() {
        // dispatch the main routine
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            let width = 320, height = 240
            var scene: Scene
            let render: Renderer

            do {
                let file = NSBundle.mainBundle().pathForResource("scene", ofType: "json")!
                let data = NSData(contentsOfFile: file)!
                let json = try NSJSONSerialization.JSONObjectWithData(data, options: [])
                scene = try Scene.decode(json)
            } catch {
                print(error)
                return
            }
            
            // FIXME: choose the integrator from the scene file
            let integrator = PathTracer()
            render = Renderer(scene: &scene, w: width, h: height, integrator: integrator)
//            let render = DistributedRayTracer(scene: scene, w: width, h: height)
//            let render = WhittedTracer(scene: scene, w: width, h: height)
            
            var totalFrameTime:NSTimeInterval = 0
            var lastFrameDisplayed: NSTimeInterval = NSDate().timeIntervalSince1970
            var totalHits = 0
            while true {
                let lastFrameStart = NSDate().timeIntervalSince1970
                
                // render a frame
                render.render() //Tile(size: 64)
                
                // compute stats
                let lastFrameDuration = NSDate().timeIntervalSince1970 - lastFrameStart
                totalFrameTime = totalFrameTime + lastFrameDuration
                let lastFrameTime = Int(lastFrameDuration * 1000)
                let avgFrameTime = Int(totalFrameTime * 1000 / Double(render.framebuffer.samples))
                print("Profiler: frame in \(lastFrameTime)ms, avg. \(avgFrameTime)ms")
                
                // compute more stats
                let hits = UnsafeMutableBufferPointer<Intersection>(start: render.framebuffer.hit, count: render.framebuffer.length)
                totalHits += 320 * 240 //hits.reduce(0) { $0 + $1.count }
                let hps = Scalar(totalHits) / Scalar(render.framebuffer.samples) / Scalar(lastFrameDuration)

                // update window on the main loop
                dispatch_async(dispatch_get_main_queue()) {
                    self.hitsPerSecond!.stringValue = "Avg. hits: \(Int(hps/1e6)) Mh/s"
                    self.profilerTextField!.stringValue = "Frame in \(lastFrameTime)ms, Avg. \(avgFrameTime)ms"
                    self.view.window!.title = "Samples \(render.framebuffer.samples)"
                }
                
                // update the UI at least twice a second 
                if NSDate().timeIntervalSince1970 - lastFrameDisplayed < 0.5 { continue }
                lastFrameDisplayed = NSDate().timeIntervalSince1970
                
                // FIXME: warn the user if there is any problem
                guard let image = render.framebuffer.cgImage() else { continue }
//                guard let hitImage = render.framebuffer.hitImage() else { continue }
                
                dispatch_async(dispatch_get_main_queue()) {
                    self.imageView!.image = NSImage(CGImage: image, size: NSZeroSize)
//                    self.hitImageView!.image = NSImage(CGImage: hitImage, size: NSZeroSize)
                }
            }
        }
    }
    
    override var representedObject: AnyObject? {
        didSet {
            // Update the view, if already loaded.
        }
    }


}

