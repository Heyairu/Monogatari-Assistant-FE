import "dart:io";

import "package:path/path.dart" as path;

Future<void> main(List<String> arguments) async {
  if (arguments.contains("--help") || arguments.contains("-h")) {
    stdout.writeln(_usage);
    return;
  }

  final options = _BuildOptions.parse(arguments);
  final projectRoot = Directory.current.absolute.path;
  final manifest = path.join(projectRoot, "rust", "Cargo.toml");
  if (!File(manifest).existsSync()) {
    stderr.writeln("Run this tool from the dart_edition directory.");
    exitCode = 64;
    return;
  }

  final cargo = options.cargo ?? "cargo";
  final command = <String>[
    "build",
    "--manifest-path",
    manifest,
    "-p",
    "rhodanthe-bridge",
    if (options.release) "--release",
    if (options.target != null) ...<String>["--target", options.target!],
  ];
  stdout.writeln("$cargo ${command.join(' ')}");
  final result = await Process.run(
    cargo,
    command,
    workingDirectory: path.join(projectRoot, "rust"),
    runInShell: Platform.isWindows,
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    exitCode = result.exitCode;
    return;
  }

  final profile = options.release ? "release" : "debug";
  final artifact = path.joinAll(<String>[
    projectRoot,
    "rust",
    "target",
    if (options.target != null) options.target!,
    profile,
    options.artifactName,
  ]);
  final source = File(artifact);
  if (!source.existsSync()) {
    stderr.writeln("Cargo succeeded but $artifact was not produced.");
    exitCode = 66;
    return;
  }

  final outputDirectory = Directory(options.outputDirectory(projectRoot))
    ..createSync(recursive: true);
  final destination = path.join(outputDirectory.path, options.artifactName);
  await source.copy(destination);
  stdout.writeln("Staged Rhodanthe native library: $destination");
}

final class _BuildOptions {
  final String platform;
  final String? target;
  final String? cargo;
  final String? output;
  final bool release;

  const _BuildOptions({
    required this.platform,
    required this.target,
    required this.cargo,
    required this.output,
    required this.release,
  });

  factory _BuildOptions.parse(List<String> arguments) {
    String? valueAfter(String option) {
      final index = arguments.indexOf(option);
      if (index < 0) return null;
      if (index + 1 >= arguments.length) {
        throw FormatException("$option requires a value");
      }
      return arguments[index + 1];
    }

    final platform = valueAfter("--platform") ?? _hostPlatform;
    final known = _platforms[platform];
    if (known == null) {
      throw FormatException("Unsupported platform $platform");
    }
    return _BuildOptions(
      platform: platform,
      target: valueAfter("--target") ?? known.target,
      cargo: valueAfter("--cargo"),
      output: valueAfter("--out"),
      release: !arguments.contains("--debug"),
    );
  }

  _PlatformBuild get _build => _platforms[platform]!;

  String get artifactName => _build.artifactName;

  String outputDirectory(String root) {
    if (output != null) return path.absolute(output!);
    return switch (platform) {
      "android-arm64" => path.join(
        root,
        "android",
        "app",
        "src",
        "main",
        "jniLibs",
        "arm64-v8a",
      ),
      "android-arm" => path.join(
        root,
        "android",
        "app",
        "src",
        "main",
        "jniLibs",
        "armeabi-v7a",
      ),
      "android-x64" => path.join(
        root,
        "android",
        "app",
        "src",
        "main",
        "jniLibs",
        "x86_64",
      ),
      "ios-arm64" ||
      "ios-simulator" => path.join(root, "build", "rhodanthe", platform),
      _ => path.join(root, "build", "rhodanthe", platform),
    };
  }
}

final class _PlatformBuild {
  final String? target;
  final String artifactName;

  const _PlatformBuild(this.target, this.artifactName);
}

String get _hostPlatform {
  if (Platform.isWindows) return "windows";
  if (Platform.isLinux) return "linux";
  if (Platform.isMacOS) return "macos";
  throw UnsupportedError("This host platform cannot build Rhodanthe");
}

const Map<String, _PlatformBuild> _platforms = <String, _PlatformBuild>{
  "windows": _PlatformBuild(null, "rhodanthe_bridge.dll"),
  "linux": _PlatformBuild(null, "librhodanthe_bridge.so"),
  "macos": _PlatformBuild(null, "librhodanthe_bridge.dylib"),
  "android-arm64": _PlatformBuild(
    "aarch64-linux-android",
    "librhodanthe_bridge.so",
  ),
  "android-arm": _PlatformBuild(
    "armv7-linux-androideabi",
    "librhodanthe_bridge.so",
  ),
  "android-x64": _PlatformBuild(
    "x86_64-linux-android",
    "librhodanthe_bridge.so",
  ),
  "ios-arm64": _PlatformBuild("aarch64-apple-ios", "librhodanthe_bridge.a"),
  "ios-simulator": _PlatformBuild(
    "aarch64-apple-ios-sim",
    "librhodanthe_bridge.a",
  ),
};

const String _usage = """
Build and stage the MonoAshi Rhodanthe native bridge.

dart run tool/build_rhodanthe_native.dart [options]

  --platform <windows|linux|macos|android-arm64|android-arm|android-x64|ios-arm64|ios-simulator>
  --target <rust-target>   Override the platform's Rust target.
  --cargo <path>          Override the Cargo executable.
  --out <directory>       Override the staging directory.
  --debug                 Build the debug profile instead of release.

Android cross-builds require an NDK linker configured for Cargo. Apple static
libraries must be linked by the Xcode target so DynamicLibrary.process() can
resolve the exported C ABI.
""";
