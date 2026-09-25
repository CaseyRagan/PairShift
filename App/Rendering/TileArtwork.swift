import SpriteKit
import UIKit

/// A small, cached collection of original procedural artwork. All gradients and
/// refractions are rasterized once; the game board only moves textured quads.
@MainActor
enum PairTileArtwork {
    private static var tileImages: [String: UIImage] = [:]
    private static var tileTextures: [String: SKTexture] = [:]
    private static var surfaceTextures: [String: SKTexture] = [:]

    static func color(for pairID: Int) -> UIColor {
        let colors: [UInt32] = [0x6D9DFF, 0xFF839D, 0xFFC16B, 0x69DCC0, 0xC49AFF, 0x68D8F3]
        return UIColor(rgb: colors[normalized(pairID)])
    }

    static func symbolName(for pairID: Int) -> String {
        ["circle", "star", "triangle", "diamond", "crescent", "wave"][normalized(pairID)]
    }

    static func image(for pairID: Int, lightMode: Bool = false, bonded: Bool = false) -> UIImage {
        let key = "\(normalized(pairID))-\(lightMode)-\(bonded)"
        if let cached = tileImages[key] { return cached }
        let tint = color(for: pairID)
        let image = render(size: CGSize(width: 192, height: 192), scale: 2) { context in
            let face = CGRect(x: 24, y: 20, width: 144, height: 144)
            let silhouette = UIBezierPath(roundedRect: face, cornerRadius: 29)
            let base = UIBezierPath(roundedRect: face.offsetBy(dx: 0, dy: 7), cornerRadius: 29)

            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: 9), blur: 12,
                              color: UIColor.black.withAlphaComponent(lightMode ? 0.25 : 0.65).cgColor)
            UIColor(rgb: 0x060D20).setFill()
            base.fill()
            context.restoreGState()

            context.saveGState()
            context.setShadow(offset: .zero, blur: bonded ? 22 : 17,
                              color: tint.withAlphaComponent(bonded ? 0.58 : 0.30).cgColor)
            tint.mixed(with: .black, amount: 0.35).setFill()
            base.fill()
            context.restoreGState()

            context.saveGState()
            silhouette.addClip()
            linearGradient(context, rect: face, colors: [
                tint.mixed(with: .white, amount: 0.36),
                tint.mixed(with: .white, amount: 0.04),
                tint.mixed(with: UIColor(rgb: 0x162449), amount: 0.39)
            ], locations: [0, 0.43, 1])
            radialGradient(context, center: CGPoint(x: 61, y: 41), radius: 123,
                           color: UIColor.white.withAlphaComponent(0.30))

            // The diagonals are deliberately quiet: they read as glass without
            // obscuring the shape that identifies each pair.
            let reflection = UIBezierPath()
            reflection.move(to: CGPoint(x: 25, y: 21))
            reflection.addLine(to: CGPoint(x: 140, y: 21))
            reflection.addLine(to: CGPoint(x: 35, y: 130))
            reflection.addLine(to: CGPoint(x: 25, y: 139))
            reflection.close()
            UIColor.white.withAlphaComponent(0.10).setFill()
            reflection.fill()
            let lowerRefraction = UIBezierPath(ovalIn: CGRect(x: 41, y: 141, width: 112, height: 23))
            tint.mixed(with: .white, amount: 0.30).withAlphaComponent(0.36).setFill()
            lowerRefraction.fill()
            context.restoreGState()

            context.saveGState()
            context.setShadow(offset: .zero, blur: 4, color: tint.withAlphaComponent(0.80).cgColor)
            tint.mixed(with: .white, amount: 0.65).withAlphaComponent(0.88).setStroke()
            silhouette.lineWidth = 2.5
            silhouette.stroke()
            context.restoreGState()

            let innerRim = UIBezierPath(roundedRect: face.insetBy(dx: 4, dy: 4), cornerRadius: 25)
            UIColor.white.withAlphaComponent(0.27).setStroke()
            innerRim.lineWidth = 1
            innerRim.stroke()

