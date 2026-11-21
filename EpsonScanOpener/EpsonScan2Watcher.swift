//
//  EpsonScan2Watcher.swift
//  EpsonScanOpener
//
//  Tracks whether Epson Scan 2 is currently running, both via initial
//  scan of running apps and via NSWorkspace launch/terminate notifications.
//
//  Beobachtet, ob Epson Scan 2 gerade läuft – initial via Liste der
//  laufenden Apps und laufend via Workspace-Notifications.
//

import AppKit
import Observation

@Observable
final class EpsonScan2Watcher {
    /// Whether Epson Scan 2 is currently running.
    /// Ob Epson Scan 2 gerade läuft.
    private(set) var isRunning: Bool = false

    @ObservationIgnored private var bundleIdentifier: String
    @ObservationIgnored private var appName: String
    @ObservationIgnored private var observerTokens: [NSObjectProtocol] = []

    /// Callback when `isRunning` changes.
    /// Callback bei Änderung von `isRunning`.
    var onStateChange: ((Bool) -> Void)?

    init(
        bundleIdentifier: String = "com.epson.Epson-Scan-2",
        appName: String = "Epson Scan 2"
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
    }

    func start() {
        isRunning = currentlyRunning()
        let center = NSWorkspace.shared.notificationCenter

        observerTokens.append(center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            if self.matches(note) {
                self.updateRunning(true)
            }
        })

        observerTokens.append(center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            if self.matches(note) {
                // Use a fresh check – another instance might still be running
                self.updateRunning(self.currentlyRunning())
            }
        })
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        for token in observerTokens { center.removeObserver(token) }
        observerTokens.removeAll()
    }

    /// Fallback resync – call periodically in case a notification was missed.
    /// Fallback-Resync – periodisch aufrufen, falls eine Notification verschluckt wurde.
    func resync() {
        updateRunning(currentlyRunning())
    }

    /// Update bundle identifier / app name and re-evaluate running state.
    /// Bundle-ID / App-Namen ändern und Lauf-Status neu prüfen.
    func reconfigure(bundleIdentifier: String, appName: String) {
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        resync()
    }

    private func updateRunning(_ newValue: Bool) {
        guard newValue != isRunning else { return }
        isRunning = newValue
        onStateChange?(newValue)
    }

    private func currentlyRunning() -> Bool {
        // Match by bundle identifier first (precise)
        if !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty {
            return true
        }
        // Fallback: localized name (in case the bundle identifier differs on this system)
        return NSWorkspace.shared.runningApplications.contains { app in
            app.localizedName == appName
        }
    }

    private func matches(_ note: Notification) -> Bool {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return false
        }
        if app.bundleIdentifier == bundleIdentifier { return true }
        if app.localizedName == appName { return true }
        return false
    }
}
