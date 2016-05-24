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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
//            Random.seed(1234)
            
            let width = 320, height = 256
            
            let start = NSDate().timeIntervalSince1970
            _ = ObjectLibrary(name: "cube.obj")
            let duration = NSDate().timeIntervalSince1970 - start
            print("Load object: completed in \(duration * 1000)ms")
            
//            let render = PathTracer(scene: CornellBox(), w: width, h: height)
//            let render = RayTracer(scene: CornellBox(), w: width, h: height)
//            let render = WhittedTracer(scene: CornellBox(), w: width, h: height)

            let render = PathTracer(scene: Scene(), w: width, h: height)
//            let render = RayTracer(scene: ThreeBall(), w: width, h: height)
//            let render = WhittedTracer(scene: ThreeBall(), w: width, h: height)
            
            var avg:NSTimeInterval = 0
            while true {
                // render another frame
                let start = NSDate().timeIntervalSince1970
                render.renderTile()
                let duration = NSDate().timeIntervalSince1970 - start
                avg = avg + duration
                print("Profiler: completed in \(Int(duration * 1000))ms, \(Int(avg * 1000 / Double(render.framebuffer.samples)))ms")
                
                // update the UI
                if render.framebuffer.samples % 10 != 1 { continue }
                
                let image = render.framebuffer.cgImage()
                dispatch_async(dispatch_get_main_queue()) {
                    self.imageView!.image = NSImage(CGImage: image, size: NSZeroSize)
                    self.view.window!.title = "Samples \(render.framebuffer.samples)"
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

