// Turns numbered PNG frames into a looping GIF with ImageIO, no ffmpeg.
// usage: swift tools/frames_to_gif.swift <frames dir> <out.gif> [fps] [width] [every]
// Takes every [every]th frame, scaled to [width] px wide.
import AppKit
import ImageIO
import UniformTypeIdentifiers

let a = CommandLine.arguments
let dir = URL(fileURLWithPath: a[1]), out = URL(fileURLWithPath: a[2])
let fps = Double(a.count > 3 ? a[3] : "10")!, width = Int(a.count > 4 ? a[4] : "800")!, every = Int(a.count > 5 ? a[5] : "2")!
let files = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".png") }.sorted()
let picked = files.enumerated().filter { $0.offset % every == 0 }.map { $0.element }
guard let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.gif.identifier as CFString, picked.count, nil) else { exit(1) }
CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
let frameProps = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / fps]] as CFDictionary
for name in picked {
  guard let src = NSImage(contentsOf: dir.appendingPathComponent(name)),
        let cg = src.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
  let h = cg.height * width / cg.width
  let ctx = CGContext(data: nil, width: width, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
  ctx.interpolationQuality = .high
  ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: h))
  CGImageDestinationAddImage(dest, ctx.makeImage()!, frameProps)
}
CGImageDestinationFinalize(dest)
print("wrote \(out.path): \(picked.count) frames, \(width) px, \(fps) fps")
