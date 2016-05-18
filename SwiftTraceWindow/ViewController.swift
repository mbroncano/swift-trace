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
            Random.seed(1234)
            
            let width = 320, height = 240
            
//            let render = PathTracer(scene: CornellBox(), w: width, h: height)
//            let render = RayTracer(scene: CornellBox(), w: width, h: height)
//            let render = EyeTracer(scene: CornellBox(), w: width, h: height)

            let render = PathTracer(scene: ThreeBall(), w: width, h: height)
//            let render = RayTracer(scene: ThreeBall(), w: width, h: height)
//            let render = EyeTracer(scene: ThreeBall(), w: width, h: height)
            
            while true {
                // render another frame
                let start = NSDate().timeIntervalSince1970
                render.render()
                let duration = NSDate().timeIntervalSince1970 - start
                print("Profiler: completed in \(duration * 1000)ms")
                
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

