import Foundation

enum FilesService {
    static func downloadsDirectory(for device: SimulatorDevice) async throws -> URL {
        let command = ["simctl", "get_app_container", device.id, "com.apple.DocumentsApp", "groups"]
        let output: Data
        do {
            output = try await AppleTool.run(command)
        } catch {
            // The local Files provider may not have a container until Files has been launched once.
            _ = try await AppleTool.run(["simctl", "launch", device.id, "com.apple.DocumentsApp"])
            output = try await AppleTool.run(command)
        }
        let text = String(decoding: output, as: UTF8.self)
        let group = "group.com.apple.FileProvider.LocalStorage"
        let path: String
        if let groups = try? JSONSerialization.jsonObject(with: output) as? [String: String], let value = groups[group] {
            path = value
        } else if let line = text.components(separatedBy: .newlines).first(where: { $0.contains(group) }),
                  let slash = line.firstIndex(of: "/") {
            path = String(line[slash...]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\";,")))
        } else {
            throw PhotoError.message("The simulator's local Files provider is not available. Open Files → Browse → On My iPhone/iPad once, then retry.")
        }
        guard path.hasPrefix("/"), !path.contains("\n"), FileManager.default.fileExists(atPath: path) else {
            throw PhotoError.message("Cannot locate the simulator's shared Files storage. Open Files in this simulator once, then retry.")
        }
        let storage = URL(fileURLWithPath: path).appendingPathComponent("File Provider Storage", isDirectory: true)
        let downloads = storage.appendingPathComponent("Downloads", isDirectory: true)
        guard downloads.resolvingSymlinksInPath().path.hasPrefix(URL(fileURLWithPath: path).resolvingSymlinksInPath().path + "/") else {
            throw PhotoError.message("The simulator's Downloads folder points outside its Files storage.")
        }
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        return downloads
    }

    static func availableDestination(in directory: URL, named name: String, extension ext: String) -> URL {
        let filename = (name as NSString).lastPathComponent
        let stem = String((filename as NSString).deletingPathExtension.prefix(100))
            .replacingOccurrences(of: ":", with: "-").replacingOccurrences(of: "\n", with: " ")
        let base = stem.isEmpty || stem == "." || stem == ".." ? "Imported file" : stem
        var candidate = directory.appendingPathComponent(base).appendingPathExtension(ext)
        var suffix = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(base) (\(suffix))").appendingPathExtension(ext)
            suffix += 1
        }
        return candidate
    }

    static func importDocument(_ file: URL, named name: String, to device: SimulatorDevice) async throws -> URL {
        let directory = try await downloadsDirectory(for: device)
        return try await copyDocument(file, named: name, into: directory)
    }

    static func copyDocument(_ file: URL, named name: String, into directory: URL) async throws -> URL {
        let ext = try SafeFile.validatedExtension(file)
        let destination = availableDestination(in: directory, named: name, extension: ext)
        // Stream file contents with rsync: filesystem cloning/copying can leave zero-byte files in the provider.
        _ = try await AppleTool.run(["--ignore-existing", "--", file.path, destination.path], executable: "/usr/bin/rsync")
        guard FileManager.default.contentsEqual(atPath: file.path, andPath: destination.path) else {
            throw PhotoError.message("The simulator did not save the complete document. Open Files in the simulator and retry.")
        }
        return destination
    }
}
