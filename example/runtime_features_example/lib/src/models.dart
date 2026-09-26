// Application-owned models, codecs, and typed session API.
import 'dart:async';
import 'dart:typed_data';

import 'package:dart_zig/dart_zig.dart';

import 'sync_native.dart' if (dart.library.js_interop) 'sync_web.dart' as sync;

/// Map representation used by this application.
typedef Scores = Map<String, int>;

/// Set representation used by this application.
typedef Labels = Set<String>;

/// Array representation used by this application.
typedef Coordinates = List<double>;

/// Tuple representation used by this application.
typedef LabelledNumber = (String, BigInt);

/// Enumeration; declaration order determines wire tags.
enum Importance { low, normal, high }

/// Application message shared with Zig.
///
/// Collection and byte fields are retained by reference; this is not a deep copy.
final class SumArgs {
  /// Creates a message from its fields.
  const SumArgs({required this.a, required this.b});

  /// The `a` field encoded as `i64`.
  final int a;

  /// The `b` field encoded as `i64`.
  final int b;
}

/// Application message shared with Zig.
///
/// Collection and byte fields are retained by reference; this is not a deep copy.
final class Message {
  /// Creates a message from its fields.
  const Message({required this.text, required this.sequence});

  /// The `text` field encoded as `string`.
  final String text;

  /// The `sequence` field encoded as `i64`.
  final int sequence;
}

/// Application message shared with Zig.
///
/// Collection and byte fields are retained by reference; this is not a deep copy.
final class CountArgs {
  /// Creates a message from its fields.
  const CountArgs({required this.count});

  /// The `count` field encoded as `u32`.
  final int count;
}

/// Application message shared with Zig.
///
/// Collection and byte fields are retained by reference; this is not a deep copy.
final class CounterCreate {
  /// Creates a message from its fields.
  const CounterCreate({required this.initial});

  /// The `initial` field encoded as `i64`.
  final int initial;
}

/// Application message shared with Zig.
///
/// Collection and byte fields are retained by reference; this is not a deep copy.
final class CounterAdd {
  /// Creates a message from its fields.
  const CounterAdd({required this.handle, required this.delta});

  /// The `handle` field encoded as `u64`.
  final int handle;

  /// The `delta` field encoded as `i64`.
  final int delta;
}

/// Application message shared with Zig.
///
/// Collection and byte fields are retained by reference; this is not a deep copy.
final class HandleArgs {
  /// Creates a message from its fields.
  const HandleArgs({required this.handle});

  /// The `handle` field encoded as `u64`.
  final int handle;
}

/// Application message shared with Zig.
///
/// Collection and byte fields are retained by reference; this is not a deep copy.
final class TransformArgs {
  /// Creates a message from its fields.
  const TransformArgs({required this.callbackId, required this.value});

  /// The `callbackId` field encoded as `u32`.
  final int callbackId;

  /// The `value` field encoded as `i64`.
  final int value;
}

/// Application message shared with Zig.
///
/// Collection and byte fields are retained by reference; this is not a deep copy.
final class Record {
  /// Creates a message from its fields.
  const Record({
    required this.label,
    required this.tags,
    required this.score,
    required this.importance,
    required this.data,
    required this.flags,
  });

  /// The `label` field encoded as `string`.
  final String label;

  /// The `tags` field encoded as `string[]`.
  final List<String> tags;

  /// The `score` field encoded as `f64?`.
  final double? score;

  /// The `importance` field encoded as `Importance`.
  final Importance importance;

  /// The `data` field encoded as `bytes`.
  final Uint8List data;

  /// The `flags` field encoded as `bool[]`.
  final List<bool> flags;
}

/// Application message shared with Zig.
///
/// Collection and byte fields are retained by reference; this is not a deep copy.
final class RichValues {
  /// Creates a message from its fields.
  const RichValues({
    required this.scores,
    required this.labels,
    required this.coordinates,
    required this.pair,
    required this.huge,
    required this.small,
    required this.medium,
  });

