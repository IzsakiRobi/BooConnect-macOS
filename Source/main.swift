import Cocoa
import Foundation
import UserNotifications

let CONFIG_PATH = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".vpn_config.json")
let RESOURCES_PATH = Bundle.main.resourcePath ?? FileManager.default.currentDirectoryPath
let VPNC_SCRIPT = "\(RESOURCES_PATH)/vpnc-script"
let OPENCONNECT_BIN = "\(RESOURCES_PATH)/bin/openconnect"
let LOG_FILE_PATH = "/tmp/vpn_debug.log"

let ICON_LOCK_PATH = "\(RESOURCES_PATH)/icon_lock.png"
let ICON_WAIT_PATH = "\(RESOURCES_PATH)/icon_wait.png"
let ICON_SHIELD_PATH = "\(RESOURCES_PATH)/icon_shield.png"
let ICON_APP_PATH = "\(RESOURCES_PATH)/AppIcon.icns"
let DIALOG_ICON_APP_PATH = "\(RESOURCES_PATH)/Dialog.icns"
let SOUND_PATH = "\(RESOURCES_PATH)/Alert.caf"

struct VpnConfig: Codable {
    var host: String = ""; var user: String = ""; var pin: String = ""; var sudo: String = ""
}


class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var config: VpnConfig
    var inputs: [NSTextField] = []
    var onSave: ((VpnConfig) -> Void)?

    init(config: VpnConfig) {
        self.config = config
        let sw = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 350, height: 280), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        sw.titlebarAppearsTransparent = true; sw.titleVisibility = .hidden; sw.center(); sw.isReleasedWhenClosed = false
        
        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 350, height: 280))
        effect.material = .popover; effect.state = .active
        sw.contentView = effect
        super.init(window: sw)
        sw.delegate = self

        let title = NSTextField(labelWithString: "Settings")
        title.font = .boldSystemFont(ofSize: 16); title.alignment = .center
        title.frame = NSRect(x: 0, y: 240, width: 350, height: 20)
        effect.addSubview(title)

        let fields: [(String, Bool, WritableKeyPath<VpnConfig, String>)] = [("Host:", false, \.host), ("User:", false, \.user), ("PIN:", true, \.pin), ("Mac Pass:", true, \.sudo)]
        for (i, item) in fields.enumerated() {
            let y = 190 - (i * 35)
            let lbl = NSTextField(labelWithString: item.0); lbl.alignment = .right
            lbl.frame = NSRect(x: 20, y: y, width: 80, height: 20)
            let txt = item.1 ? NSSecureTextField() : NSTextField()
            txt.frame = NSRect(x: 110, y: y, width: 200, height: 22); txt.stringValue = config[keyPath: item.2]
            effect.addSubview(lbl); effect.addSubview(txt); inputs.append(txt)
        }

        let saveBtn = NSButton(title: "Save", target: self, action: #selector(saveClicked))
        saveBtn.frame = NSRect(x: 180, y: 20, width: 100, height: 32); saveBtn.keyEquivalent = "\r"
        if #available(macOS 11.0, *) { saveBtn.bezelColor = .systemBlue; saveBtn.controlSize = .large }

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancelClicked))
        cancelBtn.frame = NSRect(x: 70, y: 20, width: 100, height: 32)
        if #available(macOS 11.0, *) { cancelBtn.controlSize = .large }

        effect.addSubview(saveBtn); effect.addSubview(cancelBtn)
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc func saveClicked() {
        config.host = inputs[0].stringValue; config.user = inputs[1].stringValue
        config.pin = inputs[2].stringValue; config.sudo = inputs[3].stringValue
        onSave?(config)
        window?.close(); NSApp.stopModal(withCode: .OK)
    }
    @objc func cancelClicked() { window?.close(); NSApp.stopModal(withCode: .cancel) }
    func windowWillClose(_ notification: Notification) { if NSApp.modalWindow == self.window { NSApp.stopModal(withCode: .cancel) } }
}

class SMSWindowController: NSWindowController, NSWindowDelegate {
    var input: NSTextField!; var code: String = ""

