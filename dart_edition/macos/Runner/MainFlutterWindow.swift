import Cocoa
import FlutterMacOS

// DropView: capture file drag-and-drop and forward file paths to MainFlutterWindow
class DropView: NSView {
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    registerForDraggedTypes([.fileURL])
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    registerForDraggedTypes([.fileURL])
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
  }

  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    return .copy
  }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let pasteboard = sender.draggingPasteboard
    guard let items = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [NSURL] else {
      NSLog("DropView: no file URLs in pasteboard")
      return false
    }

    let paths = items.compactMap { $0.path }
    NSLog("DropView.performDragOperation received paths: \(paths)")
    if !paths.isEmpty {
      MainFlutterWindow.openProjectFiles(paths)
      return true
    }
    return false
  }
}

class MainFlutterWindow: NSWindow {
  private let fileChannelName = "com.heyairu.monogatari_assistant/file"
  private static weak var activeWindow: MainFlutterWindow?
  private static var pendingProjectFilePayloads: [[String: String]] = []
  private static var dartIsReadyForProjectFiles = false
  private var fileChannel: FlutterMethodChannel?

  static func openProjectFiles(_ paths: [String]) {
    NSLog("MainFlutterWindow.openProjectFiles called with \(paths)")
    let projectPaths = paths.filter {
      URL(fileURLWithPath: $0).pathExtension.lowercased() == "mnproj"
    }
    NSLog("Filtered projectPaths: \(projectPaths)")
    guard !projectPaths.isEmpty else {
      NSLog("No projectPaths to open")
      return
    }

    let payloads = projectPaths.map { projectFilePayload(forPath: $0) }
    guard dartIsReadyForProjectFiles, let activeWindow else {
      pendingProjectFilePayloads.append(contentsOf: payloads)
      return
    }

    activeWindow.sendProjectFilesToDart(payloads)
  }

  private static func projectFilePayload(forPath path: String) -> [String: String] {
    var payload = ["path": path]
    let url = URL(fileURLWithPath: path)
    payload["name"] = url.lastPathComponent

    do {
      let content = try String(contentsOf: url, encoding: .utf8)
      payload["content"] = content
    } catch {
      NSLog("Could not read project file content immediately for \(path): \(error)")
    }

    do {
      let bookmarkData = try url.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
      payload["bookmark"] = bookmarkData.base64EncodedString()
    } catch {
      NSLog("Could not create security-scoped bookmark for project file \(path): \(error)")
    }
    return payload
  }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    // Overlay a transparent DropView to capture file drag-and-drop onto the window
    let dropView = DropView(frame: flutterViewController.view.bounds)
    dropView.autoresizingMask = [.width, .height] as NSView.AutoresizingMask
    flutterViewController.view.addSubview(dropView)

    RegisterGeneratedPlugins(registry: flutterViewController)
    setupFileChannel(with: flutterViewController)
    MainFlutterWindow.activeWindow = self

    super.awakeFromNib()
  }

  private func setupFileChannel(with flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: fileChannelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    fileChannel = channel

    NSLog("File channel set up: \(fileChannelName)")

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "WINDOW_DEALLOCATED", message: "Window was released", details: nil))
        return
      }

      switch call.method {
      case "takePendingProjectFiles":
        MainFlutterWindow.dartIsReadyForProjectFiles = true
        let pendingPayloads = MainFlutterWindow.pendingProjectFilePayloads
        MainFlutterWindow.pendingProjectFilePayloads.removeAll()
        result(pendingPayloads)

      case "flushPendingProjectFiles":
        MainFlutterWindow.dartIsReadyForProjectFiles = true
        let pendingPayloads = MainFlutterWindow.pendingProjectFilePayloads
        MainFlutterWindow.pendingProjectFilePayloads.removeAll()
        if !pendingPayloads.isEmpty {
          self.sendProjectFilesToDart(pendingPayloads)
        }
        result(nil)

      case "createSecurityScopedBookmark":
        guard
          let args = call.arguments as? [String: Any],
          let rawPath = args["path"] as? String,
          !rawPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
          result(FlutterError(code: "INVALID_ARGS", message: "path is required", details: nil))
          return
        }

        do {
          let bookmark = try self.createSecurityScopedBookmark(forPath: rawPath)
          result(bookmark)
        } catch {
          result(FlutterError(code: "BOOKMARK_CREATE_FAILED", message: error.localizedDescription, details: nil))
        }

      case "openProjectFromSecurityScopedBookmark":
        guard
          let args = call.arguments as? [String: Any],
          let bookmark = args["bookmark"] as? String,
          !bookmark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
          result(FlutterError(code: "INVALID_ARGS", message: "bookmark is required", details: nil))
          return
        }

        do {
          let payload = try self.openProjectFromSecurityScopedBookmark(bookmark)
          result(payload)
        } catch {
          result(FlutterError(code: "BOOKMARK_OPEN_FAILED", message: error.localizedDescription, details: nil))
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func sendProjectFilesToDart(_ payloads: [[String: String]]) {
    guard let fileChannel else {
      MainFlutterWindow.pendingProjectFilePayloads.append(contentsOf: payloads)
      NSLog("fileChannel nil, queued project file payloads: \(payloads)")
      return
    }
    for payload in payloads {
      NSLog("Invoking openProjectFile with payload: \(payload)")
      fileChannel.invokeMethod("openProjectFile", arguments: payload)
    }
  }

  private func createSecurityScopedBookmark(forPath path: String) throws -> String {
    let url = URL(fileURLWithPath: path)
    let bookmarkData = try url.bookmarkData(
      options: [.withSecurityScope],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
    return bookmarkData.base64EncodedString()
  }

  private func openProjectFromSecurityScopedBookmark(_ base64Bookmark: String) throws -> [String: Any] {
    guard let bookmarkData = Data(base64Encoded: base64Bookmark) else {
      throw NSError(
        domain: "MonogatariAssistant",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Bookmark data is invalid"]
      )
    }

    var isStale = false
    let url = try URL(
      resolvingBookmarkData: bookmarkData,
      options: [.withSecurityScope],
      relativeTo: nil,
      bookmarkDataIsStale: &isStale
    )

    guard url.startAccessingSecurityScopedResource() else {
      throw NSError(
        domain: "MonogatariAssistant",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Cannot access security-scoped file"]
      )
    }
    defer {
      url.stopAccessingSecurityScopedResource()
    }

    let data = try Data(contentsOf: url)
    guard let content = String(data: data, encoding: .utf8) else {
      throw NSError(
        domain: "MonogatariAssistant",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: "File content is not UTF-8 text"]
      )
    }

    var resolvedBookmark = base64Bookmark
    if isStale {
      let refreshedBookmark = try url.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
      resolvedBookmark = refreshedBookmark.base64EncodedString()
    }

    return [
      "name": url.lastPathComponent,
      "path": url.path,
      "uri": resolvedBookmark,
      "content": content,
    ]
  }
}
