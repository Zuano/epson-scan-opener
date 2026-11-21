//
//  OpenerCoordinator.swift
//  EpsonScanOpener
//
//  Wires ScannerPinger + EpsonScan2Watcher into a state machine and triggers
//  the launch of Epson Scan 2 when appropriate.
//
//  Verbindet ScannerPinger + EpsonScan2Watcher zu einer State-Machine und
//  startet Epson Scan 2 zum richtigen Zeitpunkt.
//

import AppKit
import Observation
import ServiceManagement
import os

@Observable
final class OpenerCoordinator {
    // MARK: - Public observable state
    // MARK: - Öffentlich beobachtbarer Status

    private(set) var state: OpenerState = .armed
    private(set) var scannerOnline: Bool = false
    private(set) var epsonScan2Running: Bool = false

    /// User toggle in the menu. When false, no auto-launch happens.
    /// Schalter im Menü. Wenn aus, kein Auto-Start.
    var autoStartEnabled: Bool = true {
        didSet { persistSettings() }
    }

    var isLoginItemEnabled: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            }
            return false
        }
    }

    // MARK: - Wiring
    // MARK: - Verdrahtung

    @ObservationIgnored private let pinger: ScannerPinger
    @ObservationIgnored private let watcher: EpsonScan2Watcher
    @ObservationIgnored private var resyncTimer: Timer?
    @ObservationIgnored private let log = Logger(subsystem: "io.github.zuano.EpsonScanOpener", category: "Coordinator")

    // MARK: - User-editable settings (persisted in UserDefaults)
    // MARK: - Benutzer-Einstellungen (in UserDefaults gespeichert)

    /// IP / hostname of the scanner.
    /// IP / Hostname des Scanners.
    private(set) var scannerHost: String

    /// TCP port used for the reachability check.
    /// TCP-Port für die Erreichbarkeitsprüfung.
    private(set) var scannerPort: UInt16

    /// Filesystem path to the Epson Scan 2 app bundle.
    /// Dateipfad zum Epson Scan 2 App-Bundle.
    private(set) var appPath: String

    /// Bundle identifier of the Epson Scan 2 app (auto-detected from `appPath`).
    /// Bundle-ID der Epson Scan 2 App (wird automatisch aus `appPath` erkannt).
    private(set) var appBundleIdentifier: String

    // UserDefaults keys
    private let autoStartKey = "autoStartEnabled"
    private let scannerHostKey = "scannerHost"
    private let scannerPortKey = "scannerPort"
    private let appPathKey = "appPath"
    private let appBundleIDKey = "appBundleIdentifier"

    // Default values – used when nothing is in UserDefaults yet.
    // Standard-Werte – greifen, solange UserDefaults leer sind.
    private static let defaultHost = "192.168.1.25"
    private static let defaultPort: UInt16 = 80
    private static let defaultAppPath = "/Applications/Epson Software/Epson Scan 2.app"
    private static let defaultBundleID = "com.epson.Epson-Scan-2"

    init() {
        let defaults = UserDefaults.standard
        let host = defaults.string(forKey: "scannerHost") ?? Self.defaultHost
        let storedPort = defaults.integer(forKey: "scannerPort")
        let port: UInt16 = storedPort > 0 ? UInt16(clamping: storedPort) : Self.defaultPort
        let path = defaults.string(forKey: "appPath") ?? Self.defaultAppPath
        let bundleID = defaults.string(forKey: "appBundleIdentifier") ?? Self.defaultBundleID

        self.scannerHost = host
        self.scannerPort = port
        self.appPath = path
        self.appBundleIdentifier = bundleID

        self.pinger = ScannerPinger(host: host, port: port)
        self.watcher = EpsonScan2Watcher(
            bundleIdentifier: bundleID,
            appName: (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        )

        if defaults.object(forKey: autoStartKey) != nil {
            self.autoStartEnabled = defaults.bool(forKey: autoStartKey)
        }

        wire()
        watcher.start()
        epsonScan2Running = watcher.isRunning
        // Seed initial state based on whether Epson Scan 2 is already running.
        // Falls Epson Scan 2 schon läuft, starten wir nicht in `armed`.
        if epsonScan2Running {
            state = .active
        }
        pinger.start()

        // Periodic safety net in case a workspace notification is missed
        // Periodisches Sicherheitsnetz, falls eine Notification fehlt
        resyncTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.watcher.resync()
        }
    }

    deinit {
        pinger.stop()
        watcher.stop()
        resyncTimer?.invalidate()
    }

    private func wire() {
        pinger.onStateChange = { [weak self] online in
            guard let self else { return }
            self.scannerOnline = online
            self.handleScannerChange(online: online)
        }
        watcher.onStateChange = { [weak self] running in
            guard let self else { return }
            self.epsonScan2Running = running
            self.handleEpsonScan2Change(running: running)
        }
    }

    // MARK: - State transitions
    // MARK: - Zustandsübergänge

    private func handleScannerChange(online: Bool) {
        log.info("scanner online=\(online, privacy: .public) state=\(self.state.rawValue, privacy: .public)")
        switch state {
        case .armed:
            if online {
                launchEpsonScan2(reason: "scanner went online while armed")
            }
        case .active:
            // Don't care – we wait for Epson Scan 2 to close
            break
        case .waitingForScannerOffline:
            if !online {
                transition(to: .waitingForPowerOn, reason: "scanner powered down")
            }
        case .waitingForPowerOn:
            if online {
                // User flipped the power switch – treat as armed and launch
                transition(to: .armed, reason: "scanner powered on by user")
                if !epsonScan2Running {
                    launchEpsonScan2(reason: "post power-on")
                }
            }
        }
    }

    private func handleEpsonScan2Change(running: Bool) {
        log.info("epsonScan2 running=\(running, privacy: .public) state=\(self.state.rawValue, privacy: .public)")
        switch state {
        case .armed:
            if running {
                transition(to: .active, reason: "Epson Scan 2 launched (externally)")
            }
        case .active:
            if !running {
                // Epson Scan 2 has been closed (by Quitter, by user, or crash)
                // → next step: wait for scanner to power down
                transition(to: .waitingForScannerOffline, reason: "Epson Scan 2 quit")
            }
        case .waitingForScannerOffline:
            if running {
                // User manually relaunched Epson Scan 2 – respect that
                transition(to: .active, reason: "user relaunched Epson Scan 2")
            }
        case .waitingForPowerOn:
            if running {
                transition(to: .active, reason: "Epson Scan 2 launched while waiting")
            }
        }
    }

    private func transition(to newState: OpenerState, reason: String) {
        guard newState != state else { return }
        log.info("transition \(self.state.rawValue, privacy: .public) -> \(newState.rawValue, privacy: .public) (\(reason, privacy: .public))")
        state = newState
    }

    // MARK: - Launching
    // MARK: - Starten

    /// Launches Epson Scan 2. Respects `autoStartEnabled`.
    /// Startet Epson Scan 2. Berücksichtigt den Auto-Start-Schalter.
    private func launchEpsonScan2(reason: String) {
        guard autoStartEnabled else {
            log.info("launch suppressed – auto-start disabled (\(reason, privacy: .public))")
            return
        }
        guard !epsonScan2Running else {
            log.info("launch skipped – already running (\(reason, privacy: .public))")
            return
        }
        log.info("launching Epson Scan 2: \(reason, privacy: .public)")
        let url = URL(fileURLWithPath: appPath)
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error {
                Logger(subsystem: "io.github.zuano.EpsonScanOpener", category: "Coordinator")
                    .error("openApplication failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        // We do NOT optimistically change state here – we let the launch
        // notification flip us to `.active`. Avoids races with manual launches.
        // Kein optimistischer State-Wechsel – die Launch-Notification erledigt das.
    }

    // MARK: - User actions
    // MARK: - Benutzer-Aktionen

    /// Manual "Open now" – ignores the state machine.
    /// Manuelles „Jetzt öffnen" – ignoriert die State-Machine.
    func openNow() {
        let url = URL(fileURLWithPath: appPath)
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }

    /// Force back to `armed` – useful if the state machine gets stuck.
    /// Erzwingt `armed` – falls die State-Machine mal hängt.
    func resetState() {
        watcher.resync()
        let isRunning = watcher.isRunning
        epsonScan2Running = isRunning
        if isRunning {
            transition(to: .active, reason: "manual reset; Epson Scan 2 running")
        } else {
            transition(to: .armed, reason: "manual reset")
        }
    }

    // MARK: - Login item
    // MARK: - Login-Item

    func setLoginItem(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                log.error("login item toggle failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Menu bar symbol
    // MARK: - Menüleisten-Symbol

    var menuBarSymbolName: String {
        // Always show the same scanner icon – status changes are visible in the popover.
        // Immer dasselbe Scanner-Icon – der Status wird im Popover angezeigt.
        "scanner"
    }

    // MARK: - Settings updates
    // MARK: - Einstellungs-Updates

    /// Update scanner IP/host and TCP port; restarts probing immediately.
    /// IP/Host und Port des Scanners ändern; Pings starten sofort neu.
    func updateScannerEndpoint(host: String, port: UInt16) {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty, port > 0 else { return }
        scannerHost = trimmedHost
        scannerPort = port
        UserDefaults.standard.set(trimmedHost, forKey: scannerHostKey)
        UserDefaults.standard.set(Int(port), forKey: scannerPortKey)
        pinger.reconfigure(host: trimmedHost, port: port)
        scannerOnline = false
    }

    /// Update the Epson Scan 2 path. Bundle identifier is read from the bundle itself.
    /// Aktualisiert den Pfad zu Epson Scan 2. Bundle-ID wird aus dem Bundle gelesen.
    func updateAppPath(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let url = URL(fileURLWithPath: trimmed)
        let detectedBundleID = Bundle(url: url)?.bundleIdentifier
        let detectedName = (trimmed as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        let finalBundleID = detectedBundleID ?? appBundleIdentifier

        appPath = trimmed
        appBundleIdentifier = finalBundleID
        UserDefaults.standard.set(trimmed, forKey: appPathKey)
        UserDefaults.standard.set(finalBundleID, forKey: appBundleIDKey)
        watcher.reconfigure(bundleIdentifier: finalBundleID, appName: detectedName)
        epsonScan2Running = watcher.isRunning
    }

    /// True when the currently configured app path actually exists on disk.
    /// True, wenn der aktuell konfigurierte App-Pfad tatsächlich existiert.
    var appPathExists: Bool {
        FileManager.default.fileExists(atPath: appPath)
    }

    // MARK: - Persistence
    // MARK: - Persistenz

    private func persistSettings() {
        UserDefaults.standard.set(autoStartEnabled, forKey: autoStartKey)
    }
}
