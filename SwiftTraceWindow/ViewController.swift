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
            let width = 256, height = 256
            let scene: _Scene
            let render: Renderer

            do {
                let file = NSBundle.mainBundle().pathForResource("cornell", ofType: "json")!
                let data = NSData(contentsOfFile: file)!
                let json = try NSJSONSerialization.JSONObjectWithData(data, options: [])
                scene = try _Scene.decode(json)
            } catch {
                print(error)
                return
            }
            
            // FIXME: choose the integrator from the scene file
            let integrator = PathTracer()
            render = Renderer(scene: scene, w: width, h: height, integrator: integrator)
            
            // initialize framebuffer
            var framebuffer = Framebuffer(width: width, height: height)
            (0..<width*height).forEach({ framebuffer.ptr[$0] = Vector() })

            
            var totalFrameTime:NSTimeInterval = 0
            var lastFrameDisplayed: NSTimeInterval = NSDate().timeIntervalSince1970
            var totalHits = 0
            while true {
                let lastFrameStart = NSDate().timeIntervalSince1970
                
                // render a frame
                render.render(&framebuffer) //Tile(size: 64)
                
                // compute stats
                let lastFrameDuration = NSDate().timeIntervalSince1970 - lastFrameStart
                totalFrameTime = totalFrameTime + lastFrameDuration
                let lastFrameTime = Int(lastFrameDuration * 1000)
                let avgFrameTime = Int(totalFrameTime * 1000 / Double(framebuffer.samples))
                print("Profiler: frame in \(lastFrameTime)ms, avg. \(avgFrameTime)ms")
                
                // compute more stats
                let hits = UnsafeMutableBufferPointer<_Ray>(start: framebuffer.ray, count: framebuffer.length)
                totalHits += hits.reduce(0) { $0 + $1.count }
                let hps = Real(totalHits) / Real(framebuffer.samples) / Real(lastFrameDuration)

                // update window on the main loop
                dispatch_async(dispatch_get_main_queue()) {
                    self.hitsPerSecond!.stringValue = "Avg. hits: \(Int(hps/1e6)) Mh/s"
                    self.profilerTextField!.stringValue = "Frame in \(lastFrameTime)ms, Avg. \(avgFrameTime)ms"
                    self.view.window!.title = "Samples \(framebuffer.samples)"
                }
                
                // update the UI at least twice a second 
                if NSDate().timeIntervalSince1970 - lastFrameDisplayed < 0.5 { continue }
                lastFrameDisplayed = NSDate().timeIntervalSince1970
                
                // FIXME: warn the user if there is any problem
                guard let image = framebuffer.cgImage() else { continue }
                guard let hitImage = framebuffer.hitImage() else { continue }
                
                dispatch_async(dispatch_get_main_queue()) {
                    self.imageView!.image = NSImage(CGImage: image, size: NSZeroSize)
                    self.hitImageView!.image = NSImage(CGImage: hitImage, size: NSZeroSize)
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

