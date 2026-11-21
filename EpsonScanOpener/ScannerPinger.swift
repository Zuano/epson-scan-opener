//
//  ScannerPinger.swift
//  EpsonScanOpener
//
//  Polls the scanner via a fast TCP connect attempt.
//  Reports `isOnline` after a small debounce so a single dropped packet
//  doesn't flip the state.
//
//  Prüft den Scanner per schnellem TCP-Verbindungsversuch.
//  Liefert `isOnline` mit kleiner Entprellung, damit ein einzelner
//  verlorener Paket-Ping nicht sofort den Zustand umkippt.
//

import Foundation
import Network
import Observation

@Observable
final class ScannerPinger {
    /// Current consolidated state (after debounce).
    /// Aktueller, entprellter Status.
    private(set) var isOnline: Bool = false

    /// Timestamp of the last successful probe.
    /// Zeitpunkt der letzten erfolgreichen Prüfung.
    private(set) var lastSuccess: Date?

    @ObservationIgnored private var host: String
    @ObservationIgnored private var port: NWEndpoint.Port
    @ObservationIgnored private let probeInterval: TimeInterval
    @ObservationIgnored private let probeTimeout: TimeInterval
    @ObservationIgnored private let requiredConsecutiveOffline: Int

    @ObservationIgnored private var consecutiveOfflineCount: Int = 0
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var inFlight: NWConnection?

    /// Callback when the consolidated `isOnline` value changes.
    /// Callback bei Änderung von `isOnline`.
    var onStateChange: ((Bool) -> Void)?

    init(
        host: String = "192.168.1.25",
        port: UInt16 = 80,
        probeInterval: TimeInterval = 1,
        probeTimeout: TimeInterval = 2,
        requiredConsecutiveOffline: Int = 2
    ) {
        self.host = host
        self.port = NWEndpoint.Port(rawValue: port)!
        self.probeInterval = probeInterval
        self.probeTimeout = probeTimeout
        self.requiredConsecutiveOffline = requiredConsecutiveOffline
    }

    func start() {
        stop()
        probe()
        timer = Timer.scheduledTimer(withTimeInterval: probeInterval, repeats: true) { [weak self] _ in
            self?.probe()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        inFlight?.cancel()
        inFlight = nil
    }

    /// Update host and port and restart probing.
    /// Hostname und Port ändern und neu starten.
    func reconfigure(host: String, port: UInt16) {
        let wasRunning = timer != nil
        stop()
        self.host = host
        self.port = NWEndpoint.Port(rawValue: port) ?? self.port
        // Reset state so user immediately sees the new probe result
        consecutiveOfflineCount = 0
        isOnline = false
        lastSuccess = nil
        if wasRunning {
            start()
        }
    }

    /// Fires a one-off TCP connect attempt with a hard timeout.
    /// Startet einen einzelnen TCP-Verbindungsversuch mit hartem Timeout.
    private func probe() {
        // Cancel any previous probe still in flight
        inFlight?.cancel()

        let conn = NWConnection(
            host: NWEndpoint.Host(host),
            port: port,
            using: .tcp
        )
        inFlight = conn

        var didFinish = false
        let finish: (Bool) -> Void = { [weak self] success in
            guard let self else { return }
            if didFinish { return }
            didFinish = true
            conn.cancel()
            if self.inFlight === conn { self.inFlight = nil }
            DispatchQueue.main.async {
                self.handleProbeResult(success: success)
            }
        }

        conn.stateUpdateHandler = { state in
            switch state {
            case .ready:
                finish(true)
            case .failed, .cancelled:
                finish(false)
            default:
                break
            }
        }
        conn.start(queue: .global(qos: .utility))

        // Hard timeout
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + probeTimeout) {
            finish(false)
        }
    }

    private func handleProbeResult(success: Bool) {
        if success {
            consecutiveOfflineCount = 0
            lastSuccess = Date()
            if !isOnline {
                isOnline = true
                onStateChange?(true)
            }
        } else {
            consecutiveOfflineCount += 1
            if isOnline, consecutiveOfflineCount >= requiredConsecutiveOffline {
                isOnline = false
                onStateChange?(false)
            }
        }
    }
}
