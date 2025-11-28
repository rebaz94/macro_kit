// import 'dart:async';
// import 'dart:developer';
// import 'dart:isolate';
//
// import 'package:macro_kit/src/analyzer/logger.dart';
// import 'package:vm_service/vm_service.dart' as vm_service;
// import 'package:vm_service/vm_service.dart' hide Isolate, Log;
// import 'package:vm_service/vm_service_io.dart';
//
// class VmUtils {
//
//   static Future<VmUtils?> create(MacroLogger logger, {int autoGCPerMin = 0}) async {
//     final serverUri = (await Service.getInfo()).serverUri;
//     if (serverUri == null) {
//       logger.warn('Cannot find serverUri for VmService. Ensure you run like `dart run --enable-vm-service main.dart`');
//       return null;
//     }
//
//     String toWebSocket(Uri uri) {
//       final pathSegments = [...uri.pathSegments.where((s) => s.isNotEmpty), 'ws'];
//       return uri.replace(scheme: 'ws', pathSegments: pathSegments).toString();
//     }
//
//     final vmService = await vmServiceConnectUri(toWebSocket(serverUri), log: _VmLog(logger));
//     return VmUtils._(logger, vmService).._setupAutoGC(autoGCPerMin);
//   }
//
//   final MacroLogger logger;
//   final VmService vmService;
//   Timer? _gcTimer;
//
//   VmUtils._(this.logger, this.vmService);
//
//   void _setupAutoGC(int perMin) {
//     if (perMin <= 0) return;
//
//     _gcTimer = Timer.periodic( Duration(minutes: perMin), (_) => gc());
//   }
//
//   Future<void> gc() async {
//     try {
//       final isolateId = Service.getIsolateId(Isolate.current)!;
//       final profile = await vmService.getAllocationProfile(isolateId, gc: true);
//       final heapCap = (profile.memoryUsage?.heapCapacity ?? 0) ~/ 1000000;
//       final heapUsage = (profile.memoryUsage?.heapUsage ?? 0) ~/ 1000000;
//
//       logger.info('gc triggered (heapCap=${heapCap}mb, heapUsage=${heapUsage}mb)');
//     } catch (e, s) {
//       logger.error('Failed to trigger gc', e, s);
//     }
//   }
//
//   void dispose() {
//     _gcTimer?.cancel();
//     _gcTimer = null;
//     vmService.dispose();
//   }
// }
//
// class _VmLog extends vm_service.Log {
//   _VmLog(this.logger);
//
//   final MacroLogger logger;
//
//   @override
//   void severe(String message) {
//     logger.error(message);
//   }
//
//   @override
//   void warning(String message) {
//     logger.warn(message);
//   }
// }
