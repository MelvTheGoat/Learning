import 'dart:convert';
import 'dart:io';

import 'package:dartcodeai_ml_systems_practical/gateway_normalizer.dart';
import 'package:test/test.dart';

Map<String, dynamic> fixture(String name) {
  final file = File('../fixtures/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('GatewayNormalizer', () {
    test('normalizes the supplied OpenAI-compatible success fixture', () {
      final result = GatewayNormalizer().normalizeSuccess(
        requestId: 'request-visible-1',
        providerId: 'hosted_primary',
        payload: fixture('provider_openai_success.json'),
        routingMetadata: const {'routeKey': 'chat.completions'},
        completedAt: DateTime.utc(2026, 8, 15, 12),
      );

      expect(result.text, 'A concise normalized answer.');
      expect(result.usage.totalTokens, 18);
      expect(result.metadata['routeKey'], 'chat.completions');
    });

    test('does not fallback after authentication failure', () {
      final failure = CanonicalFailure(
        code: CanonicalErrorCode.authError,
        message: 'Provider authentication failed.',
        httpStatusCode: 401,
        retryable: false,
        failoverEligible: false,
        providerId: 'hosted_primary',
      );

      final decision = GatewayNormalizer().decideFallback(
        failure: failure,
        hasConfiguredFallback: true,
        alreadyAttemptedFallback: false,
        fallbackIsDifferentProviderOrModel: true,
      );

      expect(decision.shouldFallback, isFalse);
    });
  });
}
