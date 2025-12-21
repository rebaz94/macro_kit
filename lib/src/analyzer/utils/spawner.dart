import 'dart:async';
import 'dart:isolate';

class Spawner {
  Spawner._();

  /// Spawns an isolate to execute code from [codeUri] and returns the first result.
  ///
  /// This method creates a new isolate, executes the code at [codeUri], receives
  /// the first data sent back from the isolate, and then automatically terminates
  /// the isolate.
  ///
  /// ## Parameters
  ///
  /// * [codeUri] - URI pointing to a Dart file containing a valid `main` entrypoint.
  ///   The main function must accept a `List<String>` for arguments and a `SendPort`
  ///   for sending results back to the parent isolate.
  ///
  /// * [onData] - Callback function that transforms the received data into type [T].
  ///   This function should throw an exception if the data cannot be mapped to [T],
  ///   which will result in a [SpawnError] being returned.
  ///
  /// * [debugName] - Optional name for debugging purposes to identify the isolate.
  ///
  /// ## Code Requirements
  ///
  /// The code at [codeUri] must follow this structure:
  ///
  /// ```dart
  /// void main(List<String> args, SendPort port) {
  ///   // Perform computation
  ///   final result = {'key': 'value', 'count': 42};
  ///
  ///   // Send result once to parent isolate
  ///   port.send(result);
  /// }
  /// ```
  ///
  /// ## Usage Example
  ///
  /// ```dart
  /// final result = await evaluateCode<Map<String, dynamic>>(
  ///   codeUri: Uri.file('/project/lib/workers/data_processor.dart'),
  ///   onData: (data) {
  ///     if (data is! Map<String, dynamic>) {
  ///       throw FormatException('Expected Map, got ${data.runtimeType}');
  ///     }
  ///     return data;
  ///   },
  ///   debugName: 'DataProcessor',
  /// );
  ///
  /// switch(result) {
  ///   case SpawnData<Map<String, dynamic>:
  ///     print('Received: ${result.data}');
  ///   case SpawnError<Map<String, dynamic>:
  ///     print('Failed: ${result.error}'),
  /// }
  /// ```
  ///
  /// ## Returns
  ///
  /// A [SpawnResult<T>] which contains either:
  /// * The successfully mapped data of type [T]
  /// * A [SpawnError] if the isolate failed to spawn, the data couldn't be mapped,
  ///   or any other error occurred during execution
  ///
  /// ## Notes
  ///
  /// * The isolate is automatically terminated after receiving the first message
  /// * Only the **first** message sent from the isolate will be processed
  /// * Any subsequent messages sent by the isolate will be ignored
  /// * Exceptions thrown in [onData] will be caught and returned as [SpawnError]
  static Future<SpawnResult<T>> evaluateCode<T>({
    required Uri codeUri,
    required T Function(Object? data) onData,
    String? debugName,
  }) async {
    final result = Completer<SpawnResult<T>>();
    final resultPort = RawReceivePort();
    Isolate? isolate;

    // some logic got from [Isolate.run]
    resultPort.handler = (response) {
      if (result.isCompleted) return;

      resultPort.close();
      isolate?.kill();
      if (response == null) {
        // onExit handler message, isolate terminated without sending result.
        return result.complete(
          SpawnError(
            RemoteError('Evaluation ended without result', ''),
            StackTrace.empty,
          ),
        );
      }

      if (response is List<Object?> && response.length == 2) {
        var remoteError = response[0];
        var remoteStack = response[1];
        if (remoteStack is StackTrace) {
          result.complete(SpawnError(remoteError!, remoteStack));
        } else {
          var error = RemoteError(
            remoteError.toString(),
            remoteStack.toString(),
          );
          result.complete(SpawnError(error, error.stackTrace));
        }
      } else {
        try {
          result.complete(SpawnData(data: onData(response)));
        } catch (e, s) {
          result.complete(SpawnError(e, s));
        }
      }
    };

    try {
      Isolate.spawnUri(
        codeUri,
        [],
        resultPort.sendPort,
        onError: resultPort.sendPort,
        onExit: resultPort.sendPort,
        errorsAreFatal: true,
        debugName: debugName ?? codeUri.toString(),
      ).then<void>(
        (value) => isolate = value,
        onError: (e, s) async {
          resultPort.close();
          isolate?.kill();
          if (!result.isCompleted) {
            result.complete(SpawnError(e, s));
          }
        },
      );
    } on Object catch (e, s) {
      resultPort.close();
      result.complete(SpawnError(e, s));
    }

    return result.future;
  }
}

sealed class SpawnResult<T> {
  const SpawnResult();
}

class SpawnError<T> extends SpawnResult<T> {
  const SpawnError(this.error, this.trace);

  final Object error;
  final StackTrace? trace;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpawnError && runtimeType == other.runtimeType && error == other.error && trace == other.trace;

  @override
  int get hashCode => error.hashCode ^ trace.hashCode;

  @override
  String toString() {
    return 'SpawnError{error: $error, trace: $trace}';
  }
}

class SpawnData<T> extends SpawnResult<T> {
  const SpawnData({required this.data});

  final T data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SpawnData && runtimeType == other.runtimeType && data == other.data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() {
    return 'SpawnData{data: $data}';
  }
}
