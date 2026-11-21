//
//  MenuBarView.swift
//  EpsonScanOpener
//
//  Popover shown when the user clicks the menu bar icon.
//  Popover, das beim Klick auf das Menüleisten-Icon erscheint.
//

import SwiftUI
import AppKit

struct MenuBarView: View {
    @Bindable var coordinator: OpenerCoordinator

    // Local mirror of the login-item toggle (SMAppService has no observable status)
    // Lokale Spiegelung des Login-Item-Schalters (SMAppService liefert keinen Observable Status)
    @State private var loginItemOn: Bool = false

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            statusBlock
            Divider()
            actions
            Divider()
            footer
        }
        .frame(width: 320)
        .padding(.vertical, 8)
        .onAppear {
            loginItemOn = coordinator.isLoginItemEnabled
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: coordinator.menuBarSymbolName)
                .font(.title2)
            Text("Epson Scan Opener")
                .font(.headline)
            Spacer()
            Toggle("Auto-Start", isOn: $coordinator.autoStartEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(coordinator.state.emoji)
                Text(coordinator.state.germanDescription)
                    .font(.body)
                Spacer()
            }
            HStack(spacing: 12) {
                Label(
                    coordinator.scannerOnline ? "Scanner online" : "Scanner offline",
                    systemImage: coordinator.scannerOnline ? "wifi" : "wifi.slash"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Label(
                    coordinator.epsonScan2Running ? "Epson Scan 2 läuft" : "Epson Scan 2 zu",
                    systemImage: coordinator.epsonScan2Running ? "checkmark.circle" : "circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var actions: some View {
        VStack(spacing: 0) {
            menuButton(label: "Jetzt öffnen", systemImage: "play.fill") {
                coordinator.openNow()
            }
            menuButton(label: "Status zurücksetzen", systemImage: "arrow.counterclockwise") {
                coordinator.resetState()
            }
            menuButton(label: "Einstellungen…", systemImage: "gearshape") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $loginItemOn) {
                Label("Beim Login starten", systemImage: "power.circle")
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .onChange(of: loginItemOn) { _, newValue in
                coordinator.setLoginItem(enabled: newValue)
                // Re-read to reflect actual SMAppService status
                loginItemOn = coordinator.isLoginItemEnabled
            }

            menuButton(label: "Epson Scan Opener beenden", systemImage: "power") {
                NSApp.terminate(nil)
            }
        }
    }

    @ViewBuilder
    private func menuButton(label: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