  /// The `scores` field encoded as `Scores`.
  final Map<String, int> scores;

  /// The `labels` field encoded as `Labels`.
  final Set<String> labels;

  /// The `coordinates` field encoded as `Coordinates`.
  final List<double> coordinates;

  /// The `pair` field encoded as `LabelledNumber`.
  final (String, BigInt) pair;

  /// The `huge` field encoded as `u128`.
  final BigInt huge;

  /// The `small` field encoded as `i8`.
  final int small;

  /// The `medium` field encoded as `u16`.
  final int medium;
}

/// Tagged union; wire tags follow variant declaration order.
sealed class Value {
  const Value();
}

/// The `text` variant of [Value].
final class ValueText extends Value {
  const ValueText(this.value);
  final String value;
}

/// The `count` variant of [Value].
final class ValueCount extends Value {
  const ValueCount(this.value);
  final int value;
}

/// The `data` variant of [Value].
final class ValueData extends Value {
  const ValueData(this.value);
  final Uint8List value;
}

void _write0(BinaryWriter writer, List<double> value) {
  if (value.length != 3) throw RangeError("Wrong fixed array length");
  for (final item in value) {
    _write18(writer, item);
  }
}

List<double> _read0(BinaryReader reader) {
  final count = 3;
  return List.generate(count, (_) => _read18(reader));
}

void _write1(BinaryWriter writer, CountArgs value) {
  _write30(writer, value.count);
}

CountArgs _read1(BinaryReader reader) {
  return CountArgs(count: _read30(reader));
}

void _write2(BinaryWriter writer, CounterAdd value) {
  _write31(writer, value.handle);
  _write24(writer, value.delta);
}

CounterAdd _read2(BinaryReader reader) {
  return CounterAdd(handle: _read31(reader), delta: _read24(reader));
}

void _write3(BinaryWriter writer, CounterCreate value) {
  _write24(writer, value.initial);
}

CounterCreate _read3(BinaryReader reader) {
  return CounterCreate(initial: _read24(reader));
}

void _write4(BinaryWriter writer, HandleArgs value) {
  _write31(writer, value.handle);
}

HandleArgs _read4(BinaryReader reader) {
  return HandleArgs(handle: _read31(reader));
}

void _write5(BinaryWriter writer, Importance value) {
  writer.u32(value.index);
}

Importance _read5(BinaryReader reader) {
  final tag = reader.u32();
  if (tag >= 3) throw const FormatException("Invalid enum tag");
  return Importance.values[tag];
}

void _write6(BinaryWriter writer, (String, BigInt) value) {
  _write26(writer, value.$1);
  _write21(writer, value.$2);
}

(String, BigInt) _read6(BinaryReader reader) {
  return (_read26(reader), _read21(reader));
}

void _write7(BinaryWriter writer, Set<String> value) {
  if (value.length > 1000000) throw RangeError("Collection too large");
  writer.u32(value.length);
  for (final item in value) {
    _write26(writer, item);
  }
}

Set<String> _read7(BinaryReader reader) {
  final count = reader.collectionLength();
  final values = <String>{};
  for (var i = 0; i < count; i++) {
    if (!values.add(_read26(reader))) {
      throw const FormatException("Duplicate element");
    }
  }
  return values;
}

void _write8(BinaryWriter writer, Message value) {
  _write26(writer, value.text);
  _write24(writer, value.sequence);
}

Message _read8(BinaryReader reader) {
  return Message(text: _read26(reader), sequence: _read24(reader));
}

void _write9(BinaryWriter writer, Record value) {
  _write26(writer, value.label);
  _write27(writer, value.tags);
  _write20(writer, value.score);
  _write5(writer, value.importance);
  _write17(writer, value.data);
  _write16(writer, value.flags);
}

Record _read9(BinaryReader reader) {
  return Record(
    label: _read26(reader),
    tags: _read27(reader),
    score: _read20(reader),
    importance: _read5(reader),
    data: _read17(reader),
    flags: _read16(reader),
  );
}

