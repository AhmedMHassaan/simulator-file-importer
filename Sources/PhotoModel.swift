import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ImportResult: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let succeeded: Bool
}

@MainActor
final class PhotoModel: ObservableObject {
    @Published var input = ""
    @Published var sources: [PhotoSource] = []
    @Published var devices: [SimulatorDevice] = []
    @Published var selected: Set<String> = []
    @Published var results: [ImportResult] = []
    @Published var error: String?
    @Published var refreshing = false
    @Published var importing = false
    @Published var progress = ""
    private var hasLoadedDevices = false

    var canImport: Bool { !sources.isEmpty && !selected.isEmpty && !importing && !refreshing }

    func addInput() {
        do {
            let source = try PhotoSource.parse(input)
            add(source.url)
            input = ""
        } catch { self.error = error.localizedDescription }
    }

    func add(_ url: URL) {
        guard !importing else { return }
        let normalized = url.isFileURL ? url.standardizedFileURL : url
        guard !sources.contains(where: { $0.url == normalized }) else { return }
        sources.append(PhotoSource(url: normalized))
        error = nil
    }

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = SafeFile.chooserTypes
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.prompt = "Add files"
        panel.begin { response in
            guard response == .OK else { return }
            Task { @MainActor in panel.urls.forEach { self.add($0) } }
        }
    }

    func refresh() async {
        guard !refreshing && !importing else { return }
        refreshing = true
        defer { refreshing = false }
        do {
            let available = try await SimulatorService.runningDevices()
            let ids = Set(available.map(\.id))
            selected.formIntersection(ids)
            if !hasLoadedDevices || (available.count == 1 && selected.isEmpty) { selected = ids }
            devices = available
            hasLoadedDevices = true
            error = nil
        } catch {
            devices = []
            selected = []
            self.error = error.localizedDescription
        }
    }

    func importPhotos() async {
        guard canImport else { return }
        importing = true
        results = []
        error = nil
        let targets = devices.filter { selected.contains($0.id) }
        let queue = sources
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SimulatorPhotos-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: directory)
            importing = false
            progress = ""
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for (index, source) in queue.enumerated() {
                progress = "Preparing file \(index + 1) of \(queue.count)…"
                let file: URL
                do {
                    // Downloading and decoding run away from the UI actor.
                    file = try await Task.detached { try await SimulatorService.prepare(source, in: directory) }.value
                } catch {
                    results.append(ImportResult(title: source.title, detail: error.localizedDescription, succeeded: false))
                    continue
                }
                for device in targets {
                    progress = "Importing \(index + 1) of \(queue.count) → \(device.name)…"
                    do {
                        let destination: String
                        if SafeFile.isImage(file) {
                            try await SimulatorService.importImage(file, to: device)
                            destination = "Added to Photos"
                        } else {
                            let saved = try await FilesService.importDocument(file, named: source.title, to: device)
                            destination = "Saved to Files → On My iPhone/iPad → Downloads → \(saved.lastPathComponent)"
                        }
                        results.append(ImportResult(title: "\(source.title) → \(device.name)", detail: "\(destination) · \(device.runtime) · \(device.id.prefix(8))", succeeded: true))
                    } catch {
                        results.append(ImportResult(title: "\(source.title) → \(device.name)", detail: error.localizedDescription, succeeded: false))
                    }
                }
            }
        } catch { self.error = error.localizedDescription }
    }
}
