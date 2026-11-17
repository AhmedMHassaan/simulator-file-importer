# Simulator File Importer — User guide

Developed by [Ahmed Mohamed Hassaan](https://www.linkedin.com/in/ahmedmhassaan/) · LinkedIn: **@ahmedmhassaan**.

Send images to the simulator’s **Photos library**, and PDFs or supported text documents to its shared **Files → On My iPhone/iPad → Downloads** folder, similar to Android’s shared Downloads folder.

## Why this app exists

When Device Hub does not support dragging and dropping files into a simulator in your setup, use this utility to import them. Drag and drop into this app is supported. Device Hub behavior can vary by Xcode version; this app additionally supports multiple destination simulators, direct file URLs, and Base64 data URLs.

## Interface example

![Earlier interface showing the input field, drop area, and selected simulator](docs/images/simulator-photos-importer-example.png)

This screenshot shows an earlier photo-only build titled “Simulator Photos”. The current app is named **Simulator File Importer**, also accepts documents and Base64 data, and has an **Import to simulators** button.

## 1. Requirements

- macOS 13 Ventura or later, on an Intel or Apple Silicon Mac.
- Xcode installed and opened at least once, with initial setup completed and an iOS simulator runtime installed.
- At least one running simulator.

Xcode Command Line Tools alone do not include iOS simulators. No Terminal, shell configuration, or other project is required to use this app.

## 2. Install and open

1. Download **Simulator File Importer.zip** from the [latest release](https://github.com/AhmedMHassaan/simulator-file-importer/releases/latest).
2. Double-click the ZIP to extract it, then open the extracted **Simulator File Importer** folder.
3. Move **Simulator File Importer.app** to Applications or another folder of your choice.
4. Double-click the app.

The ZIP also contains this guide, README, screenshot, and a complete Base64 example. macOS may require approval after transfer because this build is not Apple-notarized.

## Apple verification when opening the app

The downloadable build is locally signed and has not been notarized by Apple. On another Mac, you may see a warning that Apple cannot verify the developer or check the app for malicious software.

If you trust the copy you received:

1. Try opening **Simulator File Importer.app** once, then dismiss the warning.
2. Open **System Settings → Privacy & Security**.
3. Find the blocked-app message and click **Open Anyway**.
4. Confirm that you want to open the app, authenticating if asked.

This grants an exception on that Mac; it does not notarize the app. Organization-managed Macs may restrict this option. Only approve a copy from a source you trust. See [Apple’s instructions for opening apps safely](https://support.apple.com/102445).

For a developer to distribute an Apple-notarized build:

1. Enroll in the **Apple Developer Program** and obtain a **Developer ID Application** signing certificate.
2. Sign the release app with Developer ID and hardened runtime enabled.
3. Submit it to Apple’s notarization service. Xcode’s **Archive → Distribute App → Developer ID** workflow can handle distribution signing and notarization.
4. After Apple accepts it, attach the notarization ticket to the app (stapling), verify the result, and create a new ZIP from that app.

Notarization does not require publishing the app in the Mac App Store. See [Apple’s notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## 3. Start and select simulators

1. Open Xcode, then choose **Xcode → Open Developer Tool → Simulator**.
2. In Simulator, use **File → Open Simulator** to start the devices you need. Wait for them to boot.
3. In Simulator File Importer, click **Refresh**.
4. Check the destination simulators. Use **Select all** or **Deselect all** as needed.

Only running simulators appear. Refresh again after starting or closing devices. The first successful refresh selects the running simulators; review the checkboxes before importing. Devices with identical names are distinguished by runtime and short device ID.

## 4. Add files

You can combine any of these methods in the same queue.

### Choose files

Click **Choose files…**, select one or more supported images or documents, then click **Add files**. Hold Command to select several files. **Command + O** also opens the chooser.

### Drag and drop

Drag files from Finder onto **Drop images or documents here**. Their paths appear automatically in the queue. Folders and app bundles are not supported.

### Paste a local path

Paste a path, then click **Add** or press Return:

```text
/Users/yourname/Pictures/sample photo.png
~/Downloads/report.pdf
file:///Users/yourname/Downloads/notes.txt
```

Paths containing spaces are supported. Use a normal Finder path rather than a shell-escaped path.

### Paste a direct URL

Paste an `https://` or `http://` URL that returns a supported image or document, then click **Add**. A webpage containing a file, a sign-in page, or an image search page will not work. Downloads happen when you import, so network access is needed at that time. Custom sign-in flows and authentication headers are not supported.

### Paste Base64 data

Paste a complete Base64 **data URL**, then click **Add**. Examples of prefixes:

```text
data:image/png;base64,...
data:image/jpeg;base64,...
data:application/pdf;base64,...
data:text/plain;base64,...
data:application/json;base64,...
```

Replace `...` with the complete encoded file contents; an ellipsis is not valid image or document data. The MIME type and `;base64,` prefix are required. [Open the included complete PNG example](docs/examples/base64-image.txt), copy its entire contents, and paste it into the app to try it.

The app accepts line breaks and whitespace within the Base64 payload. Embedded files decode locally, without a network request. A readable label appears in the queue rather than the long encoded string. Invalid Base64 or decoded file content produces an error for that item. Bare Base64 strings without the data URL prefix are not supported.

### Review the queue

- Remove an entry with the **×** button, or use **Clear** to empty the queue.
- Adding the same path, URL, or normalized Base64 value again does not duplicate the queue entry.
- Queue deduplication does not check whether the file was imported in an earlier operation.

## 5. Supported formats

| Format | Destination |
| --- | --- |
| Readable images, including PNG/JPEG | Photos library |
| PDF | Shared Files Downloads folder |
| TXT, MD, CSV, JSON, XML, YAML, YML, LOG, RTF | Shared Files Downloads folder |
| Base64 data URLs for those formats | Same destination as the decoded file |

Text documents must be UTF-8 or UTF-16. JSON and RTF also receive format checks. Executables, scripts, archives, app bundles, and directories are rejected. This is a format filter, not malware scanning or a guarantee that a file is harmless. The importer does not execute or automatically open imported files.

## 6. Import and find your files

1. Add at least one file and check at least one simulator.
2. Click **Import to simulators** and wait for the progress message to finish.
3. Review each result. A failure for one file or simulator does not prevent the others from being attempted.
4. For images, open **Photos** inside the selected simulator.
5. For PDFs and other documents, open **Files → Browse → On My iPhone/iPad → Downloads** inside the selected simulator.

For example, importing two valid files into three selected simulators produces six destination results.

Documents go into a shared Downloads folder, not an individual app’s private Documents directory. Apps can select them through a document picker that exposes the Files app. The Files provider may need to be opened once on a new simulator: open **Files → Browse → On My iPhone/iPad**, then retry the import if needed.

Existing documents are preserved. A duplicate filename receives a number, such as `report (2).pdf`. Reimporting images can create duplicates in Photos. Local originals are unchanged. Downloaded and decoded temporary files are removed after the operation. The queue remains available for another import.

## 7. Troubleshooting

| Problem | What to try |
| --- | --- |
| No simulators appear | Start a simulator, wait for it to boot, then click **Refresh**. |
| Simulator tools cannot be found | Complete Xcode setup. Check **Xcode → Settings → Locations → Command Line Tools** points to your installed Xcode. |
| **Import to simulators** is disabled | Queue a file and select at least one simulator. Wait for the current refresh/import to finish. |
| A local file cannot be read | Confirm it exists and choose it again, especially if it was moved or renamed. |
| URL download fails | Check network access and use a direct file URL that does not require sign-in. |
| Base64 is invalid | Paste the full `data:<MIME type>;base64,<payload>` value. Do not include an ellipsis or truncate it. |
| A format is unsupported | Use a readable image, PDF, or a listed text format. Renaming an executable to a document extension does not make it supported. |
| PDF/text validation fails | Check the file opens correctly. For text, use UTF-8/UTF-16; JSON and RTF must have valid formatting. |
| Files provider is unavailable | Open **Files → Browse → On My iPhone/iPad** on that simulator once, then retry. Simulator storage behavior can vary by runtime. |
| Documents do not appear immediately | Reopen the Downloads folder in Files; confirm the import result succeeded for that simulator. |
| One simulator fails | Make sure it is still running, refresh the list, and retry only the necessary destinations. |
| An operation times out | Check that the simulator responds normally, refresh, and retry. |
| An image is missing from Downloads | Images are imported into **Photos**. Documents are copied to **Files → Downloads**. |

## 8. Share with another Mac

Send **Simulator File Importer.zip** to the other Mac and follow section 2. No rebuild is needed. That Mac must meet the requirements in section 1. The app discovers that Mac’s own running simulators; it does not transfer simulator devices or runtimes.

## Developer

**Developed by Ahmed Mohamed Hassaan**

LinkedIn: [@ahmedmhassaan](https://www.linkedin.com/in/ahmedmhassaan/)
