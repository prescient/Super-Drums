#!/usr/bin/swift

import Cocoa
import CoreGraphics

// Colors matching the app theme
let backgroundColor = NSColor(red: 0.067, green: 0.067, blue: 0.078, alpha: 1.0) // #111114
let surfaceColor = NSColor(red: 0.106, green: 0.110, blue: 0.118, alpha: 1.0) // #1B1C1E
let accentCyan = NSColor(red: 0.0, green: 0.898, blue: 0.898, alpha: 1.0) // #00E5E5
let accentMagenta = NSColor(red: 0.898, green: 0.0, blue: 0.600, alpha: 1.0) // #E50099
let accentOrange = NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0) // #FF9900
let accentGreen = NSColor(red: 0.0, green: 0.898, blue: 0.6, alpha: 1.0) // #00E599

func generateAppIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))

    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    // Background with slight gradient
    let backgroundRect = CGRect(x: 0, y: 0, width: size, height: size)

    // Create gradient background
    let gradientColors = [
        NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0).cgColor,
        NSColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0).cgColor
    ]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: gradientColors as CFArray,
                               locations: [0, 1])!

    context.drawLinearGradient(gradient,
                                start: CGPoint(x: 0, y: size),
                                end: CGPoint(x: size, y: 0),
                                options: [])

    // Grid parameters
    let padding = size * 0.12
    let gridSize = size - (padding * 2)
    let cols = 4
    let rows = 4
    let spacing = size * 0.025
    let cellSize = (gridSize - (spacing * CGFloat(cols - 1))) / CGFloat(cols)
    let cornerRadius = cellSize * 0.2

    // Draw grid cells (some active, some inactive to create pattern)
    let activePattern: [[Bool]] = [
        [true, false, false, true],
        [false, true, false, false],
        [false, false, true, false],
        [true, false, false, true]
    ]

    let colors: [[NSColor]] = [
        [accentCyan, accentCyan, accentMagenta, accentCyan],
        [accentMagenta, accentOrange, accentGreen, accentMagenta],
        [accentGreen, accentCyan, accentMagenta, accentOrange],
        [accentCyan, accentGreen, accentOrange, accentCyan]
    ]

    for row in 0..<rows {
        for col in 0..<cols {
            let x = padding + CGFloat(col) * (cellSize + spacing)
            let y = padding + CGFloat(rows - 1 - row) * (cellSize + spacing)
            let cellRect = CGRect(x: x, y: y, width: cellSize, height: cellSize)
            let cellPath = CGPath(roundedRect: cellRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

            // Draw cell background
            context.setFillColor(surfaceColor.cgColor)
            context.addPath(cellPath)
            context.fillPath()

            // Draw active cells with color fill
            if activePattern[row][col] {
                let color = colors[row][col]

                // Glow effect
                context.saveGState()
                context.setShadow(offset: .zero, blur: cellSize * 0.3, color: color.withAlphaComponent(0.6).cgColor)
                context.setFillColor(color.withAlphaComponent(0.8).cgColor)
                context.addPath(cellPath)
                context.fillPath()
                context.restoreGState()

                // Velocity bar inside the cell
                let barHeight = cellSize * 0.6
                let barPadding = cellSize * 0.15
                let barRect = CGRect(x: x + barPadding,
                                     y: y + barPadding,
                                     width: cellSize - barPadding * 2,
                                     height: barHeight)
                let barPath = CGPath(roundedRect: barRect, cornerWidth: cornerRadius * 0.5, cornerHeight: cornerRadius * 0.5, transform: nil)
                context.setFillColor(color.cgColor)
                context.addPath(barPath)
                context.fillPath()
            }

            // Draw cell border
            context.setStrokeColor(activePattern[row][col] ?
                                   colors[row][col].withAlphaComponent(0.5).cgColor :
                                   NSColor(white: 0.2, alpha: 1.0).cgColor)
            context.setLineWidth(size * 0.003)
            context.addPath(cellPath)
            context.strokePath()
        }
    }

    // Add subtle "SD" text or waveform accent
    let waveformY = size * 0.5
    let waveformStartX = size * 0.25
    let waveformEndX = size * 0.75

    // Draw decorative waveform line through center
    context.setStrokeColor(accentCyan.withAlphaComponent(0.3).cgColor)
    context.setLineWidth(size * 0.008)
    context.setLineCap(.round)

    let wavePath = CGMutablePath()
    wavePath.move(to: CGPoint(x: waveformStartX, y: waveformY))

    let segments = 20
    for i in 0...segments {
        let t = CGFloat(i) / CGFloat(segments)
        let x = waveformStartX + t * (waveformEndX - waveformStartX)
        let amplitude = size * 0.05
        let frequency: CGFloat = 4.0
        let y = waveformY + sin(t * frequency * .pi * 2) * amplitude * (1 - abs(t - 0.5) * 2)
        if i == 0 {
            wavePath.move(to: CGPoint(x: x, y: y))
        } else {
            wavePath.addLine(to: CGPoint(x: x, y: y))
        }
    }

    context.addPath(wavePath)
    context.strokePath()

    image.unlockFocus()
    return image
}

func saveImage(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG data")
        return
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Saved: \(path)")
    } catch {
        print("Failed to save \(path): \(error)")
    }
}

// Generate all required sizes
let basePath = "/Users/robertdelvicario/Library/CloudStorage/GoogleDrive-rdelvicario@valuemetryx.com/My Drive/Code/Super-Drums/SuperDrums/Resources/Assets.xcassets/AppIcon.appiconset"

let sizes: [(name: String, size: CGFloat)] = [
    ("icon_20x20@1x.png", 20),
    ("icon_20x20@2x.png", 40),
    ("icon_29x29@1x.png", 29),
    ("icon_29x29@2x.png", 58),
    ("icon_40x40@1x.png", 40),
    ("icon_40x40@2x.png", 80),
    ("icon_76x76@1x.png", 76),
    ("icon_76x76@2x.png", 152),
    ("icon_83.5x83.5@2x.png", 167),
    ("icon_1024x1024@1x.png", 1024)
]

print("Generating app icons...")

for (name, size) in sizes {
    let icon = generateAppIcon(size: size)
    let path = "\(basePath)/\(name)"
    saveImage(icon, to: path)
}

print("Done!")
