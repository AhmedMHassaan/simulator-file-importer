import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var model: PhotoModel
    @State private var dropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.largeTitle).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Simulator File Importer").font(.title2.bold())
                    Text("Send images to Photos and documents to Files → Downloads.")
                        .foregroundStyle(.secondary)
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TextField("Paste a URL, file path, or Base64 data URL", text: $model.input)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { model.addInput() }
                        Button("Add") { model.addInput() }
                            .disabled(model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    VStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down").font(.title2)
                        Text("Drop images or documents here").font(.headline)
                        Button("Choose files…") { model.chooseFiles() }
                        Text("Files and Base64 data stay local. Web URLs download when you import.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(18)
                    .background(dropTargeted ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onDrop(of: [UTType.fileURL.identifier, UTType.url.identifier], isTargeted: $dropTargeted, perform: acceptDrop)

                    if !model.sources.isEmpty {
                        HStack {
                            Text("\(model.sources.count) file(s) queued").font(.subheadline.bold())
                            Spacer()
                            Button("Clear") { model.sources = [] }.buttonStyle(.link)
                        }
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(model.sources) { source in
                                    HStack {
                                        Image(systemName: source.isEmbeddedData ? "doc.text" : (source.url.isFileURL ? "photo" : "link")).foregroundStyle(.secondary)
                                        Text(source.displayLocation)
                                            .lineLimit(1).truncationMode(.middle).help(source.displayLocation)
                                        Spacer()
                                        Button { model.sources.removeAll { $0.id == source.id } } label: {
                                            Image(systemName: "xmark.circle.fill")
                                        }.buttonStyle(.borderless).accessibilityLabel("Remove \(source.title)")
                                    }
                                }
                            }
                        }.frame(maxHeight: 90)
                    }
                }.padding(8)
            }.disabled(model.importing)

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Running simulators").font(.headline)
                        Spacer()
                        if model.refreshing { ProgressView().controlSize(.small) }
                        Button("Refresh") { Task { await model.refresh() } }
                            .disabled(model.refreshing || model.importing)
                    }
                    if model.devices.isEmpty {
                        Text("Start an iOS simulator in Xcode or Simulator, then click Refresh.")
                            .foregroundStyle(.secondary).padding(.vertical, 8)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(model.devices) { device in
                                    Toggle(isOn: Binding(
                                        get: { model.selected.contains(device.id) },
                                        set: { checked in
                                            if checked { model.selected.insert(device.id) }
                                            else { model.selected.remove(device.id) }
                                        }
                                    )) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(device.name)
                                            Text("\(device.runtime) · \(device.id.prefix(8))")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                    }.toggleStyle(.checkbox)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.frame(maxHeight: 140)
                        HStack {
                            Button("Select all") { model.selected = Set(model.devices.map(\.id)) }
                            Button("Deselect all") { model.selected = [] }
                        }.buttonStyle(.link)
                    }
                }.padding(8)
            }.disabled(model.importing)

            if let error = model.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red).font(.callout).textSelection(.enabled)
                    .lineLimit(4).help(error)
            }

            if !model.results.isEmpty {
                Text("\(model.results.filter(\.succeeded).count) imported · \(model.results.filter { !$0.succeeded }.count) failed")
                    .font(.headline)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(model.results) { result in
                            HStack(alignment: .top) {
                                Image(systemName: result.succeeded ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundStyle(result.succeeded ? .green : .red)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(result.title).fontWeight(.medium)
                                    Text(result.detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                                }
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(minHeight: 60, maxHeight: 140)
            }
            Spacer(minLength: 0)
            HStack {
                if model.importing {
                    ProgressView().controlSize(.small)
                    Text(model.progress).font(.callout).foregroundStyle(.secondary)
                } else {
                    Text("\(model.selected.count) simulator(s) selected").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Import to simulators") { Task { await model.importPhotos() } }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(!model.canImport)
            }
            Divider()
            HStack(spacing: 6) {
                Text("Developed by Ahmed Mohamed Hassaan")
                    .foregroundStyle(.secondary)
                Text("·").foregroundStyle(.tertiary)
                Link("@ahmedmhassaan", destination: URL(string: "https://www.linkedin.com/in/ahmedmhassaan/")!)
                    .help("View Ahmed Mohamed Hassaan on LinkedIn")
            }
            .font(.caption)
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .task { await model.refresh() }
    }

    private func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !model.importing else { return false }
        for provider in providers {
            let type = provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
                ? UTType.fileURL.identifier : UTType.url.identifier
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, error in
                let url: URL?
                if let value = item as? URL { url = value }
                else if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                else if let text = item as? String { url = URL(string: text) }
                else { url = nil }
                Task { @MainActor in
                    if let url { model.add(url) }
                    else { model.error = error?.localizedDescription ?? "This drop did not contain a file or URL. Try Choose files instead." }
                }
            }
        }
        return !providers.isEmpty
    }
}
