import 'package:daily_bread/presentation/utils/sync_diagnostics_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildSyncDiagnosticsText', () {
    test('includes diagnostics version as first line', () {
      final diagnostics = buildSyncDiagnosticsText(
        backend: 'Firebase',
        status: 'failed',
        health: 'Critical',
        isOffline: false,
        category: 'Permission',
        code: 'permission-denied',
        retryAttempts: 1,
        successes: 0,
        failures: 1,
        retriesScheduled: 0,
        lastAttemptAt: DateTime(2026, 4, 26, 10, 15, 30),
        lastSuccessAt: null,
        lastOutcome: 'failure',
        lastOutcomeAt: DateTime(2026, 4, 26, 10, 15, 30),
        nextRetryAt: null,
        error: '[cloud_functions/permission-denied] permission denied',
      );

      expect(diagnostics.startsWith('Diagnostics Version: 1\n'), isTrue);
      expect(diagnostics, contains('Backend: Firebase'));
      expect(diagnostics, contains('Status: failed'));
    });

    test('formats reset-state diagnostics cleanly', () {
      final diagnostics = buildSyncDiagnosticsText(
        backend: 'Firebase',
        status: 'idle',
        health: 'Unknown',
        isOffline: false,
        category: 'None',
        code: 'unknown',
        retryAttempts: 0,
        successes: 0,
        failures: 0,
        retriesScheduled: 0,
        lastAttemptAt: null,
        lastSuccessAt: null,
        lastOutcome: null,
        lastOutcomeAt: null,
        nextRetryAt: null,
        error: 'N/A',
      );

      expect(diagnostics, contains('Diagnostics Version: 1'));
      expect(diagnostics, contains('Status: idle'));
      expect(diagnostics, contains('Health: Unknown'));
      expect(diagnostics, contains('Last attempt: N/A'));
      expect(diagnostics, contains('Last success: N/A'));
      expect(diagnostics, contains('Last outcome: N/A'));
      expect(diagnostics, contains('Next retry: N/A'));
      expect(diagnostics, contains('Error: N/A'));
    });
  });

  group('redactSyncDiagnosticsText', () {
    test('masks bearer authorization values', () {
      const source =
          'Error: Authorization: Bearer abcdefghijklmnopqrstuvwxyz1234567890';

      final redacted = redactSyncDiagnosticsText(source);

      expect(redacted, isNot(contains('abcdefghijklmnopqrstuvwxyz1234567890')));
      expect(redacted, contains('Authorization: Bearer abcd...7890'));
    });

    test('masks token-like key-value pairs', () {
      const source =
          'Error: apiKey=myVerySensitiveSecretValue9876543210 token=anotherSecretToken1234567890';

      final redacted = redactSyncDiagnosticsText(source);

      expect(redacted, contains('apiKey=myVe...3210'));
      expect(redacted, contains('token=anot...7890'));
      expect(redacted, isNot(contains('myVerySensitiveSecretValue9876543210')));
      expect(redacted, isNot(contains('anotherSecretToken1234567890')));
    });

    test('keeps normal diagnostics context readable', () {
      const source =
          'Status: failed\nCategory: Permission\nCode: permission-denied';

      final redacted = redactSyncDiagnosticsText(source);

      expect(redacted, contains('Status: failed'));
      expect(redacted, contains('Category: Permission'));
      expect(redacted, contains('Code: permission-denied'));
    });

    test('preserves diagnostics version line while redacting secrets', () {
      const source =
          'Diagnostics Version: 1\nError: Authorization: Bearer abcdefghijklmnopqrstuvwxyz1234567890';

      final redacted = redactSyncDiagnosticsText(source);

      expect(redacted, contains('Diagnostics Version: 1'));
      expect(redacted, contains('Authorization: Bearer abcd...7890'));
      expect(redacted, isNot(contains('abcdefghijklmnopqrstuvwxyz1234567890')));
    });
  });
}
