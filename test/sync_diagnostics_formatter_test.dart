import 'package:daily_bread/presentation/utils/sync_diagnostics_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
  });
}
