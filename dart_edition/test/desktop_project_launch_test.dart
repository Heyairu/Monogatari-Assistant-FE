import "dart:async";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/services/desktop_project_launch.dart";

void main() {
  group("DesktopProjectLaunch.normalizeProjectArgument", () {
    test("keeps a native project path unchanged", () {
      const path = "/home/heyairu/文件/戀憶.mnproj";

      expect(DesktopProjectLaunch.normalizeProjectArgument(path), path);
    });

    test("decodes a file-manager file URI", () {
      final uri = Uri.file(
        Platform.isWindows
            ? r"C:\Users\heyairu\戀憶 project.mnproj"
            : "/home/heyairu/文件/戀憶 project.mnproj",
        windows: Platform.isWindows,
      );

      expect(
        DesktopProjectLaunch.normalizeProjectArgument(uri.toString()),
        uri.toFilePath(windows: Platform.isWindows),
      );
    });

    test("does not reinterpret non-file URIs", () {
      const uri = "content://projects/42.mnproj";

      expect(DesktopProjectLaunch.normalizeProjectArgument(uri), uri);
    });
  });

  test(
    "delivers Linux main arguments to the project handler",
    () async {
      final uri = Uri.file("/home/heyairu/文件/戀憶 project.mnproj");
      final deliveredPath = Completer<String>();

      await DesktopProjectLaunch.initialize(
        startupArguments: <String>[uri.toString()],
      );
      DesktopProjectLaunch.bind(deliveredPath.complete);

      expect(await deliveredPath.future, uri.toFilePath(windows: false));
      DesktopProjectLaunch.unbind();
    },
    skip: !Platform.isLinux,
  );
}