            let highlight = UIBezierPath()
            highlight.move(to: CGPoint(x: 28, y: 79))
            highlight.addLine(to: CGPoint(x: 28, y: 48))
            highlight.addQuadCurve(to: CGPoint(x: 50, y: 23), controlPoint: CGPoint(x: 28, y: 24))
            highlight.addLine(to: CGPoint(x: 127, y: 23))
            UIColor.white.withAlphaComponent(0.83).setStroke()
            highlight.lineWidth = 2.6
            highlight.lineCapStyle = .round
            highlight.stroke()

            // A small lower bevel gives the tile a tangible thickness.
            let bevel = UIBezierPath()
            bevel.move(to: CGPoint(x: 47, y: 168))
            bevel.addQuadCurve(to: CGPoint(x: 145, y: 168), controlPoint: CGPoint(x: 96, y: 173))
            tint.withAlphaComponent(0.67).setStroke()
            bevel.lineWidth = 2
            bevel.lineCapStyle = .round
            bevel.stroke()

            let glyph = symbolPath(for: pairID, center: CGPoint(x: 96, y: 90), radius: 28)
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: 2), blur: 3,
                              color: tint.mixed(with: .black, amount: 0.70).withAlphaComponent(0.80).cgColor)
            tint.mixed(with: .white, amount: 0.43).setFill()
            glyph.fill()
            context.restoreGState()
            context.saveGState()
            context.setShadow(offset: .zero, blur: 8, color: UIColor.white.withAlphaComponent(0.35).cgColor)
            UIColor.white.withAlphaComponent(0.95).setStroke()
            glyph.lineWidth = 2.1
            glyph.lineJoinStyle = .round
            glyph.stroke()
            context.restoreGState()
        }
        tileImages[key] = image
        return image
    }

    static func texture(for pairID: Int, lightMode: Bool, bonded: Bool) -> SKTexture {
        let key = "\(normalized(pairID))-\(lightMode)-\(bonded)"
        if let cached = tileTextures[key] { return cached }
        let texture = SKTexture(image: image(for: pairID, lightMode: lightMode, bonded: bonded))
        texture.filteringMode = .linear
        tileTextures[key] = texture
        return texture
    }

    static func trayTexture(lightMode: Bool) -> SKTexture {
        let key = "tray-\(lightMode)"
        if let cached = surfaceTextures[key] { return cached }
        let image = render(size: CGSize(width: 600, height: 600), scale: 1.5) { context in
            let face = CGRect(x: 9, y: 7, width: 582, height: 582)
            let shape = UIBezierPath(roundedRect: face, cornerRadius: 37)
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: 7), blur: 8,
                              color: UIColor.black.withAlphaComponent(lightMode ? 0.15 : 0.40).cgColor)
            UIColor(rgb: lightMode ? 0xB8C7CE : 0x111F33).setFill()
            shape.fill()
            context.restoreGState()
            context.saveGState()
            shape.addClip()
            linearGradient(context, rect: face, colors: lightMode
                           ? [UIColor(rgb: 0xD6E1E2), UIColor(rgb: 0xACBBC1), UIColor(rgb: 0xBBC8CE)]
                           : [UIColor(rgb: 0x27374D), UIColor(rgb: 0x17263A), UIColor(rgb: 0x132035)],
                           locations: [0, 0.47, 1])
            radialGradient(context, center: CGPoint(x: 50, y: 5), radius: 550,
                           color: UIColor(rgb: 0xD6DFEB).withAlphaComponent(lightMode ? 0.10 : 0.065))
            context.restoreGState()
            UIColor.white.withAlphaComponent(lightMode ? 0.70 : 0.23).setStroke()
            shape.lineWidth = 1.4
            shape.stroke()
            let inner = UIBezierPath(roundedRect: face.insetBy(dx: 5, dy: 5), cornerRadius: 33)
            UIColor.black.withAlphaComponent(0.11).setStroke()
            inner.lineWidth = 1
            inner.stroke()
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        surfaceTextures[key] = texture
        return texture
    }

    static func wellTexture(lightMode: Bool) -> SKTexture {
        let key = "well-\(lightMode)"
        if let cached = surfaceTextures[key] { return cached }
        let image = render(size: CGSize(width: 120, height: 120), scale: 2) { context in
            let rect = CGRect(x: 3, y: 3, width: 114, height: 114)
            let shape = UIBezierPath(roundedRect: rect, cornerRadius: 22)
            context.saveGState()
            shape.addClip()
            linearGradient(context, rect: rect, colors: lightMode
                           ? [UIColor(rgb: 0x8EA1AC), UIColor(rgb: 0xABBBC3)]
                           : [UIColor(rgb: 0x101D2E), UIColor(rgb: 0x1E2D41)], locations: [0, 1])
            context.restoreGState()
            UIColor.black.withAlphaComponent(lightMode ? 0.13 : 0.28).setStroke()
            shape.lineWidth = 1.8
            shape.stroke()
            let lip = UIBezierPath()
            lip.move(to: CGPoint(x: 8, y: 104))
            lip.addQuadCurve(to: CGPoint(x: 23, y: 117), controlPoint: CGPoint(x: 10, y: 117))
            lip.addLine(to: CGPoint(x: 97, y: 117))
            lip.addQuadCurve(to: CGPoint(x: 112, y: 104), controlPoint: CGPoint(x: 110, y: 117))
            UIColor.white.withAlphaComponent(lightMode ? 0.24 : 0.10).setStroke()
            lip.lineWidth = 1.1
            lip.stroke()
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        surfaceTextures[key] = texture
        return texture
    }

    static func wallTexture(lightMode: Bool) -> SKTexture {
        let key = "wall-\(lightMode)"
        if let cached = surfaceTextures[key] { return cached }
        let image = render(size: CGSize(width: 160, height: 160), scale: 2) { context in
            let rect = CGRect(x: 12, y: 9, width: 136, height: 137)
            let shape = UIBezierPath(roundedRect: rect, cornerRadius: 24)
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: 5), blur: 6,
                              color: UIColor.black.withAlphaComponent(0.30).cgColor)
            UIColor(rgb: 0x26313D).setFill()
            shape.fill()
            context.restoreGState()
            context.saveGState()
            shape.addClip()
            linearGradient(context, rect: rect, colors: lightMode
                           ? [UIColor(rgb: 0x8A959D), UIColor(rgb: 0x606E7A), UIColor(rgb: 0x4A5A68)]
                           : [UIColor(rgb: 0x49515D), UIColor(rgb: 0x303D4E), UIColor(rgb: 0x253347)],
                           locations: [0, 0.35, 1])

            // Fixed, subdued mineral veins: no random work on the render loop.
            let veins: [[CGPoint]] = [
                [CGPoint(x: 0, y: 36), CGPoint(x: 44, y: 49), CGPoint(x: 69, y: 86), CGPoint(x: 160, y: 103)],
                [CGPoint(x: 102, y: 0), CGPoint(x: 89, y: 44), CGPoint(x: 123, y: 82), CGPoint(x: 111, y: 160)],
                [CGPoint(x: 15, y: 150), CGPoint(x: 63, y: 120), CGPoint(x: 62, y: 79), CGPoint(x: 47, y: 49)]
            ]
            for (index, points) in veins.enumerated() {
                let vein = UIBezierPath()
                vein.move(to: points[0])
                vein.addCurve(to: points[3], controlPoint1: points[1], controlPoint2: points[2])
                UIColor(rgb: 0xD6C6B5).withAlphaComponent(index == 0 ? 0.17 : 0.09).setStroke()
                vein.lineWidth = index == 0 ? 1.9 : 1.3
                vein.stroke()
            }
            radialGradient(context, center: CGPoint(x: 28, y: 19), radius: 143,
                           color: UIColor.white.withAlphaComponent(0.08))
            context.restoreGState()
            UIColor(rgb: 0xC7C9D1).withAlphaComponent(lightMode ? 0.55 : 0.28).setStroke()
            shape.lineWidth = 1.8
            shape.stroke()
            let inset = UIBezierPath(roundedRect: rect.insetBy(dx: 3, dy: 3), cornerRadius: 21)
            UIColor.black.withAlphaComponent(0.14).setStroke()
            inset.lineWidth = 1
            inset.stroke()
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        surfaceTextures[key] = texture
        return texture
    }

    static func glowTexture() -> SKTexture {
        if let cached = surfaceTextures["glow"] { return cached }
        let image = render(size: CGSize(width: 128, height: 128), scale: 1) { context in
            radialGradient(context, center: CGPoint(x: 64, y: 64), radius: 64,
                           color: UIColor.white.withAlphaComponent(0.85))
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        surfaceTextures["glow"] = texture
        return texture
    }

    private static func symbolPath(for pairID: Int, center: CGPoint, radius: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        switch normalized(pairID) {
        case 0:
            return UIBezierPath(ovalIn: CGRect(x: center.x - radius * 0.84, y: center.y - radius * 0.84,
                                              width: radius * 1.68, height: radius * 1.68))
        case 1:
            for index in 0..<10 {
                let angle = CGFloat(index) * .pi / 5 - .pi / 2
                let distance = index.isMultiple(of: 2) ? radius : radius * 0.47
                let point = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.close()
        case 2:
            path.move(to: CGPoint(x: center.x, y: center.y - radius))
            path.addLine(to: CGPoint(x: center.x + radius * 0.94, y: center.y + radius * 0.75))
            path.addQuadCurve(to: CGPoint(x: center.x + radius * 0.83, y: center.y + radius * 0.90),
                              controlPoint: CGPoint(x: center.x + radius * 1.04, y: center.y + radius * 0.90))
            path.addLine(to: CGPoint(x: center.x - radius * 0.83, y: center.y + radius * 0.90))
            path.addQuadCurve(to: CGPoint(x: center.x - radius * 0.94, y: center.y + radius * 0.75),
                              controlPoint: CGPoint(x: center.x - radius * 1.04, y: center.y + radius * 0.90))
            path.close()
        case 3:
            path.move(to: CGPoint(x: center.x, y: center.y - radius))
            path.addLine(to: CGPoint(x: center.x + radius, y: center.y))
            path.addLine(to: CGPoint(x: center.x, y: center.y + radius))
            path.addLine(to: CGPoint(x: center.x - radius, y: center.y))
            path.close()
        case 4:
            path.move(to: CGPoint(x: center.x + 10, y: center.y - 25))
            path.addCurve(to: CGPoint(x: center.x - 5, y: center.y + 26),
                          controlPoint1: CGPoint(x: center.x - 25, y: center.y - 30),
                          controlPoint2: CGPoint(x: center.x - 35, y: center.y + 15))
            path.addCurve(to: CGPoint(x: center.x + 24, y: center.y + 11),
                          controlPoint1: CGPoint(x: center.x + 8, y: center.y + 31),
                          controlPoint2: CGPoint(x: center.x + 22, y: center.y + 20))
            path.addCurve(to: CGPoint(x: center.x + 10, y: center.y - 25),
                          controlPoint1: CGPoint(x: center.x - 7, y: center.y + 20),
                          controlPoint2: CGPoint(x: center.x - 13, y: center.y - 12))
            path.close()
        default:
            path.move(to: CGPoint(x: center.x - 29, y: center.y - 1))
            path.addCurve(to: CGPoint(x: center.x + 29, y: center.y - 12),
                          controlPoint1: CGPoint(x: center.x - 7, y: center.y - 31),
                          controlPoint2: CGPoint(x: center.x + 4, y: center.y + 20))
            path.addLine(to: CGPoint(x: center.x + 29, y: center.y + 2))
            path.addCurve(to: CGPoint(x: center.x - 29, y: center.y + 13),
                          controlPoint1: CGPoint(x: center.x + 5, y: center.y + 34),
                          controlPoint2: CGPoint(x: center.x - 8, y: center.y - 18))
            path.close()
        }
        return path
    }

    private static func normalized(_ pairID: Int) -> Int { ((pairID % 6) + 6) % 6 }

    private static func render(size: CGSize, scale: CGFloat, drawing: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { drawing($0.cgContext) }
    }

    private static func linearGradient(_ context: CGContext, rect: CGRect, colors: [UIColor], locations: [CGFloat]) {
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors.map(\.cgColor) as CFArray, locations: locations) else { return }
        context.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.minY),
                                   end: CGPoint(x: rect.maxX * 0.74, y: rect.maxY),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    private static func radialGradient(_ context: CGContext, center: CGPoint, radius: CGFloat, color: UIColor) {
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray,
                                        locations: [0, 1]) else { return }
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                   endCenter: center, endRadius: radius, options: [])
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }

    func mixed(with other: UIColor, amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r + (r2 - r) * amount, green: g + (g2 - g) * amount,
                       blue: b + (b2 - b) * amount, alpha: a + (a2 - a) * amount)
    }
}
