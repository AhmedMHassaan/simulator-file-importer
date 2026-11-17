import Foundation

/// A Base64 file data URL. Decoding is deferred to the import worker.
struct Base64File {
    let mediaType: String
    let payload: String

    init(_ value: String) throws {
        guard value.prefix(5).lowercased() == "data:", let comma = value.firstIndex(of: ",") else {
            throw PhotoError.message("Use a complete Base64 file data URL: data:image/png;base64,…")
        }
        let header = value[value.index(value.startIndex, offsetBy: 5)..<comma]
            .split(separator: ";", omittingEmptySubsequences: false).map(String.init)
        guard let type = header.first?.lowercased(), SafeFile.supports(mediaType: type),
              header.last?.lowercased() == "base64" else {
            throw PhotoError.message("Use a supported image, PDF, or text MIME type followed by ;base64, and the complete encoded file.")
        }
        let encoded = String(value[value.index(after: comma)...])
        guard let unescaped = encoded.removingPercentEncoding else {
            throw PhotoError.message("The Base64 file contains invalid URL escapes.")
        }
        let compact = unescaped.components(separatedBy: .whitespacesAndNewlines).joined()
        guard !compact.isEmpty else { throw PhotoError.message("The Base64 file has no file data after the comma.") }
        mediaType = type
        payload = compact
    }

    var normalizedURL: URL? { URL(string: "data:\(mediaType);base64,\(payload)") }

    func decodedData() throws -> Data {
        guard let data = Data(base64Encoded: payload), !data.isEmpty else {
            throw PhotoError.message("The Base64 file data is invalid or incomplete. Paste the full data:…;base64,… value.")
        }
        return data
    }
}
