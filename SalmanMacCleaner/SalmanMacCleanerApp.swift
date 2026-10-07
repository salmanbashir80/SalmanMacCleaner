//
//  SalmanMacCleanerApp.swift
//  SalmanMacCleaner
//
//  App entry point: Aurora window sizing, shared environment objects,
//  appearance preference and native menu commands (including
//  "Check for Updates…").
//

import SwiftUI
import AppKit

@main
struct SalmanMacCleanerApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var accessibility = AccessibilityEnvironment.shared
    @StateObject private var permissionService = PermissionService.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Prevent duplicate instances of the app from running simultaneously
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            if runningApps.count > 1 {
                // Keep the oldest instance running, terminate if we are a newly launched duplicate
                let sorted = runningApps.sorted { ($0.launchDate ?? Date.distantFuture) < ($1.launchDate ?? Date.distantFuture) }
                if let oldest = sorted.first, oldest != NSRunningApplication.current {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(accessibility)
                .environmentObject(permissionService)
                .frame(minWidth: 1100, minHeight: 720)
                .preferredColorScheme(appState.settings.appearance.colorScheme)
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        permissionService.recheck()
                    }
                }
        }
        .defaultSize(width: 1440, height: 900)
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button(NSLocalizedString("menu.check_updates", comment: "")) {
                    SparkleUpdaterController.shared.checkForUpdates()
                }
                .keyboardShortcut("u", modifiers: [.command])
            }
            CommandGroup(after: .appTermination) {
                Button(NSLocalizedString("menu.smart_care", comment: "")) {
                    appState.module = .smartCare
                }
                .keyboardShortcut("1", modifiers: [.command])
                Button(NSLocalizedString("menu.deep_scan", comment: "")) {
                    appState.module = .deepScan
                }
                .keyboardShortcut("2", modifiers: [.command])
            }
            CommandGroup(replacing: .help) {
                Button(NSLocalizedString("menu.readme", comment: "")) {
                    guard let url = URL(string: "https://github.com/salmanbashir80/SalmanMacCleaner") else { return }
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
