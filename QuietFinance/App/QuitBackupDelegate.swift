import AppKit

/// Triggers a custom-folder backup when the app is about to terminate.
final class QuitBackupDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        _ = BackupService.backupOnQuit()
    }
}
