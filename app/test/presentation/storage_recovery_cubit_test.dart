import 'package:bloc_test/bloc_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_cubit.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_state.dart';

/// Never opens — every statement throws, simulating an unavailable
/// database (e.g. permission denied, corrupted file).
class _FailingExecutor extends QueryExecutor {
  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => throw Exception('cannot open database');

  @override
  Future<List<Map<String, Object?>>> runSelect(String statement, List<Object?> args) =>
      throw UnimplementedError();

  @override
  Future<int> runInsert(String statement, List<Object?> args) => throw UnimplementedError();

  @override
  Future<int> runUpdate(String statement, List<Object?> args) => throw UnimplementedError();

  @override
  Future<int> runDelete(String statement, List<Object?> args) => throw UnimplementedError();

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) =>
      throw Exception('cannot open database');

  @override
  Future<void> runBatched(BatchedStatements statements) => throw UnimplementedError();

  @override
  TransactionExecutor beginTransaction() => throw UnimplementedError();

  @override
  QueryExecutor beginExclusive() => this;

  @override
  Future<void> close() async {}
}

void main() {
  const cause = DatabaseFailure(null, code: DatabaseFailure.storageUnavailable);

  group('constructed already failed to open', () {
    blocTest<StorageRecoveryCubit, StorageRecoveryState>(
      'starts in idle(cause)',
      build: () => StorageRecoveryCubit(
        createDatabase: () => AppDatabase(NativeDatabase.memory()),
        initialState: const StorageRecoveryState.idle(cause: cause),
      ),
      verify: (cubit) => expect(cubit.state, const StorageRecoveryState.idle(cause: cause)),
    );
  });

  group('retry', () {
    blocTest<StorageRecoveryCubit, StorageRecoveryState>(
      'a working database emits working() then recovered()',
      build: () => StorageRecoveryCubit(
        createDatabase: () => AppDatabase(NativeDatabase.memory()),
        initialState: const StorageRecoveryState.idle(cause: cause),
      ),
      act: (cubit) => cubit.retry(),
      expect: () => [
        const StorageRecoveryState.working(),
        isA<StorageRecoveryRecovered>(),
      ],
    );

    blocTest<StorageRecoveryCubit, StorageRecoveryState>(
      'a still-broken database goes back to idle(cause), not an exception',
      build: () => StorageRecoveryCubit(
        createDatabase: () => AppDatabase(_FailingExecutor()),
        initialState: const StorageRecoveryState.idle(cause: cause),
      ),
      act: (cubit) => cubit.retry(),
      expect: () => [
        const StorageRecoveryState.working(),
        isA<StorageRecoveryIdle>(),
      ],
    );

    test('does not emit after the cubit is closed', () async {
      final cubit = StorageRecoveryCubit(
        createDatabase: () => AppDatabase(NativeDatabase.memory()),
        initialState: const StorageRecoveryState.idle(cause: cause),
      );
      final future = cubit.retry();
      await cubit.close();
      expect(cubit.isClosed, isTrue);
      await future;
    });
  });

  group('resetData', () {
    blocTest<StorageRecoveryCubit, StorageRecoveryState>(
      // No path_provider platform-channel handler is registered in this
      // test environment, so AppBootstrap.resetData() itself fails — that
      // stands in for a real-world reset failure (e.g. permission denied).
      'a failed reset lands on error(), not idle()',
      build: () => StorageRecoveryCubit(
        createDatabase: () => AppDatabase(NativeDatabase.memory()),
        initialState: const StorageRecoveryState.idle(cause: cause),
      ),
      act: (cubit) => cubit.resetData(),
      expect: () => [
        const StorageRecoveryState.working(),
        isA<StorageRecoveryError>(),
      ],
    );

    blocTest<StorageRecoveryCubit, StorageRecoveryState>(
      'after a failed reset, retry/continueWithoutSaving are still reachable',
      build: () => StorageRecoveryCubit(
        createDatabase: () => AppDatabase(NativeDatabase.memory()),
        initialState: const StorageRecoveryState.idle(cause: cause),
      ),
      act: (cubit) async {
        await cubit.resetData();
        cubit.continueWithoutSaving();
      },
      expect: () => [
        const StorageRecoveryState.working(),
        isA<StorageRecoveryError>(),
        const StorageRecoveryState.readOnlyAccepted(),
      ],
    );
  });

  group('continueWithoutSaving', () {
    blocTest<StorageRecoveryCubit, StorageRecoveryState>(
      'emits readOnlyAccepted() immediately, no async work',
      build: () => StorageRecoveryCubit(
        createDatabase: () => AppDatabase(NativeDatabase.memory()),
        initialState: const StorageRecoveryState.idle(cause: cause),
      ),
      act: (cubit) => cubit.continueWithoutSaving(),
      expect: () => [const StorageRecoveryState.readOnlyAccepted()],
    );
  });
}
