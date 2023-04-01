//
//  AppDelegate.swift
//  BrewLet
//
//  Created by zzada on 2/8/20.
//

import Cocoa
import OSLog
import UserNotifications
import AppKit.NSWorkspace

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, PreferencesDelegate {

    var timer: Timer?
    var packages: [Package] = []
    let name2tag = ["outdated":  1,
                    "update": 2,
                    "info": 3,
                    "packages": 4,
                    "services": 7]
    
    @IBOutlet weak var statusMenu: NSMenu!
    let userDefaults = UserDefaults.standard
    let statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    
    var preferencesWindow: PreferencesController!
    
    struct Service {
        var name: String
        var isStopped: Bool?
    }
    
    /***
     Entry-point into the application.
     
     Runs jobs to sync with `brew` and check for outdated packages, then sets up a timer
     to do this periodicially.
     
     - Parameter aNotification: Unsued.
     */
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        // Set the icon
        statusItem.menu = statusMenu
        statusItem.button?.toolTip = "Brewlet \(appVersion ?? "")"
        statusItem.button?.image = NSImage(named: "BrewletIcon-Black")
        statusItem.button?.image?.isTemplate = true

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
        sync_services()
        update_upgrade(sender: nil)
        update_info()
        update_analytics()
        setupTimers()
    }
    
    /**
     Creates a Timer that will run every periodically to synchronize with `brew`.
     
     The scheduled job will check for packge update, update the info stats, and analytics settings.
     It uses a default interval of 1 hour, or the user defined preference if set.
     
     - Postcondition: Assigns the `timer` variable.
     - SeeAlso: self.update_upgrade
     */
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
            self.update_analytics()
            self.sync_services()
        }
        
        os_log("Scheduled a timer with a period of %f seconds", type: .info, period)
    }
    
    // MARK: - Actions
    
    /**
     
     */
    @IBAction func openLog(sender: NSMenuItem) {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let logDir = homeDir.appendingPathComponent("Library/Logs/Brewlet")
        let logFile = logDir.path + "/brewlet.log"
        NSWorkspace.shared.openFile(logFile, withApplication: "Console")
        os_log("Opened log file.", type: .info)
    }
    
    /**
     Runs `brew cleanup` and updates the info statistics.
     
     - Parameter sender: Unused.
     */
    @IBAction func cleanup(sender: NSMenuItem) {
        run_command(arguments: ["cleanup"], outputHandler: { (_,_) in
            os_log("Cleaned up.", type: .info)
            self.update_info()
        })
    }
    
    /**
     Either run `brew update` or `brew upgrade` on all packages.
     
     If there are existing outdated packages and the user clicks on the upgrade menu item, this function
     will call on the upgrade command, otherwise it will update the package list.
     
     - Parameter sender: Optional that is set when the menu item is clicked from the UI.
     - SeeAlso: AppDelegate.check_outdated
     */
    @IBAction func update_upgrade(sender: NSMenuItem?) {
        let animation = animateIcon()
        
        // Determine which packages to include
        let includeDependencies = self.userDefaults.bool(forKey: "includeDependencies")
        let criterion: (Package) -> Bool = includeDependencies
            ? { $0.outdated }
            : { $0.outdated && $0.installed_on_request }
        
        let shouldUpgrade = self.packages.filter(criterion).count > 0
        
        let command = shouldUpgrade && sender != nil ? "upgrade" : "update"
        
        var args = [command]
        if command == "upgrade" && self.userDefaults.bool(forKey: "dontUpgradeCasks") {
            args.append("--formula")
        }
        
        let updateItem = self.statusMenu.item(withTag: self.name2tag["update"]!)!
        updateItem.isEnabled = false
        updateItem.title = command == "update" ? "Updating..." : "Upgrading..."
        
        let packageItem = self.statusMenu.item(withTag: self.name2tag["packages"]!)!
        packageItem.isEnabled = false
        
        let tmpFile = getLogFile()
        
        run_command(arguments: args, fileRedirect: tmpFile) { _,_ in
            os_log("Ran command: `%s`.", type: .info, args.joined(separator: " "))
            
            updateItem.isEnabled = true
            animation.invalidate()
            self.check_outdated()
        }
        
        let dateStr = formatDate()
        statusItem.button?.toolTip = "Brewlet \(appVersion ?? ""). Last updated \(dateStr)"
    }
    
    /**
     Sets the user analytics sharing preference by calling on the `brew analytics` command.
     
     - Parameter turnOn: True if analytics should be turned on, otherwise false.
     - Postcondition: Sets the `shareAnalytics` key in `UserDefaults`.
     */
    func toggle_analytics(turnOn: Bool) {
        let command = turnOn ? "on" : "off"
        run_command(arguments: ["analytics", command]) { _,_ in
            self.userDefaults.set(turnOn, forKey: "shareAnalytics")
            os_log("Updated analytics to %s state", type: .info, command)
        }
    }
    
    /**
     Save a file containing a list of brew packages to the user's downloads directory.
     
     - Parameter sender:Unused.
     - Postcondition: Saves the file `~/Downloads/brew-packages.txt`.
     */
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
                                      body: "An unexpected error occurred during export. See log for details.")
            }
        }
    }
    
    /**
     Syncs `UserDefaults["shareAnalytics"]` with the current `brew analytics state` boolean.
     */
    func update_analytics() {
        run_command(arguments: ["analytics", "state"]) { (_, data: Data) in
            let output = String(decoding: data, as: UTF8.self)
            let isDisabled = output.lowercased().contains("disabled")
            self.userDefaults.set(!isDisabled, forKey: "shareAnalytics")
            os_log("Currently %s sharing analytics", type: .info, isDisabled ? "not" : "am")
        }
    }
    
    /**
     Syncs `self.packages` with `brew`'s current states for installed packages.
     
     Will also update the GUI with the appropriate actions (i.e. upgrade if outdated packages exist).
     */
    func check_outdated() {
        let statusItem = statusMenu.item(withTag: 0)!
        statusItem.title = "Checking..."
        
        let updateItem = self.statusMenu.item(withTag: self.name2tag["update"]!)!
        updateItem.title = "Updating..."
        updateItem.isEnabled = false
        
        let packageItem = self.statusMenu.item(withTag: self.name2tag["packages"]!)!
        packageItem.isEnabled = false
        
        run_command(arguments: ["info", "--json=v2", "--installed"]) { (_, data: Data) in
            // Determine which packages to include
            let includeDependencies = self.userDefaults.bool(forKey: "includeDependencies")
            let criterion: (Package) -> Bool = includeDependencies
                ? { $0.outdated }
                : { $0.outdated && $0.installed_on_request }
            
            // Keep only packages that are outdated and meet the above criteria
            let previousOutdatedPackageCount = self.packages.filter(criterion).count
            
            do {
                self.packages = try packagesFromJson(jsonData: data)
            } catch {
                os_log("Unexpected error: %s", type: .error, "\(error)")
                self.sendNotification(title: "Unexpected Error",
                                      body: "An unexpected error occurred in JSON serialization. See log for details.")
                return
            }
            
            // Update  the GUI
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
                packageItem.isEnabled = true
                self.fillPackageMenu(packageMenu: packageItem.submenu!, packages: outdatedPackages)
                
                // Only notify end-user when transitioning from having no updates to updates
                if previousOutdatedPackageCount != outdatedPackageCount {
                    let message = (outdatedPackageCount == 1) ?
                        "\(outdatedPackages[0].name) can be upgraded." :
                        "\(outdatedPackageCount) packages can be upgraded."

                    self.sendNotification(title: "Updates Available", body: message)
                }
            } else {
                statusItem.title = "Packages are up-to-date"
                iconName = "BrewletIcon-Black"
                updateItem.title = "Update"
                packageItem.isHidden = true
                packageItem.isEnabled = false
            }
            
            updateItem.isEnabled = true
            
            os_log("Checked outdated status.", type: .info)

            // Update icon in main thread
            DispatchQueue.main.async {
                self.statusItem.button?.image = NSImage(named: iconName)
                
                // Upgrade packages if configured to do so
                let autoUpgrade = self.userDefaults.bool(forKey: "autoUpgrade")
                if autoUpgrade && outdatedPackageCount > 0 {
                    os_log("Auto upgrading packages.", type: .info)
                    let updateItem = self.statusMenu.item(withTag: self.name2tag["update"]!)!
                    self.update_upgrade(sender: updateItem)
                }
            }
        }
    }
    
    /**
     Populates the Packages menu with menu items for each outdated package.
     
     - Parameter packageMenu: The menu to add the `NSMenuItem`s to.
     - Parameter packages: The list of packages to add, using their name and versions.
     */
    func fillPackageMenu(packageMenu : NSMenu, packages: [Package]) {
        for package in packages {
            let newVersion = package.getStableVersion()
            let currentVersion = package.getInstalledVersion() ?? "?"
            let title = "\(package.name) (\(currentVersion)) <  \(newVersion)"
            
            let item = NSMenuItem.init(title: title,
                                       action: #selector(AppDelegate.upgradePackage),
                                       keyEquivalent: "")
            item.toolTip = package.desc
            packageMenu.addItem(item)
        }
    }
    
    /**
     Upgrade a single package.
     
     Called when a user clicks on one outdated package in the Packages menu. If this is the last
     package in the list, reset menu labels and status. Otherwise, leave as is.
     
     - Parameter sender: The `NSMenuItem` representing the package to be updated.
     */
    @objc func upgradePackage(_ sender: NSMenuItem) {
        let animation = self.animateIcon()
        let packageName = String(sender.title.split(separator: " ")[0])
        let tmpFile = getLogFile()
        
        let updateItem = self.statusMenu.item(withTag: self.name2tag["update"]!)!
        updateItem.isEnabled = false
        updateItem.title = "Upgrading..."
        
        let packageItem = self.statusMenu.item(withTag: self.name2tag["packages"]!)!
        packageItem.isEnabled = false
        
        run_command(arguments: ["upgrade", packageName], fileRedirect: tmpFile) { _,_ in
            os_log("Upgraded package: %s.", type: .info, packageName)
            
            animation.invalidate()
            sender.menu?.removeItem(sender)
            
            updateItem.isEnabled = true
            packageItem.isEnabled = true
            
            // Update statuses
            let statusItem = self.statusMenu.item(withTag: self.name2tag["outdated"]!)!
            if let n_packages = Int(statusItem.title.split(separator: " ")[0]) {
                if n_packages > 1 {
                    statusItem.title = "\(n_packages - 1) Outdated Packages"
                    updateItem.title = "Upgrade"
                    DispatchQueue.main.async {
                        self.statusItem.button?.image = NSImage(named: "BrewletIcon-Color")
                    }
                } else {
                    updateItem.title = "Update"
                    self.check_outdated()
                }
            }
        }
    }
    
    /**
     Update the info statistics with `brew info` results.
     */
    func update_info() {
        run_command(arguments: ["info"]) { (process: Process, data: Data) in
            let info = String(decoding: data, as: UTF8.self)
            if process.terminationStatus == 0 {
                let statusItem = self.statusMenu.item(withTag: self.name2tag["info"]!)!
                statusItem.title = info
                os_log("Updated info.", type: .info)
            } else {
                os_log("Error updating info: %s.", type: .error, info)
            }
        }
    }
    
    /**
     
     */
    func sync_services() {
        let servicesMenu = self.statusMenu.item(withTag: self.name2tag["services"]!)!
        servicesMenu.state = .on
        
        run_command(arguments: ["services"]) { (_, data: Data) in
            var services: [Service] = []
            
            os_log("Syncing services.", type: .info)
            
            // Sync with brew
            let data = String(decoding: data, as: UTF8.self)
            let lines = data.split(separator: "\n")
            
            // Check that there are services before parsing the output
            if lines.count > 0 {
                for line in lines[1...] {
                    let parts = line.split(separator: " ", maxSplits: Int.max, omittingEmptySubsequences: true)
                    let package = parts[0]
                    let isStopped = parts[1] == "stopped"
                    services.append(Service(name: String(package), isStopped: isStopped))
                }
            }
            
            // Update UI
            if services.count > 0 {
                
                // Make sure all are enabled
                for item in servicesMenu.submenu!.items.filter({ $0.isEnabled == false }) {
                    item.isEnabled = true
                }
                        
                // Remove old menu items
                for item in servicesMenu.submenu!.items.filter({ $0.tag == -1 }) {
                    servicesMenu.submenu!.removeItem(item)
                }
                
                // Add new ones
                for service in services {
                    let serviceItem = NSMenuItem(title: service.name, action: #selector(AppDelegate.handleServiceAction), keyEquivalent: "")
                    serviceItem.tag = -1
                    serviceItem.state = service.isStopped! ? .off : .on
                    serviceItem.onStateImage = NSImage(named: NSImage.statusAvailableName)
                    serviceItem.offStateImage = NSImage(named: NSImage.statusUnavailableName)
                    serviceItem.mixedStateImage = NSImage(named: NSImage.statusPartiallyAvailableName)
                    servicesMenu.submenu!.addItem(serviceItem)
                }
            } else {
                // Disable all actions
                for item in servicesMenu.submenu!.items {
                    item.isEnabled = false
                }
            }
            
            servicesMenu.state = .off
        }
    }
    
    @IBAction func handleServiceAction(_ sender: NSMenuItem) {
        
        if sender.tag == -1 {
            // The sender is a specific service
            let service = sender.title
            let command = sender.state == .off ? "start" : "stop"
                        
            sender.state = .mixed
            sender.isEnabled = false
            
            let args = ["services", command, service]
            run_command(arguments: args) { _,_ in
                print("Done", service, command)
                self.sync_services()
            }
            
        } else {
            // The sender is from start/stop/restart all
            
            var command: String
            if sender.title.lowercased().contains("restart") {
                command = "restart"
            }
            else if sender.title.lowercased().contains("start") {
                command = "start"
            }
            else if sender.title.lowercased().contains("stop") {
                command = "stop"
            }
            else {
                return
            }
            
            // Show service menu as being refreshed, and disable all actions
            let servicesMenu = self.statusMenu.item(withTag: self.name2tag["services"]!)!
            servicesMenu.state = .on
            for item in servicesMenu.submenu!.items {
                item.isEnabled = false
            }
            
            let args = ["services", command, "--all"]
            run_command(arguments: args) { _,_ in
                // TODO - show somehow that services is being refresh?
                print("Done all", command)
                self.sync_services()
            }
        }
    }
    
    
    // MARK: - Helper functions
    
    /**
     Run the `brew` command with the given arguments asynchronously, and call on
     `outputHandler` when the process completes.
     
     The main function that interfaces with `brew` via calls with `Process`. It will run
     the command in a separate thread, but pipe its standard output to a buffer so that the calling
     function can use it in the given closure.
     
     - Parameter arguments: A list of args to pass after the `brew` command.
     - Parameter fileRedirect: An optional file handler for standard output. By default will be piped to a Data buffer.
     - Parameter outputHandler: Closure to run when the command terminates (successfully or not).
     */
    func run_command(arguments: [String],
                     fileRedirect: FileHandle? = nil,
                     outputHandler: @escaping (Process,Data) -> Void) {
        #if arch(arm64)
        let brewPath = userDefaults.string(forKey: "brewPath") ?? PreferencesController.HomebrewPath.appleSilicon.rawValue
        #elseif arch(x86_64)
        let brewPath = userDefaults.string(forKey: "brewPath") ?? PreferencesController.HomebrewPath.intel.rawValue
        #endif
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = [brewPath] + arguments
        
        let pipe = Pipe()
        var allData = Data() // What happens to the scope of this variable when used inside the closure??
        pipe.fileHandleForReading.readabilityHandler = { fh in
            let data = fh.availableData
            allData.append(data)
        }
        task.standardOutput = fileRedirect != nil ? fileRedirect : pipe
        task.standardError = task.standardOutput
        
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
                                  body: "An unexpected error occurred for \(arguments). See log for details.")
        }
    }
    
    /**
     Animate the status icon.
     
     Schedule a `Timer` that will sequentially flip through icons to make an animation.
     
     - Returns: A new `Timer` process ready to be started then stopped.
     */
    func animateIcon() -> Timer {
        var frame = 0
        let animation = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            self.statusItem.button?.image = NSImage(named: "Brewlet-Filled-\(frame)")
            self.statusItem.button?.image?.isTemplate = true
            frame = (frame + 1) % 7
        }
        
        return animation
    }
    
    /**
     Send a notification to the user.
     
     Uses the native notification center to notify the user of an event, if allowed.
     
     - Parameter title: The localized title, containing the reason for the alert.
     - Parameter body: The localized message to display in the notification alert.
     - Parameter timeInterval: The time (in seconds) that must elapse from the current time before the trigger fires.
                               This value must be greater than zero.
     */
    func sendNotification(title: String, body: String, timeInterval: TimeInterval = 1) {
        
        // Disable notifications based on user's preferences
        if userDefaults.bool(forKey: "dontNotify") {
            return
        }
        
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
    
    /**
     Open a file for temporary writing.
     
     - Parameter withName: The name of the file to create.
     - Returns: A handler for the new file if creation was successful (e.g. permissions).
     */
    func getLogFile(withName: String = "brewlet.log") -> FileHandle? {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let logDir = homeDir.appendingPathComponent("Library/Logs/Brewlet")

        // Create log dir if it does not exist
        if FileManager.default.fileExists(atPath: logDir.path, isDirectory: nil) == false {
            do {
                try FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: false)
            } catch {
                os_log("Unable to create log directory: %s", type: .error, "\(logDir.path)")
            }
        }

        // Create log file
        let fileName = logDir.appendingPathComponent(withName)
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
    
    /**
     Format a given date, or the current time by default.
     
     - Parameter date: The date object to format.
     - Returns: A relative formated string representation of the given date.
     */
    func formatDate(date: Date = Date()) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .medium
        dateFormatter.locale = Locale.current
        dateFormatter.doesRelativeDateFormatting = true
        return dateFormatter.string(from: date)
    }
    
    // MARK: - Preferences functions
    
    /**
     Opens the preferences window when the  menu item is clicked.
     
     - Parameter sender: The calling menu item.
     */
    @IBAction func openPreferences(_ sender: NSMenuItem) {
        preferencesWindow.showWindow(sender)
    }
    
    /**
     Handle a change of preferences for whether to include package dependencies in list of outdated packages.
     
     - Parameter newState: The new state of the checkbox.
     - PostCondition: Will check for outdated packages, and update the cache.
     */
    func includeDependenciesChanged(newState: NSControl.StateValue) {
        // Update defaults and rerun update
        userDefaults.set(newState, forKey: "includeDependencies")
        check_outdated()
    }
    
    /**
     Handle a change in analytics sharing preferences.
     
     - Parameter newState: The new state of the checkbox.
     */
    func shareAnalyticsChanged(newState: NSControl.StateValue) {
        toggle_analytics(turnOn: newState == .on)
    }
    
    /**
     Handle a change in the background timer's periodic interval.
     
     - Parameter newInterval: The new time interval between updates, or nil to unset timer.
     */
    func updateIntervalChanged(newInterval: TimeInterval?) {
        // If newInterval is not given, then no timer should be scheduled
        let period = newInterval ?? -1
        userDefaults.setValue(period, forKey: "updateInterval")
        self.setupTimers()
    }
    
    /**
     Handle a change of preferences for where the brew binary is.
     
     - Parameter newState: The new state of the textfield.
     */
    func brewPathChanged(newPath: String) {
        // Update defaults and rerun update
        userDefaults.set(newPath, forKey: "brewPath")
        check_outdated()
        update_info()
    }
    
    // MARK: - Termination functions
    
    /**
     Quit the application, and clean up timers.
     
     - Parameter sender: Unused.
     - SeeAlso: AppDelegate.applicationWillTerminate
     */
    @IBAction func quitClicked(sender: NSMenuItem) {
        let notificationName = Notification.Name.init("Quit Clicked")
        let notification = Notification.init(name: notificationName)
        self.applicationWillTerminate(notification)
        
        NSApplication.shared.terminate(self)
    }

    /**
     Invalidates the scheduled timer.
     
     - Parameter aNotification: Unused.
     */
    func applicationWillTerminate(_ aNotification: Notification) {
        os_log("Tearing down timers.", type: .info)
        timer?.invalidate()
    }

}
