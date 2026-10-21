import AppKit
import SwiftUI
#if canImport(ClipFlow)
@testable import ClipFlow
#endif

private struct PanelSurfaceFailure: Error, CustomStringConvertible {
    let description: String
}

private func surfaceExpect(_ condition: Bool, _ message: String) throws {
    guard condition else { throw PanelSurfaceFailure(description: message) }
}

@MainActor
enum PanelSurfaceScenarios {
    private static func makeSurface() -> RoundedPanelSurface {
        RoundedPanelSurface(frame: NSRect(x: 0, y: 0, width: 380, height: 286), rootView: Color.clear)
    }

    private static func bitmap(_ surface: RoundedPanelSurface) throws -> NSBitmapImageRep {
        guard let mask = surface.backdrop.maskImage,
              let image = mask.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw PanelSurfaceFailure(description: "Native backdrop must have a renderable corner mask")
        }
        return NSBitmapImageRep(cgImage: image)
    }

    private static func alpha(_ bitmap: NSBitmapImageRep, x: Int, y: Int) throws -> CGFloat {
        guard let color = bitmap.colorAt(x: x, y: y) else {
            throw PanelSurfaceFailure(description: "Cannot sample mask at \(x), \(y)")
        }
        return color.alphaComponent
    }

    static var all: [ShortcutScenario] {
        [
            ShortcutScenario(name: "testPanelMaterialMaskClipsAllCornersAndPreservesEdges", run: {
                let surface = makeSurface()
                let pixels = try bitmap(surface)
                let maxX = pixels.pixelsWide - 1
                let maxY = pixels.pixelsHigh - 1
                for (x, y) in [(0, 0), (maxX, 0), (0, maxY), (maxX, maxY)] {
                    try surfaceExpect(try alpha(pixels, x: x, y: y) < 0.01, "Every backdrop corner must be transparent")
                }
                for (x, y) in [(maxX / 2, maxY / 2), (maxX / 2, 0), (maxX / 2, maxY), (0, maxY / 2), (maxX, maxY / 2)] {
                    try surfaceExpect(try alpha(pixels, x: x, y: y) > 0.99, "Backdrop center and straight edges must remain opaque")
                }
            }),
            ShortcutScenario(name: "testPanelMaskTracksRepeatedContentResizing", run: {
                let surface = makeSurface()
                for size in [NSSize(width: 380, height: 286), NSSize(width: 380, height: 480), NSSize(width: 520, height: 286), NSSize(width: 320, height: 480), NSSize(width: 380, height: 286)] {
                    surface.setFrameSize(size)
                    surface.layout()
                    try surfaceExpect(surface.backdrop.maskImage?.size == size, "Mask must match resized panel \(size)")
                    try surfaceExpect(surface.backdrop.frame == surface.bounds, "Backdrop must fill resized panel")
                    try surfaceExpect(surface.layer?.masksToBounds == true, "Resizing must preserve native content clipping")
                    try surfaceExpect(surface.layer?.cornerRadius == RoundedPanelSurface.cornerRadius, "Resizing must preserve corner radius")
                    let pixels = try bitmap(surface)
                    try surfaceExpect(try alpha(pixels, x: 0, y: 0) < 0.01, "Resized mask corner must remain transparent")
                    try surfaceExpect(try alpha(pixels, x: pixels.pixelsWide / 2, y: pixels.pixelsHigh / 2) > 0.99, "Resized mask center must remain opaque")
                }
            }),
            ShortcutScenario(name: "testPanelMaskGeometryIsIndependentOfSystemAppearance", run: {
                let surface = makeSurface()
                surface.appearance = NSAppearance(named: .aqua)
                surface.layout()
                let light = try bitmap(surface)
                surface.appearance = NSAppearance(named: .darkAqua)
                surface.layout()
                let dark = try bitmap(surface)
                try surfaceExpect(light.pixelsWide == dark.pixelsWide && light.pixelsHigh == dark.pixelsHigh, "Appearance must preserve mask dimensions")
                for y in 0..<light.pixelsHigh {
                    for x in 0..<light.pixelsWide {
                        try surfaceExpect(try alpha(light, x: x, y: y) == alpha(dark, x: x, y: y), "Appearance must preserve mask alpha geometry")
                    }
                }
            }),
            ShortcutScenario(name: "testPanelLayoutReusesMaskWhenSizeIsUnchanged", run: {
                let surface = makeSurface()
                guard let originalMask = surface.backdrop.maskImage else {
                    throw PanelSurfaceFailure(description: "Initial backdrop mask is missing")
                }
                for _ in 0..<5 { surface.layout() }
                try surfaceExpect(surface.backdrop.maskImage === originalMask, "Unchanged layout must reuse the native mask")
            })
        ]
    }
}
