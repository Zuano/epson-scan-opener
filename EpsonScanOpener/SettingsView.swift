//
//  SettingsView.swift
//  EpsonScanOpener
//
//  Settings window: scanner IP/port and Epson Scan 2 app path.
//  Einstellungsfenster: Scanner-IP/-Port und Epson-Scan-2-Pfad.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var coordinator: OpenerCoordinator

    // Local form state – only written back when the user clicks "Speichern".
    // Lokaler Formular-Zustand – wird erst beim Klick auf „Speichern" übernommen.
    @State private var hostField: String = ""
    @State private var portField: String = ""
    @State private var pathField: String = ""

    var body: some View {
        Form {
            Section("Scanner") {
                TextField("IP-Adresse", text: $hostField)
                    .textFieldStyle(.roundedBorder)
                TextField("Port", text: $portField)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 120, alignment: .leading)
                Text("Default: 80. Falls dein Scanner im Aus-Zustand auf Port 80 antwortet, probier 1865 oder 515.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Epson Scan 2") {
                HStack {
                    TextField("Pfad zur App", text: $pathField)
                        .textFieldStyle(.roundedBorder)
                    Button("Suchen…") {
                        browseForApp()
                    }
                }
                HStack(spacing: 6) {
                    Image(systemName: coordinator.appPathExists ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(coordinator.appPathExists ? .green : .orange)
                    Text(coordinator.appPathExists
                         ? "Bundle-ID: \(coordinator.appBundleIdentifier)"
                         : "Datei nicht gefunden – bitte Pfad prüfen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                HStack {
                    Button("Auf Standard zurücksetzen") {
                        hostField = "192.168.1.25"
                        portField = "80"
                        pathField = "/Applications/Epson Software/Epson Scan 2.app"
                    }
                    Spacer()
                    Button("Speichern") {
                        save()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(width: 520)
        .onAppear {
            hostField = coordinator.scannerHost
            portField = String(coordinator.scannerPort)
            pathField = coordinator.appPath
        }
    }

    private func save() {
        if let port = UInt16(portField.trimmingCharacters(in: .whitespaces)) {
            coordinator.updateScannerEndpoint(host: hostField, port: port)
        }
        coordinator.updateAppPath(pathField)
    }

    /// Show an Open panel filtered to application bundles.
    /// Open-Panel auf App-Bundles eingeschränkt.
    private func browseForApp() {
        let panel = NSOpenPanel()
        panel.title = "Epson Scan 2 auswählen"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            pathField = url.path
        }
    }
}