void _write10(BinaryWriter writer, RichValues value) {
  _write11(writer, value.scores);
  _write7(writer, value.labels);
  _write0(writer, value.coordinates);
  _write6(writer, value.pair);
  _write28(writer, value.huge);
  _write25(writer, value.small);
  _write29(writer, value.medium);
}

RichValues _read10(BinaryReader reader) {
  return RichValues(
    scores: _read11(reader),
    labels: _read7(reader),
    coordinates: _read0(reader),
    pair: _read6(reader),
    huge: _read28(reader),
    small: _read25(reader),
    medium: _read29(reader),
  );
}

void _write11(BinaryWriter writer, Map<String, int> value) {
  if (value.length > 1000000) throw RangeError("Collection too large");
  writer.u32(value.length);
  for (final entry in value.entries) {
    _write26(writer, entry.key);
    _write23(writer, entry.value);
  }
}

Map<String, int> _read11(BinaryReader reader) {
  final count = reader.collectionLength();
  final values = <String, int>{};
  for (var i = 0; i < count; i++) {
    final key = _read26(reader);
    if (values.containsKey(key)) throw const FormatException("Duplicate key");
    values[key] = _read23(reader);
  }
  return values;
}

void _write12(BinaryWriter writer, SumArgs value) {
  _write24(writer, value.a);
  _write24(writer, value.b);
}

SumArgs _read12(BinaryReader reader) {
  return SumArgs(a: _read24(reader), b: _read24(reader));
}

void _write13(BinaryWriter writer, TransformArgs value) {
  _write30(writer, value.callbackId);
  _write24(writer, value.value);
}

TransformArgs _read13(BinaryReader reader) {
  return TransformArgs(callbackId: _read30(reader), value: _read24(reader));
}

void _write14(BinaryWriter writer, Value value) {
  switch (value) {
    case ValueText(:final value):
      writer.u32(0);
      _write26(writer, value);
    case ValueCount(:final value):
      writer.u32(1);
      _write24(writer, value);
    case ValueData(:final value):
      writer.u32(2);
      _write17(writer, value);
  }
}

Value _read14(BinaryReader reader) {
  return switch (reader.u32()) {
    0 => ValueText(_read26(reader)),
    1 => ValueCount(_read24(reader)),
    2 => ValueData(_read17(reader)),
    _ => throw const FormatException("Invalid union tag"),
  };
}

void _write15(BinaryWriter writer, bool value) {
  writer.boolean(value);
}

bool _read15(BinaryReader reader) {
  return reader.boolean();
}

void _write16(BinaryWriter writer, List<bool> value) {
  if (value.length > 1000000) throw RangeError("Collection too large");
  writer.u32(value.length);
  for (final item in value) {
    _write15(writer, item);
  }
}

List<bool> _read16(BinaryReader reader) {
  final count = reader.collectionLength();
  return List.generate(count, (_) => _read15(reader));
}

void _write17(BinaryWriter writer, Uint8List value) {
  writer.bytes(value);
}

Uint8List _read17(BinaryReader reader) {
  return reader.bytes();
}

void _write18(BinaryWriter writer, double value) {
  writer.f32(value);
}

double _read18(BinaryReader reader) {
  return reader.f32();
}

void _write19(BinaryWriter writer, double value) {
  writer.f64(value);
}

double _read19(BinaryReader reader) {
  return reader.f64();
}

void _write20(BinaryWriter writer, double? value) {
  writer.boolean(value != null);
  if (value != null) {
    _write19(writer, value);
  }
}

double? _read20(BinaryReader reader) {
  return reader.boolean() ? _read19(reader) : null;
}

void _write21(BinaryWriter writer, BigInt value) {
  writer.i128(value);
}

BigInt _read21(BinaryReader reader) {
  return reader.i128();
}

void _write23(BinaryWriter writer, int value) {
  writer.i32(value);
}

int _read23(BinaryReader reader) {
  return reader.i32();
}

