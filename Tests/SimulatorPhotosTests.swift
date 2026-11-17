import XCTest
import AppKit
import Network
import PDFKit
@testable import SimulatorPhotos

final class SimulatorPhotosTests: XCTestCase {
    func testSourceParsingPreservesSpacesAndShellCharacters() throws {
        let path = "/tmp/my image $(echo hello);'test'.png"
        XCTAssertEqual(try PhotoSource.parse(path).url.path, path)
        XCTAssertEqual(try PhotoSource.parse("\"/tmp/my image.png\"").url.path, "/tmp/my image.png")
        XCTAssertEqual(try PhotoSource.parse("file:///tmp/my%20image.png").url.path, "/tmp/my image.png")
        XCTAssertEqual(try PhotoSource.parse("~/Pictures/a.png").url.path,
                       FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures/a.png").path)
        XCTAssertThrowsError(try PhotoSource.parse("  "))
        XCTAssertThrowsError(try PhotoSource.parse("ftp://example.com/image.png"))
        XCTAssertEqual(try PhotoSource.parse("https://example.com/image.png?q=1").url.scheme, "https")
    }

    func testOnlyBootedDevicesAreListedAndDuplicateNamesRetainIdentity() throws {
        let data = Data(#"{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-5":[{"name":"iPhone","udid":"B","state":"Booted"},{"name":"iPhone","udid":"C","state":"Shutdown"}],"com.apple.CoreSimulator.SimRuntime.iOS-26-4":[{"name":"iPhone","udid":"A","state":"Booted"}]}}"#.utf8)
        let devices = try SimulatorService.decodeDevices(data)
        XCTAssertEqual(devices.map(\.id), ["A", "B"])
        XCTAssertEqual(devices.first?.runtime, "iOS 26 4")
        XCTAssertThrowsError(try SimulatorService.decodeDevices(Data("invalid".utf8)))
    }

    func testPrepareCopiesImageWithCorrectExtensionAndRejectsNonImages() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = directory.appendingPathComponent("image with spaces & symbols.dat")
        try png().write(to: original)
        let prepared = try await SimulatorService.prepare(PhotoSource(url: original), in: directory)
        XCTAssertEqual(prepared.pathExtension, "png")
        XCTAssertNotEqual(prepared, original)
        XCTAssertEqual(try Data(contentsOf: prepared), try Data(contentsOf: original))
        let invalid = directory.appendingPathComponent("fake.png")
        try Data("<html>not a photo</html>".utf8).write(to: invalid)
        XCTAssertThrowsError(try SimulatorService.validateImage(invalid))
        do {
            _ = try await SimulatorService.prepare(PhotoSource(url: directory.appendingPathComponent("missing.png")), in: directory)
            XCTFail("Missing file was accepted")
        } catch { XCTAssertTrue(error.localizedDescription.contains("Cannot read")) }
    }

    @MainActor
    func testQueueDeduplicatesAndRequiresSimulatorSelection() {
        let model = PhotoModel()
        model.add(URL(fileURLWithPath: "/tmp/photo.png"))
        model.add(URL(fileURLWithPath: "/tmp/photo.png"))
        XCTAssertEqual(model.sources.count, 1)
        XCTAssertFalse(model.canImport)
        model.selected.insert("example")
        XCTAssertTrue(model.canImport)
        model.importing = true
        XCTAssertFalse(model.canImport)
    }

    func testURLDownloadsAndRejectsHTMLAndHTTPFailures() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let listener = try NWListener(using: .tcp, on: .any)
        let ready = expectation(description: "Local HTTP fixture ready")
        listener.stateUpdateHandler = { state in if case .ready = state { ready.fulfill() } }
        let image = png()
        let document = try pdf()
        listener.newConnectionHandler = { connection in
            connection.start(queue: .global())
            connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, _ in
                let request = String(decoding: data ?? Data(), as: UTF8.self)
                let missing = request.contains("/missing")
                let html = request.contains("/html")
                let isPDF = request.contains("/pdf")
                let body = (missing || html) ? Data("<html>Not an image</html>".utf8) : (isPDF ? document : image)
                let headers = "HTTP/1.1 \(missing ? "404 Not Found" : "200 OK")\r\nContent-Type: \(html ? "text/html" : (isPDF ? "application/pdf" : "image/png"))\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
                connection.send(content: Data(headers.utf8) + body, completion: .contentProcessed { _ in connection.cancel() })
            }
        }
        listener.start(queue: .global())
        defer { listener.cancel() }
        await fulfillment(of: [ready], timeout: 5)
        let port = try XCTUnwrap(listener.port?.rawValue)
        let source = try PhotoSource.parse("http://127.0.0.1:\(port)/image")
        let downloaded = try await SimulatorService.prepare(source, in: directory)
        XCTAssertEqual(downloaded.pathExtension, "png")
        XCTAssertEqual(try Data(contentsOf: downloaded), image)
        let pdfSource = try PhotoSource.parse("http://127.0.0.1:\(port)/pdf")
        let downloadedPDF = try await SimulatorService.prepare(pdfSource, in: directory)
        XCTAssertEqual(downloadedPDF.pathExtension, "pdf")
        XCTAssertEqual(try Data(contentsOf: downloadedPDF), document)
        for route in ["missing", "html"] {
            do {
                _ = try await SimulatorService.prepare(PhotoSource.parse("http://127.0.0.1:\(port)/\(route)"), in: directory)
                XCTFail("Invalid response accepted: \(route)")
            } catch {
                XCTAssertFalse(error.localizedDescription.isEmpty)
            }
        }
    }

    /// Opt in explicitly: this imports a small test image into one running simulator.
    func testLiveImport() async throws {
        guard ProcessInfo.processInfo.environment["SIMULATOR_PHOTOS_LIVE_TEST"] == "1" else {
            throw XCTSkip("Set SIMULATOR_PHOTOS_LIVE_TEST=1 to verify a real Photos import")
        }
        let devices = try await SimulatorService.runningDevices()
        let device = try XCTUnwrap(devices.first, "Start a simulator before the live test")
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let image = directory.appendingPathComponent("Simulator File Importer test.png")
        try png().write(to: image)
        try await SimulatorService.importImage(image, to: device)
        let base64 = try await SimulatorService.prepare(PhotoSource.parse(base64Example()), in: directory)
        try await SimulatorService.importImage(base64, to: device)
        let pdfSource = try PhotoSource.parse("data:application/pdf;base64," + pdf().base64EncodedString())
        let pdfFile = try await SimulatorService.prepare(pdfSource, in: directory)
        let saved = try await FilesService.importDocument(pdfFile, named: "Simulator importer test.pdf", to: device)
        XCTAssertEqual(try Data(contentsOf: saved), try Data(contentsOf: pdfFile))
        XCTAssertEqual(saved.deletingLastPathComponent().lastPathComponent, "Downloads")
    }

    func testBase64ExamplePreparesReadablePNG() async throws {
        let source = try PhotoSource.parse(base64Example())
        XCTAssertTrue(source.isBase64Image)
        XCTAssertEqual(source.title, "Base64 image")
        XCTAssertLessThan(source.displayLocation.count, 80)
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let image = try await SimulatorService.prepare(source, in: directory)
        XCTAssertEqual(image.pathExtension, "png")
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: image)))
        XCTAssertEqual(bitmap.pixelsWide, 152)
        XCTAssertEqual(bitmap.pixelsHigh, 148)
    }

    func testBase64WhitespaceEscapesAndHeaderValidation() throws {
        let image = try Base64File(base64Example().trimmingCharacters(in: .whitespacesAndNewlines))
        let decorated = "  DATA:IMAGE/PNG;charset=utf-8;BASE64,\n" + image.payload.prefix(100)
            + "\n  " + image.payload.dropFirst(100) + "\n "
        let normalized = try PhotoSource.parse(decorated)
        XCTAssertEqual(try Base64File(normalized.url.absoluteString).decodedData(), try image.decodedData())
        XCTAssertEqual(try Base64File("data:image/png;base64,/w%3D%3D").decodedData(), Data([255]))
        for value in ["data:image/png;base64,", "data:image/png;base64", "data:application/x-sh;base64,SGk=", "data:image/png,SGk=", "data:image/;base64,SGk="] {
            XCTAssertThrowsError(try PhotoSource.parse(value), value)
        }
        XCTAssertThrowsError(try Base64File("data:image/png;base64,not!base64").decodedData())
        XCTAssertThrowsError(try Base64File("data:image/png;base64,a").decodedData())
    }

    func testBase64RejectsDecodedNonImageAndCorruptImage() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let examples = [Data("<html>not an image</html>".utf8), png().prefix(20)]
        for data in examples {
            let source = try PhotoSource.parse("data:image/png;base64," + data.base64EncodedString())
            do {
                _ = try await SimulatorService.prepare(source, in: directory)
                XCTFail("Non-image or truncated image was accepted")
            } catch { XCTAssertTrue(error.localizedDescription.contains("not a readable image")) }
        }
    }

    @MainActor
    func testBase64QueueDeduplicatesNormalizedInput() throws {
        let model = PhotoModel()
        model.input = try base64Example()
        model.addInput()
        XCTAssertNil(model.error)
        XCTAssertEqual(model.sources.count, 1)
        XCTAssertEqual(model.input, "")
        model.input = try base64Example().replacingOccurrences(of: ",", with: ",\n ")
        model.addInput()
        XCTAssertEqual(model.sources.count, 1)
    }

    func testPDFAndTextPreparationFromFilesAndBase64() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let examples: [(String, String, Data)] = [
            ("report.pdf", "application/pdf", try pdf()),
            ("notes.txt", "text/plain", Data("Hello simulator\nمرحبا".utf8)),
            ("data.json", "application/json", Data("{\"message\":\"hello\"}".utf8)),
            ("rows.csv", "text/csv", Data("name,value\nexample,1".utf8))
        ]
        for (name, mime, data) in examples {
            let local = directory.appendingPathComponent(name)
            try data.write(to: local)
            for source in [PhotoSource(url: local), try PhotoSource.parse("data:\(mime);base64," + data.base64EncodedString())] {
                let file = try await SimulatorService.prepare(source, in: directory)
                XCTAssertFalse(SafeFile.isImage(file))
                XCTAssertEqual(file.pathExtension, local.pathExtension)
                XCTAssertEqual(try Data(contentsOf: file), data)
            }
        }
    }

    func testUnsupportedAndInvalidDocumentsAreRejected() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        for (name, data) in [
            ("run.sh", Data("#!/bin/sh\necho test".utf8)),
            ("binary.txt", Data([0, 1, 2, 255])),
            ("fake.pdf", Data("not a PDF".utf8)),
            ("invalid.json", Data("{not json".utf8)),
            ("fake.rtf", Data("plain text".utf8))
        ] {
            let file = directory.appendingPathComponent(name)
            try data.write(to: file)
            XCTAssertThrowsError(try SafeFile.validatedExtension(file), name)
        }
        XCTAssertThrowsError(try SafeFile.validatedExtension(directory))
        XCTAssertThrowsError(try PhotoSource.parse("data:application/x-executable;base64,SGk="))
    }

    func testDocumentCopyPreservesContentsAndDoesNotOverwrite() async throws {
        let sourceDirectory = try makeDirectory()
        let destination = try makeDirectory()
        defer {
            try? FileManager.default.removeItem(at: sourceDirectory)
            try? FileManager.default.removeItem(at: destination)
        }
        let source = sourceDirectory.appendingPathComponent("notes.txt")
        let data = Data("Document with spaces and symbols".utf8)
        try data.write(to: source)
        let first = try await FilesService.copyDocument(source, named: "my notes.txt", into: destination)
        let second = try await FilesService.copyDocument(source, named: "my notes.txt", into: destination)
        XCTAssertEqual(first.lastPathComponent, "my notes.txt")
        XCTAssertEqual(second.lastPathComponent, "my notes (2).txt")
        XCTAssertEqual(try Data(contentsOf: first), data)
        XCTAssertEqual(try Data(contentsOf: second), data)
        let sanitized = FilesService.availableDestination(in: destination, named: "../../other.txt", extension: "txt")
        XCTAssertEqual(sanitized.deletingLastPathComponent().path, destination.path)
    }

    private func pdf() throws -> Data {
        let document = PDFDocument()
        let image = try XCTUnwrap(NSImage(data: png()))
        let page = try XCTUnwrap(PDFPage(image: image))
        document.insert(page, at: 0)
        return try XCTUnwrap(document.dataRepresentation())
    }

    private func base64Example() throws -> String {
        let url = try XCTUnwrap(Bundle(for: SimulatorPhotosTests.self).url(forResource: "base64-example", withExtension: "txt"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func png() -> Data {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 16, pixelsHigh: 16,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        for y in 0..<16 { for x in 0..<16 { bitmap.setColor(.systemBlue, atX: x, y: y) } }
        return bitmap.representation(using: .png, properties: [:])!
    }
}
