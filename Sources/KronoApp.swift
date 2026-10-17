import SwiftUI

@main
struct KronoApp: App {
    @StateObject private var store = TaskStore()
    
    var body: some Scene {
        #if os(macOS)
        // Sits inside the macOS Menu Bar right next to Wi-Fi, Battery & Clock
        MenuBarExtra {
            MacMenuBarPopoverView(store: store)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: store.activeCount == 0 ? "checkmark.circle.fill" : "checklist")
                if store.activeCount > 0 {
                    Text("\(store.activeCount)")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                }
            }
        }
        .menuBarExtraStyle(.window)
        #else
        // Full Native iPhone Companion App
        WindowGroup {
            iOSCompanionView(store: store)
        }
        #endif
    }
}
