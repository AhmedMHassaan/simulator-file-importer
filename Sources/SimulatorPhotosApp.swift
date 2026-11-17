import SwiftUI
import AppKit

@main
struct SimulatorPhotosApp: App {
    @StateObject private var model = PhotoModel()

    var body: some Scene {
        WindowGroup("Simulator photos importer") {
            ContentView(model: model)
                .frame(minWidth: 680, minHeight: 620)
                .onOpenURL { model.add($0) }
        }
        .defaultSize(width: 780, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add images…") { model.chooseFiles() }
                    .keyboardShortcut("o")
                    .disabled(model.importing)
            }
        }
    }
}
