import 'dart:async';

import 'codec.dart';
import 'session.dart';

/// A typed native call that can be cancelled while it is pending.
final class TypedCall<T> {
  /// Wraps an operation result and its cancellation action.
  const TypedCall(this.result, this.cancel);

  /// The decoded result or an operation failure.
  final Future<T> result;

  /// Requests cancellation of a pending operation.
  final void Function() cancel;
}

/// A typed route for asynchronous request and response messages.
///
/// The application owns [input] and [output]. Each codec defines one complete
/// message; callers work with Dart values while the session carries bytes.
///
/// {@example /example/calls_example/bin/main.dart#typed-call}
final class CallEndpoint<I, O> {
  /// Binds codecs and [route] to one [session].
  const CallEndpoint(this.session, this.route, this.input, this.output);

  /// Session that owns the native operation.
  final NativeSession session;

  /// Application-defined route number.
  final int route;

  /// Codec for requests sent to Zig.
  final MessageEncoder<I> input;

  /// Codec for responses returned to Dart.
  final MessageDecoder<O> output;

  /// Starts an operation and exposes cancellation.
  TypedCall<O> start(I request, {Duration? timeout}) {
    final call = session.call(route, input.encode(request), timeout: timeout);
    return TypedCall(call.result.then(output.decode), call.cancel);
  }

  /// Returns the decoded response when the operation completes.
  Future<O> call(I request, {Duration? timeout}) =>
      start(request, timeout: timeout).result;
}

/// A typed route for a credited native stream.
///
/// Pausing and cancelling the Dart subscription propagate to the session.
///
/// {@example /example/streams_example/bin/main.dart#typed-stream-endpoint}
final class StreamEndpoint<I, O> {
  /// Binds codecs and [route] to one [session].
  const StreamEndpoint(this.session, this.route, this.input, this.output);

  /// Session that owns the native stream.
  final NativeSession session;

  /// Application-defined route number.
  final int route;

  /// Codec for stream requests sent to Zig.
  final MessageEncoder<I> input;

  /// Codec for stream items returned to Dart.
  final MessageDecoder<O> output;

  /// Opens the stream when a listener subscribes.
  Stream<O> open(I request, {Duration? timeout}) => session
      .stream(route, input.encode(request), timeout: timeout)
      .map(output.decode);
}

/// Creates typed endpoints for one native session.
extension TypedSessionEndpoints on NativeSession {
  /// Binds a request and response codec to [route].
  CallEndpoint<I, O> callEndpoint<I, O>({
    required int route,
    required MessageEncoder<I> input,
    required MessageDecoder<O> output,
  }) => CallEndpoint(this, route, input, output);

  /// Binds a stream request and item codec to [route].
  StreamEndpoint<I, O> streamEndpoint<I, O>({
    required int route,
    required MessageEncoder<I> input,
    required MessageDecoder<O> output,
  }) => StreamEndpoint(this, route, input, output);
}