    init() {

        let sw = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 230), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        sw.titlebarAppearsTransparent = true; sw.titleVisibility = .hidden; sw.center(); sw.isReleasedWhenClosed = false
        
        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 300, height: 230))
        effect.material = .popover; effect.state = .active
        sw.contentView = effect
        super.init(window: sw)
        sw.delegate = self


        let icon = NSImageView(frame: NSRect(x: 118, y: 140, width: 64, height: 64))
        if #available(macOS 11.0, *) {
            let symbolConfig = NSImage.SymbolConfiguration(pointSize: 64, weight: .regular)
            if let keyImage = NSImage(systemSymbolName: "key.viewfinder", accessibilityDescription: "Authentication") {
                icon.image = keyImage.withSymbolConfiguration(symbolConfig)
                icon.contentTintColor = .secondaryLabelColor 
            }
        } else {
            icon.image = NSImage(named: NSImage.lockLockedTemplateName)
        }
        effect.addSubview(icon)


        let desc = NSTextField(labelWithString: "Enter Token Code:")
        desc.font = .systemFont(ofSize: 13); desc.alignment = .center
        desc.frame = NSRect(x: 0, y: 105, width: 300, height: 20)
        effect.addSubview(desc)


        input = NSTextField(frame: NSRect(x: 50, y: 65, width: 200, height: 24))
        if #available(macOS 11.0, *) { input.contentType = .oneTimeCode }
        input.alignment = .center
        effect.addSubview(input)


        let verifyBtn = NSButton(title: "Verify", target: self, action: #selector(verifyClicked))
        verifyBtn.frame = NSRect(x: 155, y: 20, width: 95, height: 32); verifyBtn.keyEquivalent = "\r"
        if #available(macOS 11.0, *) { verifyBtn.bezelColor = .systemBlue; verifyBtn.controlSize = .large }

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancelClicked))
        cancelBtn.frame = NSRect(x: 50, y: 20, width: 95, height: 32)
        if #available(macOS 11.0, *) { cancelBtn.controlSize = .large }

        effect.addSubview(verifyBtn); effect.addSubview(cancelBtn)
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc func verifyClicked() { code = input.stringValue; window?.close(); NSApp.stopModal(withCode: .OK) }
    @objc func cancelClicked() { code = ""; window?.close(); NSApp.stopModal(withCode: .cancel) }
    func windowWillClose(_ notification: Notification) { if NSApp.modalWindow == self.window { NSApp.stopModal(withCode: .cancel) } }
}


