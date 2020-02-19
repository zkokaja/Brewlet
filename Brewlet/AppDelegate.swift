//
//  AppDelegate.swift
//  BrewLet
//
//  Created by zzada on 2/8/20.
//

import Cocoa
import OSLog
import UserNotifications

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var timers : [Timer] = []
    var updatesAvailable = false
    let name2tag = ["outdated":  1,
                    "update": 2,
                    "info": 3,
                    "packages": 4,
                    "analytics": 6]
    
    @IBOutlet weak var statusMenu: NSMenu!
    let statusItem : NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        // Set the icon
        statusItem.menu = statusMenu
        statusItem.button?.toolTip = "Brewlet"
        statusItem.button?.image = NSImage(named: "BrewletIcon-Black")
        statusItem.button?.image?.isTemplate = true

        // Request user access if needed
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, error in
            if error != nil {
                os_log("Notification permission error: %s", type: .error, error.debugDescription)
            }
        }
        
        // Run initial tasks to set status
        update_upgrade(sender: nil)
        update_info()
        update_analytics(sender: statusMenu.item(withTag: name2tag["analytics"]!)!)
        setupTimers()
    }
    
    func animateIcon() -> Timer {
        var frame = 0
        let animation = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { (_) in
            self.statusItem.button?.image = NSImage(named: "Brewlet-Filled-\(frame)")
            self.statusItem.button?.image?.isTemplate = true
            frame = (frame + 1) % 7
        }
        
        return animation
    }
    
    func setupTimers() {
        let hourly : TimeInterval = 60 * 60
        let daily : TimeInterval = hourly * 24
        
        // Check for updates hourly
        timers.append(Timer.scheduledTimer(withTimeInterval: hourly, repeats: true) { (Timer) in
            self.update_upgrade(sender: nil)
        })
        
        // Update info hourly
        timers.append(Timer.scheduledTimer(withTimeInterval: hourly, repeats: true) { (Timer) in
            self.update_info()
        })
        
        // Update analytics daily
        timers.append(Timer.scheduledTimer(withTimeInterval: daily, repeats: true) { (Timer) in
            self.update_analytics(sender: self.statusMenu.item(withTag: self.name2tag["analytics"]!)!)
        })        
    }
    
    @IBAction func cleanup(sender: NSMenuItem) {
        run_command(arguments: ["cleanup"], outputHandler: { (_,_) in
            os_log("Cleaned up.", type: .info)
            self.update_info()            
        })
    }
    
    @IBAction func update_upgrade(sender: NSMenuItem?) {
        let animation = animateIcon()
        let command = updatesAvailable && sender != nil ? "upgrade" : "update"
        let tmpFile = getTemporaryFile(withName: "brewlet-upgrade.log")
        
        self.run_command(arguments: [command], stdOut: tmpFile) { (_,_) in
            os_log("Ran %s command.", type: .info, command)
            
            animation.invalidate()
            self.check_outdated()
        }
    }
    
    @IBAction func toggle_analytics(sender: NSMenuItem) {
        let command = sender.title.contains("on") ? "on" : "off"
        run_command(arguments: ["analytics", command]) { (_,_) in
            self.update_analytics(sender: sender)
        }
    }
    
    func update_analytics(sender: NSMenuItem) {
        // Disable menu temporarily
        sender.isEnabled = false
        sender.title = "Updating analytics..."
        
        run_command(arguments: ["analytics", "state"],
                    outputHandler: { (Process, output: String) in
            
            if output.lowercased().contains("disabled") {
                sender.title = "Toggle analytics on"
            } else {
                sender.title = "Toggle analytics off"
            }
            
            sender.isEnabled = true
            os_log("Updated analytics.", type: .info)
        })
    }
    
    func check_outdated() {
        let statusItem = statusMenu.item(withTag: 0)!
        statusItem.title = "Checking..."
        
        run_command(arguments: ["outdated", "-v"]) { (_, output: String) in
            let packages = output.split(separator: "\n")
            let n_lines = packages.count
            let updateItem = self.statusMenu.item(withTag: self.name2tag["update"]!)!
            let statusItem = self.statusMenu.item(withTag: self.name2tag["outdated"]!)!
            let packageItem = self.statusMenu.item(withTag: self.name2tag["packages"]!)!
            packageItem.submenu?.removeAllItems()
            
            var iconName = ""
            let previousUpdatesAvailable = self.updatesAvailable
            self.updatesAvailable = n_lines > 0
            if self.updatesAvailable {
                statusItem.title = "\(n_lines) Outdated Packages"
                iconName = "BrewletIcon-Color"
                updateItem.title = "Upgrade"
                packageItem.isHidden = false
                self.updatesAvailable = true
                self.fillPackageMenu(packageMenu: packageItem.submenu!, packages: packages)
                // Only notify end-user when transitioning from having no updates to updates
                if !previousUpdatesAvailable {
                    self.sendNotification(title: "Updates Available",
                                          body: "Some packages can be upgraded.")
                }
            } else {
                statusItem.title = "Packages are up-to-date"
                iconName = "BrewletIcon-Black"
                self.updatesAvailable = false
                updateItem.title = "Update"
                packageItem.isHidden = true
            }

            // Update icon in main thread
            DispatchQueue.main.async {
                self.statusItem.button?.image = NSImage(named: iconName)
                self.statusItem.button?.image?.isTemplate = true
            }
            
            os_log("Checked outdated status.", type: .info)
        }
    }
    
    func fillPackageMenu(packageMenu : NSMenu, packages: [String.SubSequence]) {
        for package in packages {
            let item = NSMenuItem.init(title: String(package),
                                       action: #selector(AppDelegate.upgradePackage),
                                       keyEquivalent: "")
            packageMenu.addItem(item)
        }
    }
    
    @objc func upgradePackage(_ sender: NSMenuItem) {
        let animation = self.animateIcon()
        let packageName = String(sender.title.split(separator: " ")[0])
        let tmpFile = self.getTemporaryFile(withName: "brewlet-package-upgrade.log")
        
        run_command(arguments: ["upgrade", packageName], stdOut: tmpFile) { (_,_) in
            os_log("Upgraded package: %s.", type: .info, packageName)
            
            animation.invalidate()
            sender.menu?.removeItem(sender)
            
            // Update statuses
            let statusItem = self.statusMenu.item(withTag: self.name2tag["outdated"]!)!
            if let n_packages = Int(statusItem.title.split(separator: " ")[0]) {
                if n_packages > 1 {
                    statusItem.title = "\(n_packages - 1) Outdated Packages"
                    DispatchQueue.main.async {
                        self.statusItem.button?.image = NSImage(named: "BrewletIcon-Color")
                        self.statusItem.button?.image?.isTemplate = true
                    }
                } else {
                    self.check_outdated()
                }
            }
        }
    }
    
    func update_info() {
        run_command(arguments: ["info"]) { (_, info: String) in
            let statusItem = self.statusMenu.item(withTag: self.name2tag["info"]!)!
            statusItem.title = info
            os_log("Updated info.", type: .info)
        }
    }
    
    @IBAction func export_list(sender: NSMenuItem) {
        run_command(arguments: ["list", "-1"]) { (_, output: String) in
            let paths = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            let filename = paths.appendingPathComponent("brew-packages.txt")

            do {
                try output.write(to: filename, atomically: true, encoding: String.Encoding.utf8)
                os_log("Saved file in downloads folder.", type: .info)
            } catch {
                os_log("Unexpected error: %s", type: .error, error.localizedDescription)
                self.sendNotification(title: "Unexpected Error",
                                      body: "An unexpected error occurred. See log for details.")
            }
        }
    }
    
    func run_command(arguments: [String],
                     stdOut: Any? = Pipe(),
                     outputHandler: @escaping (Process,String) -> Void) {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["/usr/local/Homebrew/bin/brew"] + arguments
        task.standardOutput = stdOut
        task.terminationHandler = { (process: Process) in
            var output = ""
            
            if let stdout = process.standardOutput as? Pipe {
                let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
                output = String(decoding: outputData, as: UTF8.self)
            }
            else if let stdout = process.standardOutput as? FileHandle {
                stdout.closeFile()
            }
            else {
                os_log("Standard out type is unknown.", type: .error)
            }
            
            // Handle the output of the command
            outputHandler(process, output)
        }
        
        // Run it asynch
        do {
            try task.run()
        }
        catch {
            os_log("Unexpected error: %s", type: .error, "\(error)")
            self.sendNotification(title: "Unexpected Error",
                                  body: "An unexpected error occurred. See log for details.")
        }
    }
    
    func sendNotification(title: String, body: String, timeInterval: TimeInterval = 1) {
        
        // Create the notification content
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        
        // Set up the time trigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval,
                                                        repeats: false)
        
        // Create the request
        let uuidString = UUID().uuidString
        let request = UNNotificationRequest(identifier: uuidString,
                                            content: content,
                                            trigger: trigger)

        // Schedule the request with the system
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.add(request) { error in
           if error != nil {
            os_log("Notification request error: %s", type: .error, error.debugDescription)
           }
        }
    }
    
    func getTemporaryFile(withName: String) -> FileHandle? {
        let paths = FileManager.default.temporaryDirectory
        let fileName = paths.appendingPathComponent(withName)
        let success = FileManager.default.createFile(atPath: fileName.path, contents: nil, attributes: nil)
        
        if success {
            os_log("Opened: %s", type: .info, fileName.path)
            return FileHandle.init(forWritingAtPath: fileName.path)
        }
        else {
            os_log("Unable to create file: %s", type: .error, "\(fileName.path)")
            return nil
        }
    }
    
    // Quit any running process and application
    @IBAction func quitClicked(sender: NSMenuItem) {
        let notificationName = Notification.Name.init("Quit Clicked")
        let notification = Notification.init(name: notificationName)
        self.applicationWillTerminate(notification)
        
        NSApplication.shared.terminate(self)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        os_log("Tearing down timers.", type: .info)
        for timer in timers {
            if timer.isValid {
                timer.invalidate()
            }
        }
    }

}
