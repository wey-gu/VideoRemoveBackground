//
//  ContentView.swift
//  VideoRemoveBackground
//
//  Created by HaoPeiqiang on 2021/11/24.
//

import SwiftUI
import AVFoundation
import AVKit
import CoreImage

struct VideoEditorView: View {
    
    //for video processing
    @State private var backGroundMode = 1
    
    @State private var videoUrl:URL?
    @State var player = AVPlayer()

    @State private var videoAsset:AVAsset?
    @State private var firstImage:NSImage?
    @State private var imageTransparent:NSImage?
    @State private var firstImageProcessing = false
    
    @State private var color = Color.green
    @State private var colorImage:NSImage?
    
    @State private var processing = false
    @State private var progress:Float = 0.0
    
    @State var startTime:TimeInterval?
    
    @State var showSizeAlert = false

    @State var alertTitle:String?
    @State var alertMessage:String?
    
    var progressPercentage: String {
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value:self.progress )) ?? "0%"
    }

    var estimatedTime:String {
        
        if self.startTime == nil {
            return ""
        }
        let diff = Double(Date().timeIntervalSince1970 - self.startTime!)
        if diff < 5 {
            return ""
        }
        if self.progress == 0 {
            return ""
        }
        let et = Int((diff / Double(self.progress))*( 1 - Double(self.progress)))
        let seconds = et % 60
        let minutes = (et / 60) % 60
        let hours = (et / 3600)
        let day = (et/3600/24)
        if day > 0 {
            return "Estimated Time:\(day)D\(hours)H\(minutes)M\(seconds)S"

        }else if hours > 0 {
            return "Estimated Time:\(hours)H\(minutes)M\(seconds)S"

        }else if (minutes > 0) {
            return "Estimated Time:\(minutes)M\(seconds)S"
        }else {
            return "Estimated Time:\(seconds)S"
        }
    }
    
    private var model = VideoMatting()
    
    var body: some View {
        VStack {
            videoPreview.disabled(self.processing)
            HStack {
                //optionsPanel.disabled(self.videoUrl == nil || self.firstImageProcessing || self.processing)
                buttonsPanel.disabled(self.processing)
            }
            Spacer()
        }
        .alert(isPresented: self.$showSizeAlert) {
            Alert(title: Text(self.alertTitle!),
                  message: Text(self.alertMessage!),
                  dismissButton: .default(Text("Got it!")))
        }
    }
    
    var videoPreview : some View {
        
        HStack {
            if videoAsset != nil {
                VideoPlayer(player: self.player)
                    .onAppear(perform: {
                        self.player = AVPlayer(url: self.videoUrl!)
                    })
                    .frame(width: 384,height: 216)
            } else {
                
                ImageVideoRect()
            }
            if self.imageTransparent != nil {
                
                ZStack {
                    if self.backGroundMode == 2 {
                        
                        Image(nsImage: self.colorImage!)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 384, height: 216, alignment: Alignment.center)
                    }
                    Image(nsImage: self.imageTransparent!)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 384, height: 216, alignment: Alignment.center)
                }
            }else {
                ZStack {
                    if self.firstImageProcessing {
                        VStack {
                            Text("loading preview...")
                            ProgressView()
                        }
                    }
                    ImageVideoRect()
                }
            }
        }
        .padding()
    }
    
    var optionsPanel : some View {
        
        GroupBox(label: Text("Background modes")) {
            HStack {
                Picker(selection: $backGroundMode, label: Text("Mode")) {
                    Text("Transparent").tag(1)
                    Text("Color").tag(2)
                }
                .pickerStyle(RadioGroupPickerStyle())
                .padding()
                VStack {
                    if(backGroundMode == 2) {
                        ColorPicker("Select Color", selection: $color)
                            .onChange(of: color) { color in
                                self.colorImage = NSImage.imageWithColor(color: NSColor(color), size:self.imageTransparent!.size)
                            }
                    }
                }
                .padding()
                .frame(width:200)
            }
        }
    }
    
    var buttonsPanel : some View {
        
        VStack (alignment:.leading) {
            HStack {
                Button {
                    
                    openVideo()
                } label: {
                    Text("Select video...")
                }
                Button {
                    saveToFile()
                } label: {
                    Text("Save as...")
                }
            }
            if self.processing {
                Text(self.progressPercentage)
                Text(self.estimatedTime)
                ProgressView(value: self.progress)
                    .frame(width:200)
            }
            Spacer()
        }
    }

    fileprivate func openVideo() {
        
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie]
        
        if panel.runModal() == .OK {
            guard let videoFile = panel.url else {return}
            self.videoUrl = videoFile
            let aVideoAsset = AVAsset(url: self.videoUrl!)
            if !checkVideoSize(aVideoAsset:aVideoAsset) {
                self.videoUrl = nil
                self.videoAsset = nil
                return
            }
            self.videoAsset = aVideoAsset
            self.player = AVPlayer(url: self.videoUrl!)
            if self.videoAsset != nil {
                getFirstImage()
                self.firstImageProcessing = true
                DispatchQueue.global(qos: .background).async {
                    let newImage =
                    self.model.imageRemoveBackGround(srcImage: self.firstImage!)
                    self.imageTransparent = newImage
                    self.colorImage = NSImage.imageWithColor(color: NSColor(color), size:self.imageTransparent!.size)
                    DispatchQueue.main.async {
                        self.firstImageProcessing = false
                    }
                }
            }
        }
    }
    
    fileprivate func checkVideoSize(aVideoAsset:AVAsset) -> Bool {
        let videoTrack = aVideoAsset.tracks(withMediaType: .video).first
        //3840x2160
        if videoTrack?.naturalSize.width == 3840 && videoTrack?.naturalSize.height == 2160 {
            
            return true
        } else if videoTrack?.naturalSize.width == 1920 && videoTrack?.naturalSize.height == 1080 {
            return true
        } else if videoTrack?.naturalSize.width == 1280 && videoTrack?.naturalSize.height == 720 {
            return true
        }
        self.alertTitle = "Error Size"
        self.alertMessage = "We only support 720p,1080p and 4k Video"
        self.showSizeAlert = true
        return false
    }
    
    fileprivate func getFirstImage() {
        
        let imageGenerator = AVAssetImageGenerator(asset: self.videoAsset!)
        imageGenerator.appliesPreferredTrackTransform = true
        guard let cgImage = try? imageGenerator.copyCGImage(at: CMTime(value: 1, timescale: 30), actualTime: nil) else {return}
        self.firstImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    
    fileprivate func saveToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        if panel.runModal() == .OK {
            guard let destUrl = panel.url else { return }
            var color:Color?
            if self.backGroundMode == 2 {
                color = self.color
            }
            self.processing = true
            self.startTime = Date().timeIntervalSince1970
            
            let aVideoAsset = AVAsset(url: self.videoUrl!)
            let videoTrack = aVideoAsset.tracks(withMediaType: .video).first
            if videoTrack?.naturalSize.width == 3840 && videoTrack?.naturalSize.height == 2160 {
                
                self.alertTitle = "Warnning"
                self.alertMessage = "We will resize your video to 1920*1080."
                self.showSizeAlert = true
            }
            DispatchQueue.global(qos: .background).async {

                model.videoRemoveBackground(srcURL: self.videoUrl!, destURL: destUrl, color: color, onProgressUpdate: {progress in
                    DispatchQueue.main.async {
                        self.progress = progress
                    }
                }) {
                    DispatchQueue.main.async {
                        self.processing = false
                        self.startTime = nil
                        self.progress = 0.0
                    }
                }
            }
        }
    }
}

struct VideoEditorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VideoEditorView()
        }
    }
}
