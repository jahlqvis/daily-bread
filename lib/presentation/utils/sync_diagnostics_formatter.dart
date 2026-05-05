import 'package:intl/intl.dart';

const int syncDiagnosticsVersion = 1;

String buildSyncDiagnosticsText({
  required String backend,
  required String authState,
  required String status,
  required String health,
  required bool isOffline,
  required String category,
  required String code,
  required int retryAttempts,
  required int successes,
  required int failures,
  required int retriesScheduled,
  DateTime? lastAttemptAt,
  DateTime? lastSuccessAt,
  String? lastOutcome,
  DateTime? lastOutcomeAt,
  DateTime? nextRetryAt,
  required String error,
}) {
  final formatter = DateFormat('MMM d, HH:mm:ss');
  final outcomeLine = lastOutcome == null || lastOutcomeAt == null
      ? 'N/A'
      : '$lastOutcome at ${formatter.format(lastOutcomeAt)}';

  return [
    'Diagnostics Version: $syncDiagnosticsVersion',
    'Backend: $backend',
    'Auth State: $authState',
    'Status: $status',
    'Health: $health',
    'Offline: $isOffline',
    'Category: $category',
    'Code: $code',
    'Retry attempts: $retryAttempts',
    'Successes: $successes',
    'Failures: $failures',
    'Retries scheduled: $retriesScheduled',
    'Last attempt: ${lastAttemptAt == null ? 'N/A' : formatter.format(lastAttemptAt)}',
    'Last success: ${lastSuccessAt == null ? 'N/A' : formatter.format(lastSuccessAt)}',
    'Last outcome: $outcomeLine',
    'Next retry: ${nextRetryAt == null ? 'N/A' : formatter.format(nextRetryAt)}',
    'Error: $error',
  ].join('\n');
}

String redactSyncDiagnosticsText(String input) {
  var redacted = input;

  redacted = redacted.replaceAllMapped(
    RegExp(
      r'(authorization\s*:\s*bearer\s+)([A-Za-z0-9._\-+/=]{8,})',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}${_maskSecret(match.group(2)!)}',
  );

  redacted = redacted.replaceAllMapped(
    RegExp(
      r'((?:api[_-]?key|token|access[_-]?token|refresh[_-]?token|secret|password)\s*[:=]\s*)([^\s,;]+)',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}${_maskSecret(match.group(2)!)}',
  );

  redacted = redacted.replaceAllMapped(
    RegExp(
      r'((?:api[_-]?key|token|secret|password)=)([^&\s]+)',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}${_maskSecret(match.group(2)!)}',
  );

  redacted = redacted.replaceAllMapped(
    RegExp(r'(?<![A-Za-z0-9])[A-Za-z0-9_\-]{32,}(?![A-Za-z0-9])'),
    (match) {
      final candidate = match.group(0)!;
      if (_looksLikeSecret(candidate)) {
        return _maskSecret(candidate);
      }
      return candidate;
    },
  );

  return redacted;
}

bool _looksLikeSecret(String value) {
  if (value.length < 32) {
    return false;
  }
  final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
  final hasDigit = RegExp(r'[0-9]').hasMatch(value);
  return hasLetter && hasDigit;
}

String _maskSecret(String value) {
  if (value.length <= 8) {
    return '***';
  }
  final prefix = value.substring(0, 4);
  final suffix = value.substring(value.length - 4);
  return '$prefix...$suffix';
}
