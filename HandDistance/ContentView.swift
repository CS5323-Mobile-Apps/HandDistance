//
//  ContentView.swift
//  HandDistance
//
//  Created by Cameron Curry on 11/3/24.
//

import SwiftUI
import AVFoundation
import Vision

struct ContentView: View {
    @State private var detectedGesture: String = "None"
    @State private var pinchCount: Int = 0
    @State private var textColor: Color = .white
    
    var body: some View {
        ZStack {
            CameraView(detectedGesture: $detectedGesture)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                // Score display
                Text("Pinch Count: \(pinchCount)")
                    .font(.title2)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                
                // Gesture display with changing colors
                Text("Detected Gesture: \(detectedGesture)")
                    .font(.title)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.7))
                    )
                    .foregroundColor(detectedGesture == "Pinch" ? .green : .white)
                    .animation(.easeInOut, value: detectedGesture)
                    .padding(.bottom, 50)
            }
        }
        .onChange(of: detectedGesture) { oldValue, newValue in
            if newValue == "Pinch" {
                pinchCount += 1
            }
        }
    }
}
