//
//  Package.swift
//  Brewlet
//
//  Created by zzada on 2/21/20.
//

import Foundation

struct Package {
    var name: String
    var desc: String?
    var outdated: Bool
    var versions: Version
    var installed_on_request: Bool
    var installed: [InstalledPackage]
    
    func getInstalledVersion() -> String? {
        var version: String? = nil
        if !installed.isEmpty {
            version = installed[0].version
        }
        return version
    }
}

struct Version {
    var stable: String
}

struct InstalledPackage {
    var version: String
    var installed_on_request: Bool
    var installed_as_dependency: Bool
}

func packagesFromJson(jsonData: Data) throws -> [Package] {
    var packages = [Package]()
    if let elements = try JSONSerialization.jsonObject(with: jsonData) as? [NSDictionary] {
        for element in elements {
            let name = element["name"] as? String ?? "Unknown"
            let desc = element["desc"] as? String
            let outdated = element["outdated"] as? Bool ?? false
            
            // Versions
            
            var versions = Version(stable: "?")
            if let versionsElement = element["versions"] as? NSDictionary {
                let stable = versionsElement["stable"] as? String ?? "?"
                versions = Version(stable: stable)
            }
            
            var installedPackages = [InstalledPackage]()
            if let installedElements = element["installed"] as? [NSDictionary] {
                for installedElement in installedElements {
                    let version = installedElement["version"] as? String ?? "Unknown"
                    let isRequested = installedElement["installed_on_request"] as? Bool ?? false
                    let isDependency = installedElement["installed_as_dependency"] as? Bool ?? false
                                        
                    installedPackages.append(InstalledPackage(version: version,
                                                              installed_on_request: isRequested,
                                                              installed_as_dependency: isDependency))

                }
            }
             
            let isRequested : Bool = installedPackages.filter{$0.installed_on_request}.count > 0
            
            packages.append(Package(name: name,
                                    desc: desc,
                                    outdated: outdated,
                                    versions: versions,
                                    installed_on_request: isRequested,
                                    installed: installedPackages))
        }
    }
    
    return packages
}
