import SwiftUI

@main
struct TraducteurEcranApp: App {
    @State private var modele = Modele()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(modele)
        }
    }
}
