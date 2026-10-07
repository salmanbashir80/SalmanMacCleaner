import Foundation

public struct TrashValidator: Sendable {
    /// Validates that a given path is strictly within a designated Trash directory,
    /// safe for permanent deletion.
    public static func isValidTrashPath(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        let standardized = url.standardized
        let pathString = standardized.path
        
        let trashURL = URL(fileURLWithPath: NSHomeDirectory() + "/.Trash").standardized
        let trashPrefix = trashURL.path + "/"
        
        // Must be strictly inside the Trash directory
        guard pathString.hasPrefix(trashPrefix) else { return false }
        
        // Cannot be the Trash directory itself
        guard pathString != trashURL.path && pathString != trashPrefix else { return false }
        
        return true
    }
}
