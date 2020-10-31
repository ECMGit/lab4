//
//  ModuleBViewController.swift
//  ImageLab
//
//  Created by Reid Russell on 10/30/20.
//  Copyright © 2020 Eric Larson. All rights reserved.
//

import UIKit
import Metal

class ModuleBViewController: UIViewController {


    //MARK: Class Properties
    var filters : [CIFilter]! = nil
    var videoManager:VideoAnalgesic! = nil
    let pinchFilterIndex = 2
    var detector:CIDetector! = nil
    let bridge = OpenCVBridge()
    @IBOutlet weak var heartRate: UILabel!
    


    @IBOutlet var cameraView: UIView!
    
    @IBOutlet var subView: UIView!
    
    lazy var graph:MetalGraph? = {
        return MetalGraph(mainView: self.subView)
        }()
    
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.videoManager = VideoAnalgesic(mainView: self.cameraView)
        self.videoManager.setCameraPosition(position: AVCaptureDevice.Position.back)
        

        self.videoManager.setProcessingBlock(newProcessBlock: self.processImage)
        
        if !videoManager.isRunning{
            videoManager.start()
        }
        

//        self.view.addSubview(self.subView)
        
        graph?.addGraph(withName: "PPG", shouldNormalize: true, numPointsInGraph: 100)
        Timer.scheduledTimer(timeInterval: 0.05, target: self,
            selector: #selector(self.updateGraph),
            userInfo: nil,
            repeats: true)
       
    
    }
    
    //MARK: Process image output
    func processImage(inputImage:CIImage) -> CIImage{
        
        // detect faces
        
        // if no faces, just return original image
        
        var retImage = inputImage
        

        // or any bounds to only process a certain bounding region in OpenCV
        self.bridge.setTransforms(self.videoManager.transform)
        self.bridge.setImage(retImage,
                             withBounds: retImage.extent, // the first face bounds
                             andContext: self.videoManager.getCIContext())
        self.videoManager.turnOnFlashwithLevel(0.2)
        let finger = self.bridge.processFinger()
        if finger{
            if self.bridge.checkR(){
                self.updateGraph()
                let hr = self.bridge.processHeartRate()
                NSLog("%f",hr)
            }
        }
        

//        if finger != nil{
//
//
//                if finger{
//                    self.toggleFlash.isHidden = true
//                    self.toggleCamera.isHidden = true
//                    self.videoManager.turnOnFlashwithLevel(1.0)
//                }
//                else{
//                    self.toggleFlash.isHidden = false
//                    self.toggleCamera.isHidden = false
//                    self.videoManager.turnOffFlash()
//                }
//
//        }
//        }
        retImage = self.bridge.getImageComposite() // get back opencv processed part of the image (overlayed on original)
        
        return retImage
    }
    // periodically, update the graph with refreshed FFT Data
    @objc
    func updateGraph(){
//        if self.bridge.checkR(){
            self.graph?.updateGraph(
                data: self.bridge.getR() as! [Float],
                forKey: "PPG"
            )
        if(self.bridge.checkR()){
            DispatchQueue.main.async {
                self.heartRate.text = "Detected Heart Rate:" + String(self.bridge.processHeartRate()) + " BPM"
            }
        }
            
        
//        }
        
        
        
    }
}
