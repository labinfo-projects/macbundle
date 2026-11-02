import Foundation
import AppKit

func extractIconWithAlpha(from url: URL, to outputDir: URL) {
    let name = url.deletingPathExtension().lastPathComponent
    let outUrl = outputDir.appendingPathComponent("\(name).png")
    
    let icon = NSWorkspace.shared.icon(forFile: url.path)
    
    // Trova la rappresentazione migliore (128x128 o 256x256)
    guard let bestRep = icon.bestRepresentation(for: NSRect(x: 0, y: 0, width: 256, height: 256), context: nil, hints: nil) else {
        print(" [SKIP] Impossibile estrarre: \(name)")
        return
    }
    
    let width = Int(bestRep.size.width)
    let height = Int(bestRep.size.height)
    let rect = NSRect(x: 0, y: 0, width: width, height: height)
    
    // Alloca un buffer bitmap esplicitamente RGBA a 32 bit con canale alfa
    guard let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 32
    ) else {
        print(" [ERR] Creazione buffer fallita: \(name)")
        return
    }
    
    // Disegna l'icona su un canvas pulito con canale alfa a zero (100% trasparente)
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmapRep)
    NSGraphicsContext.current = context
    context?.cgContext.clear(rect)
    bestRep.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
    
    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        print(" [ERR] Conversione PNG fallita: \(name)")
        return
    }
    
    do {
        try pngData.write(to: outUrl)
        print(" [OK] \(name).png (\(width)x\(height) RGBA)")
    } catch {
        print(" [ERR] Scrittura su disco fallita: \(name)")
    }
}

let fm = FileManager.default
let currentDir = URL(fileURLWithPath: fm.currentDirectoryPath)
let outputDir = currentDir.appendingPathComponent("png_alta_risoluzione")

try? fm.createDirectory(at: outputDir, withIntermediateDirectories: true)

let items = try fm.contentsOfDirectory(at: currentDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])

for item in items {
    let filename = item.lastPathComponent
    if filename.hasSuffix(".swift") || filename.hasSuffix(".py") || filename == "png_alta_risoluzione" {
        continue
    }
    extractIconWithAlpha(from: item, to: outputDir)
}

print("\nEstrazione completata con canale alfa in: png_alta_risoluzione/")
