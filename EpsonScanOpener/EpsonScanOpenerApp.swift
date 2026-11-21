//
//  EpsonScanOpenerApp.swift
//  EpsonScanOpener
//
//  App entry point – menu bar only app via MenuBarExtra.
//  App-Einstiegspunkt – reine Menüleisten-App via MenuBarExtra.
//

import SwiftUI

@main
struct EpsonScanOpenerApp: App {
    // Single shared coordinator for the whole app
    // Ein gemeinsamer Coordinator für die ganze App
    @State private var coordinator = OpenerCoordinator()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(coordinator: coordinator)
        } label: {
            // SF Symbol changes color based on state, set via tint in MenuBarView label
            // SF-Symbol; Status-Farbe wird über das Label gesetzt
            Image(systemName: coordinator.menuBarSymbolName)
        }
        .menuBarExtraStyle(.window)

        // Settings window – opened via "Einstellungen…" in the popover
        // Einstellungsfenster – wird über „Einstellungen…" im Popover geöffnet
        Settings {
            SettingsView(coordinator: coordinator)
        }
    }
}
