import Foundation

struct IconChunk {
    let type: String
    let fileName: String
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fputs("Usage: swift create-icns.swift <iconset-directory> <output-file>\n", stderr)
    exit(64)
}

let iconset = URL(fileURLWithPath: arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: arguments[2])
let chunks = [
    IconChunk(type: "icp4", fileName: "icon_16x16.png"),
    IconChunk(type: "icp5", fileName: "icon_32x32.png"),
    IconChunk(type: "icp6", fileName: "icon_32x32@2x.png"),
    IconChunk(type: "ic07", fileName: "icon_128x128.png"),
    IconChunk(type: "ic08", fileName: "icon_256x256.png"),
    IconChunk(type: "ic09", fileName: "icon_512x512.png"),
    IconChunk(type: "ic10", fileName: "icon_512x512@2x.png")
]

func appendBigEndian(_ value: UInt32, to data: inout Data) {
    var bigEndian = value.bigEndian
    withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
}

let payloads: [(IconChunk, Data)] = try chunks.map { chunk in
    let png = try Data(contentsOf: iconset.appendingPathComponent(chunk.fileName))
    return (chunk, png)
}
let totalLength = 8 + payloads.reduce(0) { $0 + 8 + $1.1.count }

var icon = Data("icns".utf8)
appendBigEndian(UInt32(totalLength), to: &icon)
for (chunk, png) in payloads {
    icon.append(Data(chunk.type.utf8))
    appendBigEndian(UInt32(8 + png.count), to: &icon)
    icon.append(png)
}
try icon.write(to: output, options: .atomic)
