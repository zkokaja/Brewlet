//
//  PreferencesController.swift
//  Brewlet
//
//  Created by zzada on 2/23/20.
//  Copyright © 2020 zzada. All rights reserved.
//

import OSLog
import Cocoa

protocol PreferencesDelegate {
    func updateIntervalChanged(newInterval: TimeInterval?) // if nil, then don't update
    func includeDependenciesChanged(newState: NSControl.StateValue)
    func shareAnalyticsChanged(newState: NSControl.StateValue)
    func brewPathChanged(newPath: String)
}

class PreferencesController: NSWindowController {

    @IBOutlet weak var includeDependencies: NSButton!
    @IBOutlet weak var updateInterval: NSSlider!
    @IBOutlet weak var shareAnalytics: NSButton!
    @IBOutlet weak var autoUpgrade: NSButton!
    @IBOutlet weak var dontNotifyAvailable: NSButton!
    @IBOutlet weak var dontUpgradeCasks: NSButton!
    @IBOutlet weak var brewPath: NSTextField!
    @IBOutlet weak var intel: NSButton!
    @IBOutlet weak var appleSilicon: NSButton!
    @IBOutlet weak var custom: NSButton!

    var delegate: PreferencesDelegate?
    
    enum HomebrewPath: String {
        case appleSilicon = "/opt/homebrew/bin/brew"
        case intel = "/usr/local/bin/brew"
        case custom = ""
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()

        self.window?.center()
        self.window?.makeKeyAndOrderFront(nil)
        self.window?.level = .popUpMenu
        NSApp.activate(ignoringOtherApps: true)
        
        // Update view with current preferences
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "includeDependencies") {
            includeDependencies.state = .on
        } else {
            includeDependencies.state = .off
        }
        
        let currentInterval = defaults.double(forKey: "updateInterval")
        if currentInterval == -1 {
            updateInterval.doubleValue = updateInterval.maxValue
        } else {
            let intervalIndex = (currentInterval / 3600) * 2
            updateInterval.doubleValue = intervalIndex
        }
        
        if defaults.bool(forKey: "shareAnalytics") {
            shareAnalytics.state = .on
        } else {
            shareAnalytics.state = .off
        }        
        
        autoUpgrade.state = defaults.bool(forKey: "autoUpgrade") ? .on : .off
        dontNotifyAvailable.state = defaults.bool(forKey: "dontNotify") ? .on : .off
        dontUpgradeCasks.state = defaults.bool(forKey: "dontUpgradeCasks") ? .on : .off
        
        #if arch(arm64)
        let currentBrewPath = defaults.string(forKey: "brewPath") ?? HomebrewPath.appleSilicon.rawValue
        #elseif arch(x86_64)
        let currentBrewPath = defaults.string(forKey: "brewPath") ?? HomebrewPath.intel.rawValue
        #endif
        switch currentBrewPath {
        case HomebrewPath.intel.rawValue:
            intelSelected(nil)
        case HomebrewPath.appleSilicon.rawValue:
            appleSiliconSelected(nil)
        default:
            custom.state = .on
            brewPath.stringValue = currentBrewPath
        }
    }
    
    @IBAction func includeDependenciesPressed(_ sender: NSButton) {
        delegate?.includeDependenciesChanged(newState: sender.state)
    }
    
    @IBAction func shareAnalyticsPressed(_ sender: NSButton) {
        delegate?.shareAnalyticsChanged(newState: sender.state)
    }
    
    @IBAction func autoUpgradeChanged(_ sender: NSButton) {
        os_log("Update auto upgrade: %s", type: .info, sender.state == .on ? "on" : "off")
        UserDefaults.standard.set(sender.state == .on, forKey: "autoUpgrade")
    }
    
    @IBAction func notifyChanged(_ sender: NSButton) {
        os_log("Update don't notify: %s", type: .info, sender.state == .on ? "on" : "off")
        UserDefaults.standard.set(sender.state == .on, forKey: "dontNotify")
    }
    
    @IBAction func dontUpgradeCasksChanged(_ sender: NSButton) {
        os_log("Update don't upgrade casks: %s", type: .info, sender.state == .on ? "on" : "off")
        UserDefaults.standard.set(sender.state == .on, forKey: "dontUpgradeCasks")
    }

    @IBAction func updateIntervalChanged(_ sender: NSSlider) {
        
        var seconds: TimeInterval? = nil
        if sender.intValue == 10 {
            sender.toolTip = "Never"
        } else {
            let hours = sender.doubleValue * 0.5
            seconds = hours * 3600
            sender.toolTip = "\(hours) Hours"
        }
        
        delegate?.updateIntervalChanged(newInterval: seconds)
    }
    
    @IBAction func appleSiliconSelected(_ sender: Any?) {
        appleSilicon.state = .on
        intel.state = .off
        custom.state = .off
        brewPath.isEnabled = false
        let path = HomebrewPath.appleSilicon.rawValue
        brewPath.stringValue = path
        delegate?.brewPathChanged(newPath: path)
    }
    
    @IBAction func intelSelected(_ sender: Any?) {
        intel.state = .on
        appleSilicon.state = .off
        custom.state = .off
        brewPath.isEnabled = false
        let path = HomebrewPath.intel.rawValue
        brewPath.stringValue = path
        delegate?.brewPathChanged(newPath: path)
    }
    
    @IBAction func customSelected(_ sender: Any) {
        custom.state = .on
        appleSilicon.state = .off
        intel.state = .off
        brewPath.isEnabled = true
        delegate?.brewPathChanged(newPath: brewPath.stringValue)
    }
    
    @IBAction func brewPathChanged(_ sender: NSTextField) {
        // TODO: Validate that the path is valid
        delegate?.brewPathChanged(newPath: sender.stringValue)
    }
    
    override var windowNibName : String! {
        return "PreferencesController"
    }
    
}
