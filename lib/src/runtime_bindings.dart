// ignore_for_file: non_constant_identifier_names
import 'dart:ffi' as ffi;

import 'runtime_abi.g.dart' as abi;

/// Native functions for the asset that owns a session, bridge, and its buffers.
///
/// An application's generated adapter implements this contract using the
/// functions bound to that application's native asset.
abstract interface class RuntimeBindings {
  /// Finalizer that releases buffers through the owning native asset.
  ffi.NativeFinalizer get bufferFinalizer;

  bool dz_initialize(ffi.Pointer<ffi.Void> data);
  ffi.Pointer<abi.dz_Bridge> dz_create(
    int port,
    int count,
    int bytes,
    int pending,
  );
  void dz_close(ffi.Pointer<abi.dz_Bridge> bridge);
  void dz_destroy(ffi.Pointer<abi.dz_Bridge> bridge);
  void dz_acknowledge(ffi.Pointer<abi.dz_Bridge> bridge);
  bool dz_is_pending(ffi.Pointer<abi.dz_Bridge> bridge, int id);
  int dz_take_request(
    ffi.Pointer<abi.dz_Bridge> bridge,
    ffi.Pointer<ffi.Pointer<abi.dz_Packet>> out,
  );
  int dz_packet_id(ffi.Pointer<abi.dz_Packet> packet);
  int dz_packet_length(ffi.Pointer<abi.dz_Packet> packet);
  ffi.Pointer<ffi.Uint8> dz_packet_bytes(ffi.Pointer<abi.dz_Packet> packet);
  void dz_packet_free(ffi.Pointer<abi.dz_Packet> packet);
  int dz_reply(
    ffi.Pointer<abi.dz_Bridge> bridge,
    int id,
    int kind,
    ffi.Pointer<ffi.Uint8> bytes,
    int len,
  );
  int dz_protocol_version();
  ffi.Pointer<abi.dz_Runtime> dz_runtime_create(
    int port,
    int count,
    int bytes,
    int tasks,
    int workers,
  );
  void dz_runtime_stop(ffi.Pointer<abi.dz_Runtime> runtime);
  bool dz_runtime_stopped(ffi.Pointer<abi.dz_Runtime> runtime);
  void dz_runtime_destroy(ffi.Pointer<abi.dz_Runtime> runtime);
  void dz_runtime_acknowledge(ffi.Pointer<abi.dz_Runtime> runtime);
  int dz_runtime_submit(
    ffi.Pointer<abi.dz_Runtime> runtime,
    int route,
    int kind,
    ffi.Pointer<ffi.Uint8> data,
    int length,
    int timeoutNs,
    ffi.Pointer<ffi.Uint64> outId,
  );
  int dz_runtime_send_signal(
    ffi.Pointer<abi.dz_Runtime> runtime,
    int route,
    ffi.Pointer<ffi.Uint8> data,
    int length,
  );
  int dz_runtime_callback_reply(
    ffi.Pointer<abi.dz_Runtime> runtime,
    int id,
    int callbackId,
    int code,
    ffi.Pointer<ffi.Uint8> data,
    int length,
  );
  int dz_runtime_cancel(ffi.Pointer<abi.dz_Runtime> runtime, int id);
  int dz_runtime_poll(
    ffi.Pointer<abi.dz_Runtime> runtime,
    ffi.Pointer<abi.RuntimeFrame> output,
    int capacity,
  );
  void dz_buffer_retain(ffi.Pointer<ffi.Void> owner);
  void dz_buffer_release(ffi.Pointer<ffi.Void> owner);
  int dz_runtime_grant(ffi.Pointer<abi.dz_Runtime> runtime, int id);
  bool dz_runtime_ready_to_destroy(ffi.Pointer<abi.dz_Runtime> runtime);
  void dz_runtime_stats(
    ffi.Pointer<abi.dz_Runtime> runtime,
    ffi.Pointer<abi.RuntimeStats> output,
  );
  int dz_live_buffers();
  int dz_live_buffer_bytes();
  int dz_buffer_capacity(ffi.Pointer<ffi.Void> owner);
}
