import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

/// Restricts accepted formats; it does not certify that a file is free of malware.
enum SafeFile {
    static let textExtensions: Set<String> = ["txt", "md", "csv", "json", "xml", "yaml", "yml", "log", "rtf"]
    static let documentMediaTypes = [
        "application/pdf": "pdf", "text/plain": "txt", "text/markdown": "md",
        "text/csv": "csv", "application/json": "json", "text/json": "json",
        "application/xml": "xml", "text/xml": "xml", "application/yaml": "yaml",
        "text/yaml": "yaml", "application/x-yaml": "yaml", "application/rtf": "rtf", "text/rtf": "rtf"
    ]
    static var chooserTypes: [UTType] {
        [.image, .pdf] + textExtensions.sorted().compactMap { UTType(filenameExtension: $0) }
    }

    static func supports(mediaType: String) -> Bool {
        (mediaType.hasPrefix("image/") && mediaType.count > 6) || documentMediaTypes[mediaType] != nil
    }

    static func extensionForMediaType(_ mediaType: String) -> String? {
        let type = mediaType.lowercased()
        return documentMediaTypes[type] ?? (type.hasPrefix("image/") ? UTType(mimeType: type)?.preferredFilenameExtension : nil)
    }

    static func isImage(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
    }

    static func validatedExtension(_ url: URL) throws -> String {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else { throw PhotoError.message("Choose a regular file. Folders and app bundles are not supported.") }
        if let imageType = try? SimulatorService.validateImage(url) { return imageType }
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            guard let document = PDFDocument(url: url), document.pageCount > 0 else {
                throw PhotoError.message("This PDF is invalid, empty, or cannot be opened.")
            }
            return "pdf"
        }
        guard textExtensions.contains(ext) else {
            throw PhotoError.message("This is not a readable image or a supported document. Use PDF, TXT, MD, CSV, JSON, XML, YAML, YML, LOG, or RTF. Executables, scripts, archives, and folders are not supported.")
        }
        let data = try Data(contentsOf: url)
        let text = String(data: data, encoding: .utf8) ??
            ((data.starts(with: [0xff, 0xfe]) || data.starts(with: [0xfe, 0xff])) ? String(data: data, encoding: .utf16) : nil)
        guard let text, !text.unicodeScalars.contains(where: { $0.value < 32 && ![9, 10, 13].contains($0.value) }) else {
            throw PhotoError.message("This document is not valid UTF-8 or UTF-16 text.")
        }
        if ext == "json" {
            guard let json = text.data(using: .utf8), (try? JSONSerialization.jsonObject(with: json, options: .fragmentsAllowed)) != nil else {
                throw PhotoError.message("This JSON document is invalid.")
            }
        }
        if ext == "rtf", !text.hasPrefix("{\\rtf") { throw PhotoError.message("This RTF document is invalid.") }
        return ext
    }
}