void _write24(BinaryWriter writer, int value) {
  writer.i64(value);
}

int _read24(BinaryReader reader) {
  return reader.i64();
}

void _write25(BinaryWriter writer, int value) {
  writer.i8(value);
}

int _read25(BinaryReader reader) {
  return reader.i8();
}

void _write26(BinaryWriter writer, String value) {
  writer.string(value);
}

String _read26(BinaryReader reader) {
  return reader.string();
}

void _write27(BinaryWriter writer, List<String> value) {
  if (value.length > 1000000) throw RangeError("Collection too large");
  writer.u32(value.length);
  for (final item in value) {
    _write26(writer, item);
  }
}

List<String> _read27(BinaryReader reader) {
  final count = reader.collectionLength();
  return List.generate(count, (_) => _read26(reader));
}

void _write28(BinaryWriter writer, BigInt value) {
  writer.u128(value);
}

BigInt _read28(BinaryReader reader) {
  return reader.u128();
}

void _write29(BinaryWriter writer, int value) {
  writer.u16(value);
}

int _read29(BinaryReader reader) {
  return reader.u16();
}

void _write30(BinaryWriter writer, int value) {
  writer.u32(value);
}

int _read30(BinaryReader reader) {
  return reader.u32();
}

void _write31(BinaryWriter writer, int value) {
  writer.u64(value);
}

int _read31(BinaryReader reader) {
  return reader.u64();
}

void _read33(BinaryReader reader) {}

/// Checked binary conversion for [SumArgs].
///
/// Decoded byte fields borrow the input; copy them for independent mutation.
final class SumArgsCodec implements BinaryCodec<SumArgs> {
  const SumArgsCodec();
  @override
  Uint8List encode(SumArgs value) {
    final writer = BinaryWriter();
    _write12(writer, value);
    return writer.finish();
  }

  @override
  SumArgs decode(Uint8List bytes) {
    final reader = BinaryReader(bytes);
    final value = _read12(reader);
    reader.finish();
    return value;
  }
}

/// Checked binary conversion for [Message].
///
/// Decoded byte fields borrow the input; copy them for independent mutation.
final class MessageCodec implements BinaryCodec<Message> {
  const MessageCodec();
  @override
  Uint8List encode(Message value) {
    final writer = BinaryWriter();
    _write8(writer, value);
    return writer.finish();
  }

  @override
  Message decode(Uint8List bytes) {
    final reader = BinaryReader(bytes);
    final value = _read8(reader);
    reader.finish();
    return value;
  }
}

/// Checked binary conversion for [CountArgs].
///
/// Decoded byte fields borrow the input; copy them for independent mutation.
final class CountArgsCodec implements BinaryCodec<CountArgs> {
  const CountArgsCodec();
  @override
  Uint8List encode(CountArgs value) {
    final writer = BinaryWriter();
    _write1(writer, value);
    return writer.finish();
  }

  @override
  CountArgs decode(Uint8List bytes) {
    final reader = BinaryReader(bytes);
    final value = _read1(reader);
    reader.finish();
    return value;
  }
}

/// Checked binary conversion for [CounterCreate].
///
/// Decoded byte fields borrow the input; copy them for independent mutation.
final class CounterCreateCodec implements BinaryCodec<CounterCreate> {
  const CounterCreateCodec();
  @override
  Uint8List encode(CounterCreate value) {
    final writer = BinaryWriter();
    _write3(writer, value);
    return writer.finish();
  }

  @override
  CounterCreate decode(Uint8List bytes) {
    final reader = BinaryReader(bytes);
    final value = _read3(reader);
    reader.finish();
    return value;
  }
}

/// Checked binary conversion for [CounterAdd].
///
/// Decoded byte fields borrow the input; copy them for independent mutation.
final class CounterAddCodec implements BinaryCodec<CounterAdd> {
  const CounterAddCodec();
  @override
  Uint8List encode(CounterAdd value) {
    final writer = BinaryWriter();
    _write2(writer, value);
    return writer.finish();
  }

