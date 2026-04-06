import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let fileChannelName = "com.heyairu.monogatari_assistant/file"

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    setupFileChannel(with: flutterViewController)

    super.awakeFromNib()
  }

  private func setupFileChannel(with flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: fileChannelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "WINDOW_DEALLOCATED", message: "Window was released", details: nil))
        return
      }

      switch call.method {
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
