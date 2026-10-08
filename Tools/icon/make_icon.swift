// Draws the app icon: a glazed ceramic button in the logo's rust red (#C0472A) on clay
// cream. Usage: swift Tools/icon/make_icon.swift <out.png>   (`make icon`)
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 255) / 255, green: CGFloat(hex >> 8 & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: a)
}
ctx.setFillColor(color(0xF5EDE1))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

let c = CGPoint(x: 512, y: 512)
func circle(_ r: CGFloat, at p: CGPoint = c) -> CGRect { CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r) }

// Soft shadow, then the unglazed clay rim, then the glaze.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: color(0x5A2A14, 0.35))
ctx.setFillColor(color(0xD98E62))
ctx.fillEllipse(in: circle(372))
ctx.restoreGState()
ctx.saveGState()
ctx.addEllipse(in: circle(330))
ctx.clip()
let glaze = CGGradient(colorsSpace: cs, colors: [color(0xD9573A), color(0xC0472A), color(0x9E3520)] as CFArray,
                       locations: [0, 0.55, 1])!
ctx.drawRadialGradient(glaze, startCenter: CGPoint(x: 430, y: 620), startRadius: 0, endCenter: c, endRadius: 360, options: [])
ctx.restoreGState()
// Highlight on the glaze.
ctx.setFillColor(color(0xFFFFFF, 0.22))
ctx.fillEllipse(in: CGRect(x: 262, y: 668, width: 200, height: 86))

// Four holes.
for (dx, dy) in [(-70.0, 70.0), (70.0, 70.0), (-70.0, -70.0), (70.0, -70.0)] {
    let p = CGPoint(x: c.x + dx, y: c.y + dy)
    ctx.setFillColor(color(0x7A2614))
    ctx.fillEllipse(in: circle(44, at: p))
    ctx.setFillColor(color(0xF5EDE1))
    ctx.fillEllipse(in: circle(34, at: CGPoint(x: p.x, y: p.y - 4)))
}

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
print("Wrote \(url.path)")
