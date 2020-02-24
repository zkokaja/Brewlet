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
class AppDelegate: NSObject, NSApplicationDelegate, PreferencesDelegate {

    var timer: Timer?
    var packages: [Package] = []
    let name2tag = ["outdated":  1,
                    "update": 2,
                    "info": 3,
                    "packages": 4,
                    "analytics": 6]
    
    @IBOutlet weak var statusMenu: NSMenu!
    let userDefaults = UserDefaults.standard
    let statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    var preferencesWindow: PreferencesController!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        // Set the icon
        statusItem.menu = statusMenu
        statusItem.button?.toolTip = "Brewlet"
        statusItem.button?.image = NSImage(named: "BrewletIcon-Black")

        // Set up preferences window
        preferencesWindow = PreferencesController()
        preferencesWindow.delegate = self
        
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
    
    func setupTimers() {
        // Cancel the existing timer
        timer?.invalidate()
        timer = nil
        
        // Determine how often to run the jobs (if at all)
        var period = userDefaults.double(forKey: "updateInterval")
        if period == -1 {
            return
        }
        else if period == 0 {
            period = TimeInterval(3600)
            userDefaults.set(period, forKey: "updateInterval")
        }
        
        // Start a new timer
        timer = Timer.scheduledTimer(withTimeInterval: period, repeats: true) { _ in
            self.update_upgrade(sender: nil)
            self.update_info()
            self.update_analytics(sender: self.statusMenu.item(withTag: self.name2tag["analytics"]!)!)
        }
        
        os_log("Scheduled a timer with a period of %f seconds", type: .info, period)
    }
    
    // MARK: - Actions
    
    @IBAction func cleanup(sender: NSMenuItem) {
        run_command(arguments: ["cleanup"], outputHandler: { (_,_) in
            os_log("Cleaned up.", type: .info)
            self.update_info()            
        })
    }
    
    @IBAction func update_upgrade(sender: NSMenuItem?) {
        let animation = animateIcon()
        let isOutdated = self.packages.filter{$0.outdated && $0.installed_on_request}.count > 0
        let command = isOutdated && sender != nil ? "upgrade" : "update"
        let tmpFile = getTemporaryFile(withName: "brewlet-upgrade.log")
        
        self.run_command(arguments: [command], fileRedirect: tmpFile) { _,_ in
            os_log("Ran %s command.", type: .info, command)
            
            animation.invalidate()
            self.check_outdated()
        }
        
        let dateStr = formatDate()
        statusItem.button?.toolTip = "Brewlet. Last updated \(dateStr)"
    }
    
    @IBAction func toggle_analytics(sender: NSMenuItem) {
        let command = sender.title.contains("on") ? "on" : "off"
        run_command(arguments: ["analytics", command]) { (_,_) in
            self.update_analytics(sender: sender)
        }
    }
    
    @IBAction func export_list(sender: NSMenuItem) {
        run_command(arguments: ["list", "-1"]) { (_, data: Data) in
            let paths = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            let filename = paths.appendingPathComponent("brew-packages.txt")

            do {
                let output = String(decoding: data, as: UTF8.self)
                try output.write(to: filename, atomically: true, encoding: String.Encoding.utf8)
                os_log("Saved file in downloads folder.", type: .info)
            } catch {
                os_log("Unexpected error: %s", type: .error, error.localizedDescription)
                self.sendNotification(title: "Unexpected Error",
                                      body: "An unexpected error occurred. See log for details.")
            }
        }
    }
    
    func update_analytics(sender: NSMenuItem) {
        // Disable menu temporarily
        sender.isEnabled = false
        sender.title = "Updating analytics..."
        
        run_command(arguments: ["analytics", "state"]) { (_, data: Data) in
            let output = String(decoding: data, as: UTF8.self)
            if output.lowercased().contains("disabled") {
                sender.title = "Toggle analytics on"
            } else {
                sender.title = "Toggle analytics off"
            }
            
            sender.isEnabled = true
            os_log("Updated analytics.", type: .info)
        }
    }
    
