import SwiftUI
import AVFoundation
import Vision

struct CameraView: UIViewRepresentable {
    @Binding var detectedGesture: String
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        context.coordinator.setupCamera(view)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        let parent: CameraView
        var previewLayer: AVCaptureVideoPreviewLayer?
        private var handPoseRequest = VNDetectHumanHandPoseRequest()
        private var shapeLayer = CAShapeLayer()
        
        init(_ parent: CameraView) {
            self.parent = parent
            super.init()
            shapeLayer.fillColor = UIColor.clear.cgColor
            shapeLayer.strokeColor = UIColor.green.cgColor
            shapeLayer.lineWidth = 3
        }
        
        func setupCamera(_ view: UIView) {
            let session = AVCaptureSession()
            session.sessionPreset = .high
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }
            
            session.addInput(input)
            
            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            session.addOutput(output)
            
            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer?.frame = view.bounds
            previewLayer?.videoGravity = .resizeAspectFill
            
            if let previewLayer = previewLayer {
                view.layer.addSublayer(previewLayer)
                view.layer.addSublayer(shapeLayer)
            }
            
            DispatchQueue.global(qos: .background).async {
                session.startRunning()
            }
        }
        
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            let handler = VNImageRequestHandler(cvPixelBuffer: imageBuffer, orientation: .up, options: [:])
            
            do {
                try handler.perform([handPoseRequest])
                guard let observation = handPoseRequest.results?.first else {
                    DispatchQueue.main.async {
                        self.parent.detectedGesture = "No Hand"
                        self.shapeLayer.path = nil
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.handleHandPoseObservation(observation)
                }
            } catch {
                print(error.localizedDescription)
            }
        }
        
        func handleHandPoseObservation(_ observation: VNHumanHandPoseObservation) {
            guard let points = try? observation.recognizedPoints(.all) else { return }
            
            if let previewLayer = previewLayer {
                var normalizedPoints: [CGPoint] = []
                
                // Collect valid points
                for point in points.values where point.confidence > 0.3 {
                    let cgPoint = CGPoint(x: CGFloat(point.location.x), y: CGFloat(1 - point.location.y))
                    normalizedPoints.append(cgPoint)
                }
                
                guard !normalizedPoints.isEmpty else { return }
                
                // Convert points to layer coordinates
                let convertedPoints = normalizedPoints.map { point in
                    previewLayer.layerPointConverted(fromCaptureDevicePoint: point)
                }
                
                // Calculate bounding box from converted points
                let minX = convertedPoints.map { $0.x }.min() ?? 0
                let maxX = convertedPoints.map { $0.x }.max() ?? 0
                let minY = convertedPoints.map { $0.y }.min() ?? 0
                let maxY = convertedPoints.map { $0.y }.max() ?? 0
                
                // Create bounding box with padding
                let padding: CGFloat = 50
                let boundingBox = CGRect(x: minX - padding,
                                       y: minY - padding,
                                       width: (maxX - minX) + (padding * 2),
                                       height: (maxY - minY) + (padding * 2))
                
                let path = UIBezierPath(rect: boundingBox)
                shapeLayer.path = path.cgPath
            }
            
            // Detect pinch
            if let thumbTip = points[.thumbTip],
               let indexTip = points[.indexTip] {
                let distance = hypot(thumbTip.location.x - indexTip.location.x,
                                  thumbTip.location.y - indexTip.location.y)
                
                DispatchQueue.main.async {
                    self.parent.detectedGesture = distance < 0.1 ? "Pinch" : "Open"
                }
            }
        }
    }
}
