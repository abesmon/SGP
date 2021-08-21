//
//  RenderingTools.swift
//  GenartPlayground
//
//  Created by Алексей Лысенко on 21.08.2021.
//

import UIKit
import AVFoundation

class RenderingTools {
    @discardableResult
    static func appendPixelBuffer(for image: UIImage,
                                  pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor,
                                  presentationTime: CMTime) -> Bool {
        var appendSucceeded = false

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
