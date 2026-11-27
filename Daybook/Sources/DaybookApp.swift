import SwiftUI

@main
struct DaybookApp: App {
    @StateObject private var model: AppModel

    init() {
        let args = ProcessInfo.processInfo.arguments
        let demo = args.contains("-DaybookDemo")
        if args.contains("-DaybookResetDefaults"), let id = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: id)
        }
        _model = StateObject(wrappedValue: AppModel(demo: demo))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(model.appearance.scheme)
                .task { await model.start() }
        }
    }
}