    func check_outdated() {
        let statusItem = statusMenu.item(withTag: 0)!
        statusItem.title = "Checking..."
        
        run_command(arguments: ["info", "--json", "--installed"]) { (_, data: Data) in
            
            // Determine which packages to include
            let includeDependencies = self.userDefaults.bool(forKey: "includeDependencies")
            let criterion: (Package) -> Bool = includeDependencies
                ? { $0.outdated }
                : { $0.outdated && $0.installed_on_request }
            
            
            let previousOutdatedPackageCount = self.packages.filter(criterion).count
            
            do {
                self.packages = try packagesFromJson(jsonData: data)
            } catch {
                os_log("Unexpected error: %s", type: .error, "\(error)")
                self.sendNotification(title: "Unexpected Error",
                                      body: "An unexpected error occurred. See log for details.")
                return
            }
            
            var iconName = ""
            let updateItem = self.statusMenu.item(withTag: self.name2tag["update"]!)!
            let statusItem = self.statusMenu.item(withTag: self.name2tag["outdated"]!)!
            let packageItem = self.statusMenu.item(withTag: self.name2tag["packages"]!)!
            packageItem.submenu?.removeAllItems()
            
            let outdatedPackages = self.packages.filter(criterion)
            let outdatedPackageCount = outdatedPackages.count
            if outdatedPackageCount > 0 {
                statusItem.title = "\(outdatedPackageCount) Outdated Packages"
                iconName = "BrewletIcon-Color"
                updateItem.title = "Upgrade"
                packageItem.isHidden = false
                self.fillPackageMenu(packageMenu: packageItem.submenu!, packages: outdatedPackages)
                
                // Only notify end-user when transitioning from having no updates to updates
                if previousOutdatedPackageCount != outdatedPackageCount {
                    self.sendNotification(title: "Updates Available",
                                          body: "Some packages can be upgraded.")
                }
            } else {
                statusItem.title = "Packages are up-to-date"
                iconName = "BrewletIcon-Black"
                updateItem.title = "Update"
                packageItem.isHidden = true
            }

            // Update icon in main thread
            DispatchQueue.main.async {
                self.statusItem.button?.image = NSImage(named: iconName)
            }
            
            os_log("Checked outdated status.", type: .info)
        }
    }
    
    func fillPackageMenu(packageMenu : NSMenu, packages: [Package]) {
        for package in packages {
            let newVersion = package.versions.stable
            let currentVersion = package.getInstalledVersion() ?? "?"
            let title = "\(package.name) (\(currentVersion)) <  \(newVersion)"
            
            let item = NSMenuItem.init(title: title,
                                       action: #selector(AppDelegate.upgradePackage),
                                       keyEquivalent: "")
            packageMenu.addItem(item)
        }
    }
    
    @objc func upgradePackage(_ sender: NSMenuItem) {
        let animation = self.animateIcon()
        let packageName = String(sender.title.split(separator: " ")[0])
        let tmpFile = self.getTemporaryFile(withName: "brewlet-package-upgrade.log")
        
        run_command(arguments: ["upgrade", packageName], fileRedirect: tmpFile) { _,_ in
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
                    }
                } else {
                    self.check_outdated()
                }
            }
        }
    }
    
    func update_info() {
        run_command(arguments: ["info"]) { (_, data: Data) in
            let info = String(decoding: data, as: UTF8.self)
            let statusItem = self.statusMenu.item(withTag: self.name2tag["info"]!)!
            statusItem.title = info
            os_log("Updated info.", type: .info)
        }
    }
    
    // MARK: - Helper functions
    
    func run_command(arguments: [String],
                     fileRedirect: FileHandle? = nil,
                     outputHandler: @escaping (Process,Data) -> Void) {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["/usr/local/Homebrew/bin/brew"] + arguments
        
        let pipe = Pipe()
        var allData = Data() // What happens to the scope of this variable when used inside the closure??
        pipe.fileHandleForReading.readabilityHandler = { fh in
            let data = fh.availableData
            allData.append(data)
        }
        task.standardOutput = fileRedirect != nil ? fileRedirect : pipe
        
        task.terminationHandler = { (process: Process) in
            if let stdout = process.standardOutput as? Pipe {
                allData.append(stdout.fileHandleForReading.readDataToEndOfFile())
            }
            else if let stdout = process.standardOutput as? FileHandle {
                stdout.closeFile()
            }
            else {
                os_log("Standard out type is unknown.", type: .error)
            }
            
            // Handle the output of the command
            outputHandler(process, allData)
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
    
    func animateIcon() -> Timer {
        var frame = 0
        let animation = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            self.statusItem.button?.image = NSImage(named: "Brewlet-Filled-\(frame)")
            self.statusItem.button?.image?.isTemplate = true
            frame = (frame + 1) % 7
        }
        
        return animation
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
        
    func formatDate(date: Date = Date()) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .medium
        dateFormatter.locale = Locale.current
        dateFormatter.doesRelativeDateFormatting = true
        return dateFormatter.string(from: date)
    }
    
    // MARK: - Preferences functions
    
    @IBAction func openPreferences(_ sender: NSMenuItem) {
        preferencesWindow.showWindow(sender)
    }
    
    func includeDependenciesChanged(newState: NSControl.StateValue) {
        // Update defaults and rerun update
        userDefaults.set(newState, forKey: "includeDependencies")
        check_outdated()
    }
    
    func updateIntervalChanged(newInterval: TimeInterval?) {
        // If newInterval is not given, then no timer should be scheduled
        let period = newInterval ?? -1
        userDefaults.setValue(period, forKey: "updateInterval")
        self.setupTimers()
    }
    
    // MARK: - Termination functions
    
    // Quit any running process and application
    @IBAction func quitClicked(sender: NSMenuItem) {
        let notificationName = Notification.Name.init("Quit Clicked")
        let notification = Notification.init(name: notificationName)
        self.applicationWillTerminate(notification)
        
        NSApplication.shared.terminate(self)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        os_log("Tearing down timers.", type: .info)
        timer?.invalidate()
    }

}
