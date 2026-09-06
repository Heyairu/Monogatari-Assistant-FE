# Rhodanthe native packaging

Windows and Linux Flutter CMake builds automatically run Cargo when it is
available, then install the resulting bridge next to the executable (Windows)
or into `bundle/lib` (Linux). Configure with
`-DRHODANTHE_NATIVE=OFF` when intentionally testing the Dart fallback.

The portable staging command is:

```text
dart run tool/build_rhodanthe_native.dart --platform windows
```

It supports Windows, Linux, macOS, Android arm64/arm/x64, and iOS device or
arm64 simulator Rust targets. Cross targets still require their normal Rust
target, NDK linker, or Apple SDK configuration. Android outputs are staged in
the matching `android/app/src/main/jniLibs/<abi>` directory. Apple outputs are
staged under `build/rhodanthe`; Xcode must link the static library into Runner
before `DynamicLibrary.process()` can resolve it.

Release CI should treat Cargo as required and verify ABI/contract capabilities
with the Dart preflight test. Contributor builds may omit Rust and continue on
the existing Dart path.
