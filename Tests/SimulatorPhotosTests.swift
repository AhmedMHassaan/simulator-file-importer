import XCTest
import AppKit
import Network
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
        listener.newConnectionHandler = { connection in
            connection.start(queue: .global())
            connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, _ in
                let request = String(decoding: data ?? Data(), as: UTF8.self)
                let missing = request.contains("/missing")
                let html = request.contains("/html")
                let body = (missing || html) ? Data("<html>Not an image</html>".utf8) : image
                let headers = "HTTP/1.1 \(missing ? "404 Not Found" : "200 OK")\r\nContent-Type: \(html ? "text/html" : "image/png")\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
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
        let image = directory.appendingPathComponent("Simulator photos importer test.png")
        try png().write(to: image)
        try await SimulatorService.importImage(image, to: device)
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
