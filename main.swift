import AppKit

final class Launcher: NSObject, NSApplicationDelegate {
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 140),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
    let status = NSTextField(labelWithString: "")
    let sniButton = NSButton(title: "Start SNI", target: nil, action: nil)
    let snfmButton = NSButton(title: "Open File Manager", target: nil, action: nil)
    var busy = false

    let sniApp = Bundle.main.url(forResource: "SNI", withExtension: "app")!
    let snfmApp = Bundle.main.url(forResource: "SNFM", withExtension: "app")!

    func applicationDidFinishLaunching(_ notification: Notification) {
        sniButton.target = self
        sniButton.action = #selector(sniClicked)
        snfmButton.target = self
        snfmButton.action = #selector(snfmClicked)
        for button in [sniButton, snfmButton] {
            button.bezelStyle = .rounded
            button.controlSize = .large
            button.widthAnchor.constraint(equalToConstant: 200).isActive = true
        }

        let stack = NSStackView(views: [status, sniButton, snfmButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        window.contentView = stack
        window.title = "SNI Launcher"
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        refresh()
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in self?.refresh() }

        if let path = ProcessInfo.processInfo.environment["SNI_LAUNCHER_SNAPSHOT"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.snapshot(to: path) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    @objc func sniClicked() {
        work(sniPIDs().isEmpty ? "Starting SNI…" : "Restarting SNI…") {
            self.stopSNI()
            self.startSNI()
        }
    }

    @objc func snfmClicked() {
        work("Starting SNI…") {
            if self.sniPIDs().isEmpty {
                self.startSNI()
            }
            // Opening an app that is already running just brings it to the front
            DispatchQueue.main.sync {
                NSWorkspace.shared.openApplication(at: self.snfmApp, configuration: NSWorkspace.OpenConfiguration())
            }
        }
    }

    func refresh() {
        if busy {
            return
        }
        if sniPIDs().isEmpty {
            status.stringValue = "SNI is not running"
            sniButton.title = "Start SNI"
        } else {
            status.stringValue = sniListening() ? "SNI is running" : "SNI is starting…"
            sniButton.title = "Restart SNI"
        }
    }

    func work(_ message: String, _ body: @escaping () -> Void) {
        busy = true
        status.stringValue = message
        sniButton.isEnabled = false
        snfmButton.isEnabled = false
        DispatchQueue.global().async {
            body()
            DispatchQueue.main.async {
                self.busy = false
                self.sniButton.isEnabled = true
                self.snfmButton.isEnabled = true
                self.refresh()
            }
        }
    }

    func startSNI() {
        DispatchQueue.main.sync {
            NSWorkspace.shared.openApplication(at: self.sniApp, configuration: NSWorkspace.OpenConfiguration())
        }
        waitUntil(10) { self.sniListening() }
    }

    // Stops every SNI, including ones not started from here, since they would all fight over the same ports
    func stopSNI() {
        for pid in sniPIDs() {
            kill(pid, SIGTERM)
        }
        waitUntil(5) { self.sniPIDs().isEmpty }
        for pid in sniPIDs() {
            kill(pid, SIGKILL)
        }
        waitUntil(2) { self.sniPIDs().isEmpty }
    }

    func sniPIDs() -> [pid_t] {
        run("/usr/bin/pgrep", ["-x", "sni"]).split(separator: "\n").compactMap { pid_t($0) }
    }

    func sniListening() -> Bool {
        !run("/usr/sbin/lsof", ["-nP", "-iTCP:8191", "-sTCP:LISTEN", "-t"]).isEmpty
    }

    func waitUntil(_ seconds: Double, _ done: () -> Bool) {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end && !done() {
            Thread.sleep(forTimeInterval: 0.2)
        }
    }

    func run(_ path: String, _ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    func snapshot(to path: String) {
        guard let view = window.contentView?.superview,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            return
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = Launcher()
app.delegate = delegate
app.setActivationPolicy(.regular)

let mainMenu = NSMenu()
let appMenuItem = NSMenuItem()
mainMenu.addItem(appMenuItem)
let appMenu = NSMenu()
appMenu.addItem(withTitle: "Quit SNI Launcher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
appMenuItem.submenu = appMenu
app.mainMenu = mainMenu

app.run()