  @override
  CounterAdd decode(Uint8List bytes) {
    final reader = BinaryReader(bytes);
    final value = _read2(reader);
    reader.finish();
    return value;
  }
}

/// Checked binary conversion for [HandleArgs].
///
/// Decoded byte fields borrow the input; copy them for independent mutation.
final class HandleArgsCodec implements BinaryCodec<HandleArgs> {
  const HandleArgsCodec();
  @override
  Uint8List encode(HandleArgs value) {
    final writer = BinaryWriter();
    _write4(writer, value);
    return writer.finish();
  }

  @override
  HandleArgs decode(Uint8List bytes) {
    final reader = BinaryReader(bytes);
    final value = _read4(reader);
    reader.finish();
    return value;
  }
}

/// Checked binary conversion for [TransformArgs].
///
/// Decoded byte fields borrow the input; copy them for independent mutation.
final class TransformArgsCodec implements BinaryCodec<TransformArgs> {
  const TransformArgsCodec();
  @override
  Uint8List encode(TransformArgs value) {
    final writer = BinaryWriter();
    _write13(writer, value);
    return writer.finish();
  }

  @override
  TransformArgs decode(Uint8List bytes) {
    final reader = BinaryReader(bytes);
    final value = _read13(reader);
    reader.finish();
    return value;
  }
}

/// Checked binary conversion for [Record].
///
/// Decoded byte fields borrow the input; copy them for independent mutation.
final class RecordCodec implements BinaryCodec<Record> {
  const RecordCodec();
  @override
  Uint8List encode(Record value) {
    final writer = BinaryWriter();
    _write9(writer, value);
    return writer.finish();
  }

  @override
  Record decode(Uint8List bytes) {
    final reader = BinaryReader(bytes);
    final value = _read9(reader);
    reader.finish();
    return value;
  }
}

/// Checked binary conversion for [RichValues].
///
/// Decoded byte fields borrow the input; copy them for independent mutation.
final class RichValuesCodec implements BinaryCodec<RichValues> {
  const RichValuesCodec();
  @override
  Uint8List encode(RichValues value) {
    final writer = BinaryWriter();
    _write10(writer, value);
    return writer.finish();
  }

  @override
  RichValues decode(Uint8List bytes) {
    final reader = BinaryReader(bytes);
    final value = _read10(reader);
    reader.finish();
    return value;
  }
}

/// Checked binary conversion for [Value].
///
/// Decoded byte fields borrow the input; copy them for independent mutation.
final class ValueCodec implements BinaryCodec<Value> {
  const ValueCodec();
  @override
  Uint8List encode(Value value) {
    final writer = BinaryWriter();
    _write14(writer, value);
    return writer.finish();
  }

  @override
  Value decode(Uint8List bytes) {
    final reader = BinaryReader(bytes);
    final value = _read14(reader);
    reader.finish();
    return value;
  }
}

/// Checked binary conversion for [Scores].
///
/// Decoded byte fields borrow the input; copy them for independent mutation.
final class ScoresCodec implements BinaryCodec<Scores> {
  const ScoresCodec();
  @override
  Uint8List encode(Scores value) {
    final writer = BinaryWriter();
    _write11(writer, value);
    return writer.finish();
  }

  @override
  Scores decode(Uint8List bytes) {
    final reader = BinaryReader(bytes);
    final value = _read11(reader);
    reader.finish();
    return value;
  }
}

/// Checked binary conversion for [Labels].
///
/// Decoded byte fields borrow the input; copy them for independent mutation.
final class LabelsCodec implements BinaryCodec<Labels> {
  const LabelsCodec();
  @override
  Uint8List encode(Labels value) {
    final writer = BinaryWriter();
    _write7(writer, value);
    return writer.finish();
  }

  @override
  Labels decode(Uint8List bytes) {
    final reader = BinaryReader(bytes);
    final value = _read7(reader);
    reader.finish();
    return value;
  }
}

