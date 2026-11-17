# Simulator File Importer

A standalone native macOS GUI to send images to **Photos** and PDFs or text documents to the selected simulators’ shared **Files → On My iPhone/iPad → Downloads** folder. Supports direct URLs, local file paths, drag and drop, and Base64 data URLs. No shell command is needed to use it.

## Download

Download **Simulator File Importer.zip** from the [latest GitHub release](https://github.com/AhmedMHassaan/simulator-file-importer/releases/latest). Unzip it, open the extracted folder, and move the app to Applications. The ZIP includes the app, README, step-by-step user guide, screenshot, and a complete Base64 image example.

Requires macOS 13 or later, Apple Silicon or Intel, and Xcode with an installed iOS simulator runtime and at least one running simulator. The build is locally signed and not Apple-notarized; see [Apple verification](#apple-verification) if macOS blocks it.

## Why this app exists

This utility addresses the workflow where Device Hub does not support dragging files into simulators. Drop files into this app instead, select the destination simulators, and import them. Device Hub behavior varies by Xcode version and setup; this app also provides multiple-destination imports, URL downloads, and Base64 decoding.

## Interface example

![Earlier interface showing the input field, drop area, and selected iPhone simulator](docs/images/simulator-photos-importer-example.png)

This screenshot shows an earlier build titled “Simulator Photos”. The current app is named **Simulator File Importer**, accepts documents and Base64 data, and uses the **Import to simulators** button.

## Quick start

1. Open **Simulator File Importer.app** and start the simulators you want to use.
2. Click **Refresh** to list running simulators.
3. Paste a direct file URL, local path, or complete Base64 data URL and click **Add**. Alternatively, use **Choose files…** or drag files from Finder into the drop area.
4. Check one or more destination simulators and click **Import to simulators**.
5. Open **Photos** for images, or **Files → Browse → On My iPhone/iPad → Downloads** for documents.

Read the [full user guide](USER_GUIDE.md) for installation, examples, Apple verification, and troubleshooting.

## Supported formats and destinations

| Input | Destination |
| --- | --- |
| Readable images, including PNG and JPEG | Simulator Photos library |
| PDF | Files → On My iPhone/iPad → Downloads |
| TXT, MD, CSV, JSON, XML, YAML, YML, LOG, RTF | Files → On My iPhone/iPad → Downloads |
| Base64 image data URL, such as `data:image/png;base64,...` | Decoded locally and added to Photos |
| Base64 PDF/text data URL, such as `data:application/pdf;base64,...` | Decoded locally and copied to Files → Downloads |

Paste the full Base64 value, including its MIME type and `;base64,` prefix. [A complete PNG example is included](docs/examples/base64-image.txt). Whitespace and line breaks in the encoded data are supported. Bare Base64 strings without the data URL prefix are not supported.

Supported text documents must be UTF-8 or UTF-16. Files are checked for readable image/PDF content or valid text; JSON and RTF also receive format checks. Executables, scripts, archives, app bundles, and folders are rejected. The format filter is not malware scanning or a guarantee that every accepted file is harmless. Files are copied without being executed or opened automatically.

Each file and simulator pair receives its own result. Existing document filenames are preserved by adding a suffix, such as `report (2).pdf`. Reimporting images can create duplicates in Photos. Local originals remain untouched; temporary downloads and decoded files are cleaned up after each import.

Documents use the simulator’s local Files provider. If the location is unavailable, open **Files → Browse → On My iPhone/iPad** in that simulator and retry. This storage layout may vary with simulator versions; failures are reported for the affected destination.

## Apple verification

The current build is locally signed and is not Apple-notarized. If macOS blocks a trusted copy after transfer, try opening it once, then use **System Settings → Privacy & Security → Open Anyway** and confirm. See the [user guide’s Apple verification instructions](USER_GUIDE.md#apple-verification-when-opening-the-app) and [Apple’s guidance](https://support.apple.com/102445).

For notarized distribution, the developer needs an Apple Developer Program membership, a **Developer ID Application** certificate, and a successful notarization submission followed by ticket stapling. The user guide explains the process and links to Apple’s documentation.

## Source and rebuilding

Open `SimulatorPhotos.xcodeproj` in Xcode and build the **SimulatorPhotos** scheme, or run `Build.command` with XcodeBuildMCP installed. The internal project/module name is retained from the original photo-only version. Release builds contain both `arm64` and `x86_64` code, with no third-party runtime dependencies.

`project.yml` is the XcodeGen project definition; regenerate with `xcodegen generate` after changing it. `Tools/GenerateIcon.swift` creates the native icon artwork.

The test target covers URLs and paths, simulator identity, Base64 decoding, image/PDF/text validation, HTTP downloads and failures, queue deduplication, and copying documents without overwriting existing files. Set `SIMULATOR_PHOTOS_LIVE_TEST=1` in the test runner environment to additionally import images and a PDF into the first running simulator.

## Developer

Developed by [Ahmed Mohamed Hassaan](https://www.linkedin.com/in/ahmedmhassaan/) · LinkedIn: **@ahmedmhassaan**.
