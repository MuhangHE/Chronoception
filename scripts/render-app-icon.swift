// Renders the app icon into the asset catalogs: light, dark and tinted for iOS, and
// the light one for the watch, which masks it to a circle. Also writes the README's
// copy, with the rounded corners iOS gives it.
// Run from the repository root: swift scripts/render-app-icon.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let folder = URL(fileURLWithPath: "iOS/Assets.xcassets/AppIcon.appiconset")
let watchFolder = URL(fileURLWithPath: "Watch/Assets.xcassets/AppIcon.appiconset")
let readmeIcon = URL(fileURLWithPath: "docs/images/icon.png")

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

/// A triangle with rounded corners.
func roundedTriangle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2))
    path.addArc(tangent1End: b, tangent2End: c, radius: radius)
    path.addArc(tangent1End: c, tangent2End: a, radius: radius)
    path.addArc(tangent1End: a, tangent2End: b, radius: radius)
    path.closeSubpath()
    return path
}

/// The mark: an hourglass of two rounded triangles, tip to tip.
func drawMark(in ctx: CGContext, top: CGColor, bottom: CGColor) {
    let center = CGFloat(size) / 2
    let halfWidth: CGFloat = 230
    let edge: CGFloat = 288 // from the center to the flat sides
    let neck: CGFloat = 26 // from the center to each tip
    let corner: CGFloat = 44

    // Core Graphics puts y = 0 at the bottom.
    ctx.setFillColor(top)
    ctx.addPath(roundedTriangle(
        CGPoint(x: center - halfWidth, y: center + edge),
        CGPoint(x: center + halfWidth, y: center + edge),
        CGPoint(x: center, y: center + neck),
        radius: corner
    ))
    ctx.fillPath()

    ctx.setFillColor(bottom)
    ctx.addPath(roundedTriangle(
        CGPoint(x: center + halfWidth, y: center - edge),
        CGPoint(x: center - halfWidth, y: center - edge),
        CGPoint(x: center, y: center - neck),
        radius: corner
    ))
    ctx.fillPath()
}

/// The light icon must be opaque; dark and tinted ones are drawn on transparency and
/// the system supplies the background.
func render(_ name: String, in folder: URL = folder, background: CGColor?, top: CGColor, bottom: CGColor) {
    let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: (background == nil ? CGImageAlphaInfo.premultipliedLast : .noneSkipLast).rawValue
    )!
    if let background {
        ctx.setFillColor(background)
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
    }
    drawMark(in: ctx, top: top, bottom: bottom)
    write(ctx.makeImage()!, to: folder.appendingPathComponent(name))
}

/// The light icon at `pixels` square, its corners rounded like on the home screen.
func renderRounded(to url: URL, pixels: Int) {
    let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.scaleBy(x: CGFloat(pixels) / CGFloat(size), y: CGFloat(pixels) / CGFloat(size))
    let bounds = CGRect(x: 0, y: 0, width: size, height: size)
    let corner = CGFloat(size) * 0.2237
    ctx.addPath(CGPath(roundedRect: bounds, cornerWidth: corner, cornerHeight: corner, transform: nil))
    ctx.clip()
    ctx.setFillColor(rgb(0xF0EEE6))
    ctx.fill(bounds)
    drawMark(in: ctx, top: rgb(0xD97757), bottom: rgb(0x141413))
    write(ctx.makeImage()!, to: url)
}

func write(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Could not write \(url.path)") }
    print("wrote \(url.path)")
}

for directory in [folder, watchFolder, readmeIcon.deletingLastPathComponent()] {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
}
// Claude's palette: ivory paper, clay, ink.
render("AppIcon.png", background: rgb(0xF0EEE6), top: rgb(0xD97757), bottom: rgb(0x141413))
render("AppIcon-Dark.png", background: nil, top: rgb(0xD97757), bottom: rgb(0xF5F4EE))
render("AppIcon-Tinted.png", background: nil, top: rgb(0xFFFFFF), bottom: rgb(0xB8B8B8))
render("AppIcon.png", in: watchFolder, background: rgb(0xF0EEE6), top: rgb(0xD97757), bottom: rgb(0x141413))
renderRounded(to: readmeIcon, pixels: 256)
