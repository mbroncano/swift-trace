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
            
            let width = 320, height = 240
            var scene: Scene

            do {
                let file = NSBundle.mainBundle().pathForResource("scene", ofType: "json")!
                let data = NSData(contentsOfFile: file)!
                let json = try NSJSONSerialization.JSONObjectWithData(data, options: [])
                scene = try Scene.decode(json)
            } catch {
                print(error)
                return
            }
//            let render = PathTracer(scene: CornellBox(), w: width, h: height)
//            let render = RayTracer(scene: CornellBox(), w: width, h: height)
//            let render = WhittedTracer(scene: CornellBox(), w: width, h: height)

            let render = PathTracer(scene: scene, w: width, h: height)
//            let render = DistributedRayTracer(scene: Scene(), w: width, h: height)
//            let render = WhittedTracer(scene: Scene(), w: width, h: height)
            
            var avg:NSTimeInterval = 0
            while true {
                // render another frame
                let start = NSDate().timeIntervalSince1970
                render.renderTile(size: 64)
                let duration = NSDate().timeIntervalSince1970 - start
                avg = avg + duration
                print("Profiler: frame in \(Int(duration * 1000))ms, avg. \(Int(avg * 1000 / Double(render.framebuffer.samples)))ms")
                
                // update the UI
                if duration < 1.0 && (render.framebuffer.samples % 10 != 1) { continue }
                
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