class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem!
    var process: Process?
    var outputPipe: Pipe?
    var inputPipe: Pipe?
    var config = VpnConfig()
    var isConnected = false
    var isWaitingForSMS = false
    var isPinMechanismArmed = false
    var hasSentPin = false
    
    var imgLock: NSImage?; var imgWait: NSImage?; var imgShield: NSImage?
    

    var mainWindow: NSWindow!
    var lblStatus: NSTextField!
    var btnAction: NSButton!
    var imgAppIcon: NSImageView!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        try? FileManager.default.removeItem(atPath: LOG_FILE_PATH)
        NSApp.setActivationPolicy(.accessory) 
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        
        imgLock = loadTemplateImage(path: ICON_LOCK_PATH)
        imgWait = loadTemplateImage(path: ICON_WAIT_PATH)
        imgShield = loadTemplateImage(path: ICON_SHIELD_PATH)
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button { 
            button.image = imgLock
            button.action = #selector(toggleMainWindow(_:)) 
            button.target = self
        }
        
        setupMainWindow()
        loadConfig()
        setUI(state: 0)
        
        if config.host.isEmpty || config.user.isEmpty { openSettings() }
    }
    
    func setupMainWindow() {
        let width: CGFloat = 300; let height: CGFloat = 350
        mainWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
        mainWindow.titlebarAppearsTransparent = true
        mainWindow.titleVisibility = .hidden
        mainWindow.isMovableByWindowBackground = true
        mainWindow.center()
        mainWindow.isReleasedWhenClosed = false

        let effectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        effectView.material = .popover
        effectView.state = .active
        mainWindow.contentView = effectView

        let topTitle = NSTextField(labelWithString: "BooConnect")
        topTitle.font = .boldSystemFont(ofSize: 13); topTitle.alignment = .center
        topTitle.frame = NSRect(x: 0, y: height - 30, width: width, height: 20)
        effectView.addSubview(topTitle)

        let gearBtn = NSButton(frame: NSRect(x: width - 40, y: height - 34, width: 30, height: 30))
        gearBtn.bezelStyle = .regularSquare; gearBtn.isBordered = false
        if #available(macOS 11.0, *) {
            let symbolConfig = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
            if let gearImage = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings") {
                gearBtn.image = gearImage.withSymbolConfiguration(symbolConfig)
                gearBtn.contentTintColor = .secondaryLabelColor
            }
        } else {
            gearBtn.image = NSImage(named: NSImage.preferencesGeneralName)
        }
        gearBtn.target = self; gearBtn.action = #selector(showSettingsMenu(_:))
        effectView.addSubview(gearBtn)

        imgAppIcon = NSImageView(frame: NSRect(x: (width - 120) / 2, y: 160, width: 120, height: 120))
        imgAppIcon.image = NSImage(contentsOfFile: DIALOG_ICON_APP_PATH)
        effectView.addSubview(imgAppIcon)

        let mainTitle = NSTextField(labelWithString: "BooConnect")
        mainTitle.font = .boldSystemFont(ofSize: 24); mainTitle.alignment = .center
        mainTitle.frame = NSRect(x: 0, y: 110, width: width, height: 30)
        effectView.addSubview(mainTitle)

        lblStatus = NSTextField(labelWithString: "Ready to connect")
        lblStatus.font = .systemFont(ofSize: 13); lblStatus.alignment = .center
        lblStatus.textColor = .secondaryLabelColor
        lblStatus.frame = NSRect(x: 0, y: 80, width: width, height: 20)
        effectView.addSubview(lblStatus)

        btnAction = NSButton(frame: NSRect(x: (width - 160) / 2, y: 25, width: 160, height: 40))
        btnAction.title = "Connect"
        btnAction.target = self; btnAction.action = #selector(onActionClicked)
        btnAction.bezelStyle = .push
        if #available(macOS 11.0, *) { btnAction.controlSize = .large; btnAction.bezelColor = .systemBlue }
        effectView.addSubview(btnAction)
    }

    @objc func toggleMainWindow(_ sender: Any?) {
        if mainWindow.isVisible {
            mainWindow.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            mainWindow.makeKeyAndOrderFront(nil)
        }
    }

    @objc func showSettingsMenu(_ sender: NSButton) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit BooConnect", action: #selector(quitApp), keyEquivalent: "q"))
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }

    func setUI(state: Int) {
        DispatchQueue.main.async {
            switch state {
            case 0:
                self.statusItem.button?.image = self.imgLock
                self.lblStatus.stringValue = "Ready to connect"
                self.btnAction.title = "Connect"
                if #available(macOS 11.0, *) { self.btnAction.bezelColor = .systemBlue }
            case 1:
                self.statusItem.button?.image = self.imgWait
                self.lblStatus.stringValue = "Connecting..."
                self.btnAction.title = "Cancel"
                if #available(macOS 11.0, *) { self.btnAction.bezelColor = .systemGray }
            case 2:
                self.statusItem.button?.image = self.imgShield
                self.lblStatus.stringValue = "VPN Active"
                self.btnAction.title = "Disconnect"
                if #available(macOS 11.0, *) { self.btnAction.bezelColor = .systemRed }
            default: break
            }
        }
    }

    @objc func onActionClicked() {
        if isConnected || process != nil { disconnect() } else { connect() }
    }

    @objc func connect() {
        if config.sudo.isEmpty || config.user.isEmpty || config.host.isEmpty { openSettings(); return }
        isConnected = false; isWaitingForSMS = false; isPinMechanismArmed = false
        hasSentPin = false
        setUI(state: 1)
        
        let resetTask = Process()
        resetTask.launchPath = "/usr/bin/sudo"; resetTask.arguments = ["-k"]; resetTask.launch(); resetTask.waitUntilExit()
        
        process = Process()
        process?.launchPath = "/usr/bin/sudo"
        var arguments = ["-S", OPENCONNECT_BIN, "--server=\(config.host)", "--user=\(config.user)", "--protocol=anyconnect", "--useragent=AnyConnect"]
        if FileManager.default.isExecutableFile(atPath: VPNC_SCRIPT) {
            arguments.append("--script=\(VPNC_SCRIPT)")
        }
        process?.arguments = arguments
        
        process?.terminationHandler = { _ in
            DispatchQueue.main.async {
                if self.isConnected {
                    self.isConnected = false
                    self.setUI(state: 0)
                    self.sendNotification(title: "VPN", text: "Connection lost.")
                    self.playAlert()
                } else {
                    self.setUI(state: 0)
                }
            }
        }
        
        inputPipe = Pipe(); outputPipe = Pipe()
        process?.standardInput = inputPipe; process?.standardOutput = outputPipe; process?.standardError = outputPipe
        if let sudoData = (config.sudo + "\n").data(using: .utf8) { inputPipe?.fileHandleForWriting.write(sudoData) }
        outputPipe!.fileHandleForReading.readabilityHandler = { pipe in
            let data = pipe.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) { self.handleOutput(str) }
        }
        do { try process?.run() } catch { disconnect() }
    }
    
    func handleOutput(_ text: String) {
        let lower = text.lowercased()
        log("RAW: \(text.trimmingCharacters(in: .whitespacesAndNewlines))")
        if lower.contains("enter 'yes' to accept") || lower.contains("verify failed") { writeToProcess("yes\n"); return }
        if lower.contains("please enter your username and password") { isPinMechanismArmed = true }
        

        if (lower.contains("password:") || lower.contains("pin:")) && isPinMechanismArmed && !hasSentPin {
            log("Injecting PIN securely...")
            writeToProcess(config.pin + "\n")
            isPinMechanismArmed = false
            hasSentPin = true
        }
        
        if lower.contains("response:") && !lower.contains("got connect") {
            if !isWaitingForSMS {
                isWaitingForSMS = true
                DispatchQueue.main.async {
                    let code = self.askSMS()
                    self.isWaitingForSMS = false
                    if code.isEmpty { self.disconnect() }
                    else { self.writeToProcess(code + "\n") }
                }
            }
        }
        if (lower.contains("cstp connected") || lower.contains("got connect response")) && !isConnected {
            isConnected = true
            isPinMechanismArmed = false
            DispatchQueue.main.async {
                self.setUI(state: 2)
                self.sendNotification(title: "VPN", text: "Connected successfully.")
                self.playAlert()
            }
        }
    }
    
    func writeToProcess(_ text: String) { if let data = text.data(using: .utf8) { inputPipe?.fileHandleForWriting.write(data) } }
    
    @objc func disconnect() {
        if !isConnected && process == nil { return }
        isConnected = false
        process?.terminate()
        let killTask = Process(); killTask.launchPath = "/bin/sh"
        killTask.arguments = ["-c", "echo \(config.sudo) | sudo -S pkill openconnect"]
        killTask.launch(); process = nil; isWaitingForSMS = false; isPinMechanismArmed = false
        hasSentPin = false
        DispatchQueue.main.async {
            self.setUI(state: 0)
            self.sendNotification(title: "VPN", text: "Disconnected.")
            self.playAlert()
        }
    }
    
    @objc func quitApp() { disconnect(); NSApp.terminate(nil) }
    
    func askSMS() -> String {
        let smsController = SMSWindowController()
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
                if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) { return nil }
            }
            return event
        }
        NSApp.activate(ignoringOtherApps: true)
        smsController.window?.makeKeyAndOrderFront(nil)
        smsController.window?.makeFirstResponder(smsController.input)
        let response = NSApp.runModal(for: smsController.window!)
        if let m = monitor { NSEvent.removeMonitor(m as Any) }
        return response == .OK ? smsController.code : ""
    }

    @objc func openSettings() {
        let settingsController = SettingsWindowController(config: self.config)
        settingsController.onSave = { newConfig in
            self.config = newConfig
            self.saveConfig()
        }
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
                if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) { return nil }
            }
            return event
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsController.window?.makeKeyAndOrderFront(nil)
        NSApp.runModal(for: settingsController.window!)
        if let m = monitor { NSEvent.removeMonitor(m as Any) }
    }
    
    func log(_ text: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logLine = "[\(timestamp)] \(text)\n"
        if let handle = FileHandle(forWritingAtPath: LOG_FILE_PATH) {
            handle.seekToEndOfFile(); try? handle.write(contentsOf: logLine.data(using: .utf8) ?? Data()); handle.closeFile()
        } else { try? logLine.write(toFile: LOG_FILE_PATH, atomically: true, encoding: .utf8) }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
    func loadTemplateImage(path: String) -> NSImage? {
        if let img = NSImage(contentsOfFile: path) {
            img.isTemplate = true; img.size = NSSize(width: 18, height: 18); return img
        }
        return nil
    }
    func loadConfig() { if let data = try? Data(contentsOf: CONFIG_PATH), let loaded = try? JSONDecoder().decode(VpnConfig.self, from: data) { config = loaded } }
    func saveConfig() { if let data = try? JSONEncoder().encode(config) { try? data.write(to: CONFIG_PATH); playAlert() } }
    func playAlert() { if FileManager.default.fileExists(atPath: SOUND_PATH) { Process.launchedProcess(launchPath: "/usr/bin/afplay", arguments: [SOUND_PATH]) } }
    func sendNotification(title: String, text: String) {
        let content = UNMutableNotificationContent()
        content.title = title; content.body = text
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

let app = NSApplication.shared; let delegate = AppDelegate(); app.delegate = delegate; app.run()
