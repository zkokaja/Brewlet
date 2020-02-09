//
//  AppDelegate.swift
//  BrewLet
//
//  Created by zzada on 2/8/20.
//

import Cocoa
import OSLog

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var timers : [Timer] = []
    let name2tag = ["outdated":  1,
                    "update": 2,
                    "info": 3,
                    "analytics": 6]
    
    @IBOutlet weak var statusMenu: NSMenu!
    let statusItem : NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        // Set the icon
        statusItem.menu = statusMenu
        statusItem.button?.toolTip = "Brewlet"
        statusItem.button?.image = NSImage(named: "BrewletIcon-Black")
        
        // Run initial tasks to set status
        check_outdated()
        update_info()
        update_analytics(sender: statusMenu.item(withTag: name2tag["analytics"]!)!)
        setupTimers()
    }
    
    func setupTimers() {
        let hourly : TimeInterval = 60 * 60
        let daily : TimeInterval = hourly * 24
        
        // Check for updates hourly
        timers.append(Timer.scheduledTimer(withTimeInterval: hourly, repeats: true) { (Timer) in
            self.check_outdated()
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
    
    @IBAction func update_upgrade(sender: NSMenuItem) {
        run_command(arguments: ["update"], outputHandler: { (_,_) in
            os_log("Updated brew.", type: .info)
            
            self.run_command(arguments: ["upgrade"], outputHandler: { (Process,String) in
                os_log("Upgraded packages.", type: .info)
                
                self.check_outdated()
                self.update_info()
            })
        })
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
        let statusItem = self.statusMenu.item(withTag: 0)!
        statusItem.title = "Checking..."
        
        run_command(arguments: ["outdated"]) { (_, output: String) in
            let n_lines = output.split(separator: "\n").count
            let statusItem = self.statusMenu.item(withTag: self.name2tag["outdated"]!)!
            
            var iconName = ""
            
            if n_lines > 0 {
                statusItem.title = "\(n_lines) Outdated Packages"
                iconName = "BrewletIcon-Color"
            } else {
                statusItem.title = "Packages are up-to-date"
                iconName = "BrewletIcon-Black"
            }
            
            // Update UI in main thread
            DispatchQueue.main.async {
                self.statusItem.button?.image = NSImage(named: iconName)
            }
            
            os_log("Checked outdated status.", type: .info)
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
                os_log("Unexpected error: %s", type: .error, "\(error)")
            }
        }
    }
    
    func run_command(arguments: [String], outputHandler: @escaping (Process,String) -> Void) {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["/usr/local/Homebrew/bin/brew"] + arguments
        task.standardOutput = Pipe()
        task.terminationHandler = { (process: Process) in
            if let stdout = process.standardOutput as? Pipe {
                let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
                let output = String(decoding: outputData, as: UTF8.self)
                
                outputHandler(process, output)
            }
            else {
                os_log("Standard out is not a pipe.", type: .info)
            }
        }
        
        // Run it asynch
        do {
            try task.run()
        }
        catch {
            os_log("Unexpected error: %s", type: .error, "\(error)")
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
