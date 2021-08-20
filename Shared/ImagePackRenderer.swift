//
//  ImagePackRenderer.swift
//  GenartPlayground
//
//  Created by Алексей Лысенко on 06.08.2021.
//

import UIKit
import AVFoundation

class ImagePackRenderer {
    enum RenderingErrors: Error {
        case noImagesToRender
        case unknownErrorWhileOnWritingStart
    }

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

                        Tools.appendPixelBuffer(for: nextFrame, pixelBufferAdaptor: pixelBufferAdaptor, presentationTime: presentationTime)
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

fileprivate class Tools {
    @discardableResult
    static func appendPixelBuffer(for image: UIImage,
                                  pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor,
                                  presentationTime: CMTime) -> Bool {
        var appendSucceeded = false

        autoreleasepool {
            if let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool {
                var pixelBufferPointer: CVPixelBuffer?
                let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(
                    kCFAllocatorDefault,
                    pixelBufferPool,
                    &pixelBufferPointer
                )

                if let pixelBuffer = pixelBufferPointer,
                   status == kCVReturnSuccess {
                    fillPixelBufferFromImage(image: image, pixelBuffer: pixelBuffer)

                    appendSucceeded = pixelBufferAdaptor.append(
                        pixelBuffer,
                        withPresentationTime: presentationTime
                    )
                } else {
                    print("error: Failed to allocate pixel buffer from pool")
                }

                pixelBufferPointer = nil
            }
        }
        return appendSucceeded
    }

    static func fillPixelBufferFromImage(image: UIImage, pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))

        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()

        let bitmapImage = image.cgImage!

        let context = CGContext(
            data: pixelData,
            width: bitmapImage.width,
            height: bitmapImage.height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )

        let rect = CGRect(x: 0, y: 0, width: image.size.width * image.scale, height: image.size.height * image.scale)
        context?.draw(bitmapImage, in: rect)

        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
    }
}
