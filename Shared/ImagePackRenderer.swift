//
//  ImagePackRenderer.swift
//  GenartPlayground
//
//  Created by Алексей Лысенко on 06.08.2021.
//

import UIKit
import AVFoundation

enum RenderingErrors: Error {
    case noImagesToRender
    case unknownErrorWhileOnWritingStart
    case renderAlreadyInProgress
}

class ImagePackRenderer {

    func render(images: [UIImage], outputSize: CGSize? = nil, onComplete: ((URL) -> Void)?, onFail: ((Error) -> Void)?) {
        guard let firstImage = images.first,
              let firstBitmap = firstImage.cgImage else {
            onFail?(RenderingErrors.noImagesToRender)
            return
        }

        let inputSize = CGSize(width: firstImage.size.width * firstImage.scale, height: firstImage.size.height * firstImage.scale)
        let inputSizeBitmap = CGSize(width: firstBitmap.width, height: firstBitmap.height)
        let outputSize = outputSize ?? inputSize

        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filename = UUID().uuidString
        let videoOutputURL = docsDir.appendingPathComponent("\(filename).mov")

        do {
            let assetWriter = try AVAssetWriter(outputURL: videoOutputURL, fileType: .mov)

            let videoSettings: [String : AnyObject] = [
                AVVideoCodecKey  : AVVideoCodecType.hevc as AnyObject,
                AVVideoWidthKey  : outputSize.width as AnyObject,
                AVVideoHeightKey : outputSize.height as AnyObject,
                //                AVVideoCompressionPropertiesKey : [
                //                    AVVideoAverageBitRateKey : NSInteger(1000000),
                //                    AVVideoMaxKeyFrameIntervalKey : NSInteger(16),
                //                    AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel
                //                ]
            ]
            let assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)

            let sourceBufferAttributes = [
                (kCVPixelBufferPixelFormatTypeKey as String): Int(kCVPixelFormatType_32ARGB),
                (kCVPixelBufferWidthKey as String): Float(inputSize.width),
                (kCVPixelBufferHeightKey as String): Float(inputSize.height)] as [String : Any]

            let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: assetWriterInput,
                sourcePixelBufferAttributes: sourceBufferAttributes
            )

            assert(assetWriter.canAdd(assetWriterInput))
            assetWriter.add(assetWriterInput)

            if assetWriter.startWriting() {
                assetWriter.startSession(atSourceTime: CMTime.zero)
                assert(pixelBufferAdaptor.pixelBufferPool != nil)

                let media_queue = DispatchQueue(label: "mediaInputQueue")

                var frameCount = 0
                var remainingImages = [UIImage](images.reversed())

                assetWriterInput.requestMediaDataWhenReady(on: media_queue) {
                    let fps = Int32(UIScreen.main.maximumFramesPerSecond)
                    let frameDuration = CMTimeMake(value: 1, timescale: fps)

                    print("frames to render: \(remainingImages.count)")

                    while assetWriterInput.isReadyForMoreMediaData,
                          let nextFrame = remainingImages.popLast() {
                        let lastFrameTime = CMTimeMake(value: Int64(frameCount), timescale: fps)
                        let presentationTime = frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)

                        RenderingTools.appendPixelBuffer(for: nextFrame, pixelBufferAdaptor: pixelBufferAdaptor, presentationTime: presentationTime)
                        frameCount += 1
                    }

                    if remainingImages.isEmpty {
                        assetWriterInput.markAsFinished()
                        assetWriter.finishWriting {
                            onComplete?(videoOutputURL)
                        }
                    }
                }
            } else {
                onFail?(assetWriter.error ?? RenderingErrors.unknownErrorWhileOnWritingStart)
            }
        } catch {
            onFail?(error)
        }
    }
}
