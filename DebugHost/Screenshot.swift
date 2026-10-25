import AppKit

enum Screenshot {
    /// Draws `overlay` (an ordinary view, rendered through `cacheDisplay`) onto `base` at `frame` (y-up points).
    static func composite(_ base: CGImage, overlay: NSView, at frame: NSRect, scale: CGFloat) -> CGImage? {
        guard let rep = overlay.bitmapImageRepForCachingDisplay(in: overlay.bounds) else { return nil }
        overlay.cacheDisplay(in: overlay.bounds, to: rep)
        guard let overlayImage = rep.cgImage,
              let context = CGContext(data: nil, width: base.width, height: base.height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(base, in: CGRect(x: 0, y: 0, width: base.width, height: base.height))
        context.draw(overlayImage, in: CGRect(x: frame.minX * scale, y: frame.minY * scale, width: frame.width * scale, height: frame.height * scale))
        return context.makeImage()
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "DebugHost", code: 1, userInfo: [NSLocalizedDescriptionKey: "PNG encoding failed"])
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }
}
