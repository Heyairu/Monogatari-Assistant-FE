import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override init() {
    super.init()
    NSAppleEventManager.shared().setEventHandler(
      self,
      andSelector: #selector(handleOpenDocumentsEvent(_:withReplyEvent:)),
      forEventClass: AEEventClass(kCoreEventClass),
      andEventID: AEEventID(kAEOpenDocuments)
    )
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
  }

  override func application(_ application: NSApplication, openFiles filenames: [String]) {
    NSLog("AppDelegate openFiles: \(filenames)")
    MainFlutterWindow.openProjectFiles(filenames)
    NSApp.reply(toOpenOrPrint: .success)
  }

  override func application(_ application: NSApplication, openFile filename: String) -> Bool {
    NSLog("AppDelegate openFile: \(filename)")
    MainFlutterWindow.openProjectFiles([filename])
    NSApp.reply(toOpenOrPrint: .success)
    return true
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    let paths = urls.map(\.path)
    NSLog("AppDelegate open urls: \(paths)")
    MainFlutterWindow.openProjectFiles(paths)
  }

  @objc private func handleOpenDocumentsEvent(
    _ event: NSAppleEventDescriptor,
    withReplyEvent replyEvent: NSAppleEventDescriptor
  ) {
    guard let directObject = event.paramDescriptor(forKeyword: keyDirectObject) else {
      NSLog("AppleEvent open documents had no direct object")
      return
    }

    var paths: [String] = []
    if directObject.numberOfItems > 0 {
      for index in 1...directObject.numberOfItems {
        if let path = path(from: directObject.atIndex(index)) {
          paths.append(path)
        }
      }
    } else if let path = path(from: directObject) {
      paths.append(path)
    }

    NSLog("AppleEvent open documents paths: \(paths)")
    MainFlutterWindow.openProjectFiles(paths)
  }

  private func path(from descriptor: NSAppleEventDescriptor?) -> String? {
    guard let descriptor else {
      return nil
    }
    if let fileUrl = descriptor.coerce(toDescriptorType: DescType(typeFileURL))?.stringValue,
       let path = URL(string: fileUrl)?.path {
      return path
    }
    return descriptor.stringValue
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
