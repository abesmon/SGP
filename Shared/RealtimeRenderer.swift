//
//  RealtimeRenderer.swift
//  GenartPlayground
//
//  Created by Алексей Лысенко on 21.08.2021.
//

import UIKit
import AVFoundation

class RealtimeRenderer {
    private var imagePool: [UIImage] = [] {
        didSet {
            print(imagePool.count)
        }
    }
    private var renderEnded = true
    private var queueCount = 0

    func prepare() -> Bool {
        guard renderEnded else { return false }
        queueCount = 0
        return true
    }

    func enqueue(image: UIImage) {
        queueCount += 1
        imagePool.append(image)
    }

    func endRender() {
        renderEnded = true
    }

    func startRender(outputSize: CGSize? = nil, onComplete: ((URL) -> Void)?, onFail: ((Error) -> Void)?) {
        guard renderEnded else {
            onFail?(RenderingErrors.renderAlreadyInProgress)
            return
        }

        renderEnded = false
        guard let firstImage = imagePool.first,
              let firstBitmap = firstImage.cgImage else {
            endRender()
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

                func complete(_ this: RealtimeRenderer?) {
                    this?.renderEnded = true
                    assetWriterInput.markAsFinished()
                    assetWriter.finishWriting {
                        onComplete?(videoOutputURL)
                        print("ended with frameCount: \(frameCount) and queueCount: \(this?.queueCount ?? -1)")
                    }
                }

                let fps = Int32(UIScreen.main.maximumFramesPerSecond)
                let frameDuration = CMTimeMake(value: 1, timescale: fps)
                
                assetWriterInput.requestMediaDataWhenReady(on: media_queue) { [weak self] in
                    guard let this = self else {
                        complete(self)
                        return
                    }

                    while assetWriterInput.isReadyForMoreMediaData,
                          !this.renderEnded || !this.imagePool.isEmpty
                    {
                        guard this.imagePool.first != nil else { return }
                        autoreleasepool {
                            let nextFrame = this.imagePool.removeFirst()
                            let lastFrameTime = CMTimeMake(value: Int64(frameCount), timescale: fps)
                            let presentationTime = frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)

                            RenderingTools.appendPixelBuffer(for: nextFrame, pixelBufferAdaptor: pixelBufferAdaptor, presentationTime: presentationTime)
                            frameCount += 1
                        }
                    }

                    if this.renderEnded && this.imagePool.isEmpty { complete(self) }
                }
            } else {
                endRender()
                onFail?(assetWriter.error ?? RenderingErrors.unknownErrorWhileOnWritingStart)
            }
        } catch {
            endRender()
            onFail?(error)
        }
    }
}
