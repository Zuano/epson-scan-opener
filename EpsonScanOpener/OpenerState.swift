//
//  OpenerState.swift
//  EpsonScanOpener
//
//  The four states of the auto-open lifecycle.
//  Die vier Zustände des Auto-Open-Lebenszyklus.
//

import Foundation

enum OpenerState: String {
    /// Ready to start Epson Scan 2 as soon as the scanner appears online.
    /// Bereit – startet Epson Scan 2, sobald der Scanner online ist.
    case armed

    /// Epson Scan 2 is running. Doing nothing, waiting for Quitter to close it.
    /// Epson Scan 2 läuft. Nichts tun, warten bis Quitter beendet.
    case active

    /// Quitter has closed Epson Scan 2. Waiting for the scanner to power down.
    /// Quitter hat Epson Scan 2 beendet. Warten, bis Scanner offline geht.
    case waitingForScannerOffline

    /// Scanner is off. Waiting for the user to press the power button again.
    /// Scanner ist aus. Warten, bis der User wieder einschaltet.
    case waitingForPowerOn

    /// Human-readable German label for the UI.
    /// Lesbare deutsche Beschriftung für die UI.
    var germanDescription: String {
        switch self {
        case .armed:                    return "Bereit"
        case .active:                   return "Epson Scan 2 läuft"
        case .waitingForScannerOffline: return "Warte bis Scanner aus"
        case .waitingForPowerOn:        return "Warte auf Einschalten"
        }
    }

    var emoji: String {
        switch self {
        case .armed:                    return "🟢"
        case .active:                   return "🔵"
        case .waitingForScannerOffline: return "⏳"
        case .waitingForPowerOn:        return "🟡"
        }
    }
}