/// Checked binary conversion for [Coordinates].
///
/// Decoded byte fields borrow the input; copy them for independent mutation.
final class CoordinatesCodec implements BinaryCodec<Coordinates> {
  const CoordinatesCodec();
  @override
  Uint8List encode(Coordinates value) {
    final writer = BinaryWriter();
    _write0(writer, value);
    return writer.finish();
  }

  @override
  Coordinates decode(Uint8List bytes) {
    final reader = BinaryReader(bytes);
    final value = _read0(reader);
    reader.finish();
    return value;
  }
}

/// Checked binary conversion for [LabelledNumber].
///
/// Decoded byte fields borrow the input; copy them for independent mutation.
final class LabelledNumberCodec implements BinaryCodec<LabelledNumber> {
  const LabelledNumberCodec();
  @override
  Uint8List encode(LabelledNumber value) {
    final writer = BinaryWriter();
    _write6(writer, value);
    return writer.finish();
  }

  @override
  LabelledNumber decode(Uint8List bytes) {
    final reader = BinaryReader(bytes);
    final value = _read6(reader);
    reader.finish();
    return value;
  }
}

/// Typed facade for this application's routes, bound to one native session.
final class FeatureApi {
  /// Binds calls to [session].
  FeatureApi(this.session)
    : updates = SignalEndpoint(session, 100, const MessageCodec(), state: true);

  /// Session owning the application tasks, callbacks, and native objects.
  final NativeSession session;

  /// Adds two signed integers on a native worker.
  /// [timeout] covers admission and execution.
  Future<int> sum(SumArgs input, {Duration? timeout}) async {
    final writer = BinaryWriter();
    _write12(writer, input);
    final bytes = await session
        .call(1, writer.finish(), timeout: timeout)
        .result;
    final reader = BinaryReader(bytes);
    final value = _read24(reader);
    reader.finish();
    return value;
  }

  /// Publishes a typed message to current signal listeners.
  /// [timeout] covers admission and execution.
  Future<void> publish(Message input, {Duration? timeout}) async {
    final writer = BinaryWriter();
    _write8(writer, input);
    final bytes = await session
        .call(2, writer.finish(), timeout: timeout)
        .result;
    final reader = BinaryReader(bytes);
    _read33(reader);
    reader.finish();
  }

  /// Streams successive squares under subscription credit control.
  /// [timeout] covers admission and execution.
  Stream<int> squares(CountArgs input, {Duration? timeout}) {
    final writer = BinaryWriter();
    _write1(writer, input);
    return session.stream(3, writer.finish(), timeout: timeout).map((bytes) {
      final reader = BinaryReader(bytes);
      final value = _read24(reader);
      reader.finish();
      return value;
    });
  }

  /// Creates a session-owned counter and returns its opaque handle.
  /// [timeout] covers admission and execution.
  Future<int> counterCreate(CounterCreate input, {Duration? timeout}) async {
    final writer = BinaryWriter();
    _write3(writer, input);
    final bytes = await session
        .call(4, writer.finish(), timeout: timeout)
        .result;
    final reader = BinaryReader(bytes);
    final value = _read31(reader);
    reader.finish();
    return value;
  }

  /// Atomically updates a counter identified by a live handle.
  /// [timeout] covers admission and execution.
  Future<int> counterAdd(CounterAdd input, {Duration? timeout}) async {
    final writer = BinaryWriter();
    _write2(writer, input);
    final bytes = await session
        .call(5, writer.finish(), timeout: timeout)
        .result;
    final reader = BinaryReader(bytes);
    final value = _read24(reader);
    reader.finish();
    return value;
  }

  /// Removes a native counter handle; stale handles fail.
  /// [timeout] covers admission and execution.
  Future<void> counterDispose(HandleArgs input, {Duration? timeout}) async {
    final writer = BinaryWriter();
    _write4(writer, input);
    final bytes = await session
        .call(6, writer.finish(), timeout: timeout)
        .result;
    final reader = BinaryReader(bytes);
    _read33(reader);
    reader.finish();
  }

