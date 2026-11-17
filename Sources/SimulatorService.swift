import Foundation
import ImageIO
import UniformTypeIdentifiers

struct SimulatorDevice: Identifiable, Decodable, Equatable {
    let name: String
    let udid: String
    let state: String
    var runtime: String = ""
    var id: String { udid }

    enum CodingKeys: String, CodingKey { case name, udid, state }
}

struct PhotoSource: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var isEmbeddedData: Bool { url.scheme?.lowercased() == "data" }
    var isBase64Image: Bool { url.absoluteString.prefix(11).lowercased() == "data:image/" }
    var title: String {
        isEmbeddedData ? (isBase64Image ? "Base64 image" : "Base64 file") : (url.lastPathComponent.isEmpty ? url.absoluteString : url.lastPathComponent)
    }
    var displayLocation: String {
        if isEmbeddedData { return "\(title) · embedded file data" }
        return url.isFileURL ? url.path : url.absoluteString
    }

    static func parse(_ input: String) throws -> PhotoSource {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("\"") && value.hasSuffix("\"") || value.hasPrefix("'") && value.hasSuffix("'") {
            value = String(value.dropFirst().dropLast())
        }
        guard !value.isEmpty else { throw PhotoError.message("Enter a URL, file path, or Base64 data URL.") }
        if value.prefix(5).lowercased() == "data:" {
            let image = try Base64File(value)
            guard let url = image.normalizedURL else { throw PhotoError.message("The Base64 data URL is invalid.") }
            return PhotoSource(url: url)
        }
        if let url = URL(string: value), let scheme = url.scheme?.lowercased() {
            if ["http", "https"].contains(scheme), url.host != nil { return PhotoSource(url: url) }
            if scheme == "file" { return PhotoSource(url: url) }
            throw PhotoError.message("Use an http:// or https:// URL, a local file path, or a supported Base64 data URL.")
        }
        return PhotoSource(url: URL(fileURLWithPath: (value as NSString).expandingTildeInPath))
    }
}

enum PhotoError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

/// Runs Apple's tool directly with separate arguments; user input is never evaluated by a shell.
enum AppleTool {
    static func run(_ arguments: [String], executable: String = "/usr/bin/xcrun", timeout: TimeInterval = 45) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                do {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    defer { try? FileManager.default.removeItem(at: directory) }
                    let output = directory.appendingPathComponent("output")
                    FileManager.default.createFile(atPath: output.path, contents: nil)
                    let handle = try FileHandle(forWritingTo: output)
                    defer { try? handle.close() }
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: executable)
                    process.arguments = arguments
                    process.standardOutput = handle
                    process.standardError = handle
                    // A copied app should use this Mac's active Xcode, not an inherited shell override.
                    var environment = ProcessInfo.processInfo.environment
                    environment.removeValue(forKey: "DEVELOPER_DIR")
                    process.environment = environment
                    try process.run()
                    let deadline = Date().addingTimeInterval(timeout)
                    while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
                    if process.isRunning {
                        process.terminate()
                        throw PhotoError.message("The simulator operation timed out. Check Xcode and try again.")
                    }
                    process.waitUntilExit()
                    let data = try Data(contentsOf: output)
                    guard process.terminationStatus == 0 else {
                        let detail = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                        throw PhotoError.message(detail.isEmpty ? "Apple's simulator tools failed. Open Xcode and install an iOS simulator." : detail)
                    }
                    continuation.resume(returning: data)
                } catch { continuation.resume(throwing: error) }
            }
        }
    }
}

enum SimulatorService {
    static func decodeDevices(_ data: Data) throws -> [SimulatorDevice] {
        struct Response: Decodable { let devices: [String: [SimulatorDevice]] }
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.devices.flatMap { runtime, devices in
            devices.filter { $0.state == "Booted" }.map { device in
                var result = device
                result.runtime = runtime.replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
                    .replacingOccurrences(of: "-", with: " ")
                return result
            }
        }.sorted { ($0.name, $0.udid) < ($1.name, $1.udid) }
    }

    static func runningDevices() async throws -> [SimulatorDevice] {
        try decodeDevices(await AppleTool.run(["simctl", "list", "devices", "booted", "--json"]))
    }

    static func importImage(_ file: URL, to device: SimulatorDevice) async throws {
        _ = try await AppleTool.run(["simctl", "addmedia", device.udid, file.path])
    }

    static func validateImage(_ url: URL) throws -> String {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0,
              let type = CGImageSourceGetType(source),
              let imageType = UTType(type as String), imageType.conforms(to: .image),
              CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 64
              ] as CFDictionary) != nil else {
            throw PhotoError.message("“\(url.lastPathComponent)” is not a readable image. Use a direct image URL or a valid image file.")
        }
        return imageType.preferredFilenameExtension ?? "png"
    }

    static func prepare(_ source: PhotoSource, in directory: URL) async throws -> URL {
        let local: URL
        if source.isEmbeddedData {
            let image = try Base64File(source.url.absoluteString)
            local = directory.appendingPathComponent("Base64-file-\(UUID().uuidString)").appendingPathExtension(SafeFile.extensionForMediaType(image.mediaType) ?? "dat")
            try image.decodedData().write(to: local, options: .atomic)
        } else if source.url.isFileURL {
            guard FileManager.default.isReadableFile(atPath: source.url.path) else {
                throw PhotoError.message("Cannot read “\(source.url.path)”. Choose an existing file.")
            }
            local = source.url
        } else {
            var request = URLRequest(url: source.url)
            request.timeoutInterval = 60
            let (download, response) = try await URLSession.shared.download(for: request)
            guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
                try? FileManager.default.removeItem(at: download)
                throw PhotoError.message("The file URL returned an unsuccessful response.")
            }
            let fileExtension = SafeFile.extensionForMediaType(response.mimeType ?? "")
                ?? response.suggestedFilename.map { ($0 as NSString).pathExtension }
                ?? source.url.pathExtension
            let destination = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)
            try FileManager.default.moveItem(at: download, to: destination)
            local = destination
        }
        let ext = try SafeFile.validatedExtension(local)
        let destination = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        try FileManager.default.copyItem(at: local, to: destination)
        return destination
    }
}
