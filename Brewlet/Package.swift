//
//  Package.swift
//  Brewlet
//
//  Created by zzada on 2/21/20.
//

import Foundation

/**
 A `brew` Package and some of its metadata.
 */
struct Package {
    var name: String
    var desc: String?
    var outdated: Bool
    var versions: Version
    var installed: [InstalledPackage]
    
    /// A custom property that is true if any of the installed packages are installed by request,
    /// to make searching and filtering easier.
    var installed_on_request: Bool
        
    /**
     Find the version of the latest _installed_ package.
     
     Assumes that the first item in the list is latest version.
     
     - Returns: The latest version of this package, if installed.
     */
    func getInstalledVersion() -> String? {
        var version: String? = nil
        if !installed.isEmpty {
            version = installed[0].version
        }
        return version
    }
}

/**
 The version of a package.
 */
struct Version {
    var stable: String
}

/**
 A package that is installed, including its version and metadata (e.g. on request, is a dependency).
 */
struct InstalledPackage {
    var version: String
    var installed_on_request: Bool
    var installed_as_dependency: Bool
}

/**
 Deserialize the JSON data from `brew info --json --installed` to a list of `Package` objects.
 
 - Parameter jsonData: Data representing valid `brew` JSON information.
 - Returns: A new list of `Package`s.
 */
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
                                    installed: installedPackages,
                                    installed_on_request: isRequested))
        }
    }
    
    return packages
}
