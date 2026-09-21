import AppKit

let width = 900
let height = 600
let image = NSImage(size: NSSize(width: width, height: height))
image.lockFocus()

let bounds = NSRect(x: 0, y: 0, width: width, height: height)
NSGradient(colors: [
    NSColor(calibratedRed: 0.98, green: 0.99, blue: 1.00, alpha: 1),
    NSColor(calibratedRed: 0.91, green: 0.95, blue: 1.00, alpha: 1),
])!.draw(in: bounds, angle: 270)

let title = "UMC Launchpad 설치" as NSString
title.draw(at: NSPoint(x: 72, y: 500), withAttributes: [
    .font: NSFont.systemFont(ofSize: 32, weight: .semibold),
    .foregroundColor: NSColor(calibratedRed: 0.10, green: 0.18, blue: 0.34, alpha: 1),
])
let instruction = "앱을 Applications 폴더로 드래그하세요." as NSString
instruction.draw(at: NSPoint(x: 74, y: 462), withAttributes: [
    .font: NSFont.systemFont(ofSize: 17, weight: .regular),
    .foregroundColor: NSColor(calibratedRed: 0.30, green: 0.38, blue: 0.53, alpha: 1),
])

let arrow = NSBezierPath()
arrow.lineWidth = 5
arrow.lineCapStyle = .round
arrow.move(to: NSPoint(x: 390, y: 300))
arrow.line(to: NSPoint(x: 515, y: 300))
arrow.move(to: NSPoint(x: 498, y: 317))
arrow.line(to: NSPoint(x: 515, y: 300))
arrow.line(to: NSPoint(x: 498, y: 283))
NSColor(calibratedRed: 0.20, green: 0.48, blue: 0.92, alpha: 0.78).setStroke()
arrow.stroke()

image.unlockFocus()
let tiff = image.tiffRepresentation!
let bitmap = NSBitmapImageRep(data: tiff)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
