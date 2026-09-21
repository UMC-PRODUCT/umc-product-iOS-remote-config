import AppKit

// Finder content size: 660 × 390 pt. Icon centers: (180, 190), (480, 190).
let image = NSImage(size: NSSize(width: 660, height: 390))
image.lockFocus()
NSColor(calibratedRed: 0.945, green: 0.945, blue: 0.965, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: 660, height: 390).fill()

let arrow = NSBezierPath()
arrow.lineWidth = 7
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 324, y: 216))
arrow.line(to: NSPoint(x: 340, y: 200))
arrow.line(to: NSPoint(x: 324, y: 184))
NSColor(calibratedWhite: 0.20, alpha: 1).setStroke()
arrow.stroke()
image.unlockFocus()

let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(
    to: URL(fileURLWithPath: CommandLine.arguments[1])
)