  /// Requests a registered Dart callback and resumes on its result.
  /// [timeout] covers admission and execution.
  Future<int> transform(TransformArgs input, {Duration? timeout}) async {
    final writer = BinaryWriter();
    _write13(writer, input);
    final bytes = await session
        .call(7, writer.finish(), timeout: timeout)
        .result;
    final reader = BinaryReader(bytes);
    final value = _read24(reader);
    reader.finish();
    return value;
  }

  /// Invokes [transform] with a scoped callback registration.
  Future<int> transformWith({
    required int value,
    required FutureOr<int> Function(int) callback,
    Duration? timeout,
  }) async {
    final id = registerIntTransform(callback);
    try {
      return await transform(
        TransformArgs(callbackId: id, value: value),
        timeout: timeout,
      );
    } finally {
      session.unregisterCallback(id);
    }
  }

  /// Returns the submitted bytes through the native transport.
  /// [timeout] covers admission and execution.
  Future<Uint8List> echo(Uint8List input, {Duration? timeout}) async {
    final writer = BinaryWriter();
    _write17(writer, input);
    final bytes = await session
        .call(8, writer.finish(), timeout: timeout)
        .result;
    final reader = BinaryReader(bytes);
    final value = _read17(reader);
    reader.finish();
    return value;
  }

  /// Round-trips a structured record through the native codec.
  /// [timeout] covers admission and execution.
  Future<Record> roundTripRecord(Record input, {Duration? timeout}) async {
    final writer = BinaryWriter();
    _write9(writer, input);
    final bytes = await session
        .call(9, writer.finish(), timeout: timeout)
        .result;
    final reader = BinaryReader(bytes);
    final value = _read9(reader);
    reader.finish();
    return value;
  }

  /// Round-trips a tagged union through the native codec.
  /// [timeout] covers admission and execution.
  Future<Value> roundTripValue(Value input, {Duration? timeout}) async {
    final writer = BinaryWriter();
    _write14(writer, input);
    final bytes = await session
        .call(10, writer.finish(), timeout: timeout)
        .result;
    final reader = BinaryReader(bytes);
    final value = _read14(reader);
    reader.finish();
    return value;
  }

  /// Attempts to publish a best-effort structured native log.
  /// [timeout] covers admission and execution.
  Future<void> emitLog(Message input, {Duration? timeout}) async {
    final writer = BinaryWriter();
    _write8(writer, input);
    final bytes = await session
        .call(11, writer.finish(), timeout: timeout)
        .result;
    final reader = BinaryReader(bytes);
    _read33(reader);
    reader.finish();
  }

  /// Invokes the `roundTripRich` operation.
  /// [timeout] covers admission and execution.
  Future<RichValues> roundTripRich(
    RichValues input, {
    Duration? timeout,
  }) async {
    final writer = BinaryWriter();
    _write10(writer, input);
    final bytes = await session
        .call(12, writer.finish(), timeout: timeout)
        .result;
    final reader = BinaryReader(bytes);
    final value = _read10(reader);
    reader.finish();
    return value;
  }

  /// Registers a typed callback; unregister its ID through [session] when done.
  int registerIntTransform(FutureOr<int> Function(int) callback) =>
      session.registerCallback((bytes) async {
        final reader = BinaryReader(bytes);
        final input = _read24(reader);
        reader.finish();
        final result = await callback(input);
        final writer = BinaryWriter(maxBytes: session.maxBytes);
        _write24(writer, result);
        return writer.finish();
      });

  /// Executes the short native operation synchronously on the Dart thread.
  int sumSync(int a, int b) => sync.sumSync(session, a, b);

  /// Typed broadcast events; subscribe before invoking an emitter.
  Stream<Message> get messages => session.signals
      .where((event) => event.route == 1)
      .map((event) => const MessageCodec().decode(event.bytes));

  /// Session-scoped bidirectional endpoint; dispose received packs.
  final SignalEndpoint<Message> updates;
}
