import Foundation
import AppKit
import AVFoundation

enum ThumbnailLoader {
    private static let cache = NSCache<NSString, NSImage>()
    private static let rawExtensions: Set<String> = [
        "cr2", "cr3", "nef", "nrw", "arw", "sr2", "raf", "dng", "orf", "rw2", "pef",
        "raw", "mos", "3fr", "erf", "kdc", "iiq", "x3f"
    ]

    static func loadImageThumbnail(url: URL, size: CGFloat) async -> NSImage? {
        let cacheKey = "\(url.path)_\(size)" as NSString
        if let cached = cache.object(forKey: cacheKey) { return cached }

        return await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

            let isRAW = rawExtensions.contains(url.pathExtension.lowercased())
            let maxPixelSize = isRAW ? Int(size * 1.5) : Int(size * 2)

            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceShouldCache: true
            ]

            var cgImage: CGImage?
            if let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                cgImage = thumb
            } else if let full = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                cgImage = full
            }

            guard let cgImage else { return nil }
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

            // For RAW images, aggressively downsample to icon size to save memory
            let finalImage: NSImage
            if isRAW, let rep = nsImage.representations.first {
                let targetSize = NSSize(width: size * 2, height: size * 2)
                let downsampled = NSImage(size: targetSize)
                downsampled.lockFocus()
                rep.draw(in: NSRect(origin: .zero, size: targetSize))
                downsampled.unlockFocus()
                finalImage = downsampled
            } else {
                finalImage = nsImage
            }

            cache.setObject(finalImage, forKey: cacheKey)
            return finalImage
        }.value
    }

    static func loadVideoThumbnail(url: URL, size: CGFloat) async -> NSImage? {
        let cacheKey = "\(url.path)_vid_\(size)" as NSString
        if let cached = cache.object(forKey: cacheKey) { return cached }

        return await Task.detached(priority: .userInitiated) {
            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: size * 2, height: size * 2)

            do {
                let cgImage = try generator.copyCGImage(at: CMTime(seconds: 0.3, preferredTimescale: 600), actualTime: nil)
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                cache.setObject(nsImage, forKey: cacheKey)
                return nsImage
            } catch {
                return nil
            }
        }.value
    }

    static func cachedImage(url: URL, size: CGFloat) -> NSImage? {
        let cacheKey = "\(url.path)_\(size)" as NSString
        return cache.object(forKey: cacheKey)
    }

    static func cachedVideo(url: URL, size: CGFloat) -> NSImage? {
        let cacheKey = "\(url.path)_vid_\(size)" as NSString
        return cache.object(forKey: cacheKey)
    }
}
