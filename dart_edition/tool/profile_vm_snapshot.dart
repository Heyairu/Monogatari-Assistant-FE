import "dart:convert";

import "package:vm_service/vm_service.dart";
import "package:vm_service/vm_service_io.dart";

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    throw ArgumentError(
      "Usage: dart run tool/profile_vm_snapshot.dart <ws-uri>",
    );
  }

  final service = await vmServiceConnectUri(arguments.single);
  try {
    final vm = await service.getVM();
    final process = await service.getProcessMemoryUsage();
    final isolates = <Map<String, Object?>>[];
    for (final isolateRef in vm.isolates ?? const <IsolateRef>[]) {
      final isolateId = isolateRef.id;
      if (isolateId == null) continue;
      final memory = await service.getMemoryUsage(isolateId);
      isolates.add({
        "id": isolateId,
        "name": isolateRef.name,
        "heapUsageBytes": memory.heapUsage,
        "heapCapacityBytes": memory.heapCapacity,
        "externalUsageBytes": memory.externalUsage,
      });
    }
    // ignore: avoid_print
    print(
      const JsonEncoder.withIndent("  ").convert({
        "capturedAt": DateTime.now().toUtc().toIso8601String(),
        "targetCPU": vm.targetCPU,
        "architectureBits": vm.architectureBits,
        "processMemory": process.root == null
            ? null
            : _memoryRegion(process.root!),
        "isolates": isolates,
      }),
    );
  } finally {
    await service.dispose();
  }
}

Map<String, Object?> _memoryRegion(ProcessMemoryItem usage) => {
  "name": usage.name,
  "description": usage.description,
  "sizeBytes": usage.size,
  "children": [
    for (final child in usage.children ?? const <ProcessMemoryItem>[])
      _memoryRegion(child),
  ],
};
