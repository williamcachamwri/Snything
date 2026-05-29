import Foundation
import CoreGraphics
import ImageIO
import CoreServices

let w = 1320
let h = 840
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else { fatalError() }

let top = CGColor(red: 248/255, green: 249/255, blue: 250/255, alpha: 1)
let bottom = CGColor(red: 233/255, green: 236/255, blue: 239/255, alpha: 1)
let gradientColors = [top, bottom] as CFArray
let locs: [CGFloat] = [0, 1]
guard let grad = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: locs) else { fatalError() }
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: h), options: [])

guard let img = ctx.makeImage() else { fatalError() }
let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Sources/Snything/Resources/DMGBackground.png")
let dest = CGImageDestinationCreateWithURL(out as CFURL, kUTTypePNG, 1, nil as CFDictionary?)!
CGImageDestinationAddImage(dest, img, nil as CFDictionary?)
CGImageDestinationFinalize(dest)
print("Done: \(out.path)")
