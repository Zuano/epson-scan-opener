# Epson Scan Opener

macOS menu bar app that automatically opens **Epson Scan 2** as soon as a network scanner is switched on.

It checks once per second whether the scanner answers on its IP address (TCP port 80). When the scanner comes online, Epson Scan 2 is launched. A small state machine makes sure it only re-launches after the scanner has been switched off and on again. Works well together with [Quitter](https://github.com/Zuano/quitter), which closes Epson Scan 2 after a period of inactivity.

## Recommended setting for Epson Scan 2
Set the timeout for Epson Scan 2 **shorter than your scanner's standby time** (e.g. 12 minutes if the scanner goes to standby after ~13 minutes). If the scanner falls asleep first, Epson Scan 2 shows an error dialog and ignores the quit request, so it stays open.

## Build
1. Open `EpsonScanOpener.xcodeproj` in Xcode (macOS 13+).
2. Create `Signing.local.xcconfig` next to the project with `DEVELOPMENT_TEAM = <your Team ID>` (or pick your team in Xcode).
3. Build & run. Set the scanner IP and the path to Epson Scan 2 in the app's settings.

## License
MIT
