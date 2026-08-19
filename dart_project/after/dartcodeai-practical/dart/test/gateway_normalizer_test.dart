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
    // ── Supplied tests (must keep passing) ──

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

    // ── A1: Additional normalizeSuccess tests ──

    test('normalizes the internal provider success fixture', () {
      final result = GatewayNormalizer().normalizeSuccess(
        requestId: 'request-visible-2',
        providerId: 'self_hosted_candidate',
        payload: fixture('provider_internal_success.json'),
        routingMetadata: const {'routeKey': 'internal.inference'},
        completedAt: DateTime.utc(2026, 8, 15, 13),
      );

      expect(result.text, 'Internal provider result.');
      expect(result.usage.promptTokens, 9);
      expect(result.usage.completionTokens, 4);
      expect(result.usage.totalTokens, 13);
      expect(result.finishReason, 'stop');
      expect(result.requestId, 'request-visible-2');
      expect(result.providerId, 'self_hosted_candidate');
      expect(result.metadata['routeKey'], 'internal.inference');
    });

    test('OpenAI success preserves all token fields', () {
      final result = GatewayNormalizer().normalizeSuccess(
        requestId: 'r-token-check',
        providerId: 'hosted_primary',
        payload: fixture('provider_openai_success.json'),
        routingMetadata: const {},
        completedAt: DateTime.utc(2026, 8, 15, 12),
      );

      expect(result.usage.promptTokens, 11);
      expect(result.usage.completionTokens, 7);
      expect(result.usage.totalTokens, 18);
      expect(result.finishReason, 'stop');
    });

    test('completedAt is stored as UTC', () {
      // Even if local time is passed, the normalizer should store UTC.
      final localTime = DateTime(2026, 8, 15, 15, 30);
      final result = GatewayNormalizer().normalizeSuccess(
        requestId: 'r-utc',
        providerId: 'hosted_primary',
        payload: fixture('provider_openai_success.json'),
        routingMetadata: const {},
        completedAt: localTime,
      );

      expect(result.completedAt.isUtc, isTrue);
    });

    test('throws FormatException for malformed payload (empty choices)', () {
      expect(
        () => GatewayNormalizer().normalizeSuccess(
          requestId: 'r-malformed',
          providerId: 'hosted_primary',
          payload: fixture('provider_malformed_success.json'),
          routingMetadata: const {},
          completedAt: DateTime.utc(2026, 8, 15, 12),
        ),
        throwsFormatException,
      );
    });

    test('throws FormatException for unrecognized response shape', () {
      expect(
        () => GatewayNormalizer().normalizeSuccess(
          requestId: 'r-unknown',
          providerId: 'unknown_provider',
          payload: const {'some': 'unexpected structure'},
          routingMetadata: const {},
          completedAt: DateTime.utc(2026, 8, 15, 12),
        ),
        throwsFormatException,
      );
    });

    // ── A2: normalizeFailure tests ──

    test('maps 429 to rate_limited', () {
      final f = GatewayNormalizer().normalizeFailure(
        providerId: 'hosted_primary',
        upstreamStatusCode: 429,
        payload: null,
        timedOut: false,
      );

      expect(f.code, CanonicalErrorCode.rateLimited);
      expect(f.httpStatusCode, 429);
      expect(f.retryable, isTrue);
      expect(f.failoverEligible, isFalse);
    });

    test('maps 413 to context_length_exceeded', () {
      final f = GatewayNormalizer().normalizeFailure(
        providerId: 'hosted_primary',
        upstreamStatusCode: 413,
        payload: null,
        timedOut: false,
      );

      expect(f.code, CanonicalErrorCode.contextLengthExceeded);
      expect(f.httpStatusCode, 413);
      expect(f.retryable, isFalse);
      expect(f.failoverEligible, isFalse);
    });

    test('maps 401 to auth_error', () {
      final f = GatewayNormalizer().normalizeFailure(
        providerId: 'hosted_primary',
        upstreamStatusCode: 401,
        payload: null,
        timedOut: false,
      );

      expect(f.code, CanonicalErrorCode.authError);
      expect(f.httpStatusCode, 401);
      expect(f.retryable, isFalse);
      expect(f.failoverEligible, isFalse);
    });

    test('maps 403 to auth_error', () {
      final f = GatewayNormalizer().normalizeFailure(
        providerId: 'hosted_primary',
        upstreamStatusCode: 403,
        payload: null,
        timedOut: false,
      );

      expect(f.code, CanonicalErrorCode.authError);
      expect(f.httpStatusCode, 401);
    });

    test('maps content_filtered error code from payload', () {
      final f = GatewayNormalizer().normalizeFailure(
        providerId: 'hosted_primary',
        upstreamStatusCode: 400,
        payload: fixture('provider_content_filter.json'),
        timedOut: false,
      );

      expect(f.code, CanonicalErrorCode.contentFiltered);
      expect(f.httpStatusCode, 422);
      expect(f.retryable, isFalse);
      expect(f.failoverEligible, isFalse);
    });

    test(
      'content filter error message never contains authorization credentials',
      () {
        final f = GatewayNormalizer().normalizeFailure(
          providerId: 'hosted_primary',
          upstreamStatusCode: 400,
          payload: fixture('provider_content_filter.json'),
          timedOut: false,
        );

        // The authorization field "Bearer do-not-copy-this-field" must NEVER
        // appear in the message, toJson(), or any other normalized output.
        final json = f.toJson();
        final jsonString = jsonEncode(json);
        expect(jsonString, isNot(contains('do-not-copy-this-field')));
        expect(jsonString, isNot(contains('Bearer')));
        expect(jsonString, isNot(contains('authorization')));
        expect(f.message, isNot(contains('do-not-copy-this-field')));
      },
    );

    test('maps timedOut=true to timeout', () {
      final f = GatewayNormalizer().normalizeFailure(
        providerId: 'hosted_primary',
        upstreamStatusCode: null,
        payload: null,
        timedOut: true,
      );

      expect(f.code, CanonicalErrorCode.timeout);
      expect(f.httpStatusCode, 504);
      expect(f.retryable, isTrue);
      expect(f.failoverEligible, isTrue);
    });

    test('maps 504 to timeout', () {
      final f = GatewayNormalizer().normalizeFailure(
        providerId: 'hosted_primary',
        upstreamStatusCode: 504,
        payload: null,
        timedOut: false,
      );

      expect(f.code, CanonicalErrorCode.timeout);
      expect(f.httpStatusCode, 504);
      expect(f.retryable, isTrue);
      expect(f.failoverEligible, isTrue);
    });

    test('maps 500 to provider_unavailable', () {
      final f = GatewayNormalizer().normalizeFailure(
        providerId: 'hosted_primary',
        upstreamStatusCode: 500,
        payload: null,
        timedOut: false,
      );

      expect(f.code, CanonicalErrorCode.providerUnavailable);
      expect(f.httpStatusCode, 503);
      expect(f.retryable, isTrue);
      expect(f.failoverEligible, isTrue);
    });

    test('maps 503 to provider_unavailable', () {
      final f = GatewayNormalizer().normalizeFailure(
        providerId: 'hosted_primary',
        upstreamStatusCode: 503,
        payload: null,
        timedOut: false,
      );

      expect(f.code, CanonicalErrorCode.providerUnavailable);
      expect(f.httpStatusCode, 503);
      expect(f.retryable, isTrue);
      expect(f.failoverEligible, isTrue);
    });

    test('maps unrecognized status code to invalid_provider_response', () {
      final f = GatewayNormalizer().normalizeFailure(
        providerId: 'hosted_primary',
        upstreamStatusCode: 418,
        payload: null,
        timedOut: false,
      );

      expect(f.code, CanonicalErrorCode.invalidProviderResponse);
      expect(f.httpStatusCode, 502);
      expect(f.retryable, isFalse);
      expect(f.failoverEligible, isFalse);
    });

    test('maps null status code and no timeout to invalid_provider_response',
        () {
      final f = GatewayNormalizer().normalizeFailure(
        providerId: 'hosted_primary',
        upstreamStatusCode: null,
        payload: null,
        timedOut: false,
      );

      expect(f.code, CanonicalErrorCode.invalidProviderResponse);
      expect(f.httpStatusCode, 502);
    });

    // ── A3: decideFallback tests ──

    test('permits fallback for timeout with all conditions met', () {
      final failure = CanonicalFailure(
        code: CanonicalErrorCode.timeout,
        message: 'Provider request timed out.',
        httpStatusCode: 504,
        retryable: true,
        failoverEligible: true,
        providerId: 'hosted_primary',
      );

      final decision = GatewayNormalizer().decideFallback(
        failure: failure,
        hasConfiguredFallback: true,
        alreadyAttemptedFallback: false,
        fallbackIsDifferentProviderOrModel: true,
      );

      expect(decision.shouldFallback, isTrue);
      expect(decision.reason, 'fallback_permitted');
    });

    test('permits fallback for provider_unavailable', () {
      final failure = CanonicalFailure(
        code: CanonicalErrorCode.providerUnavailable,
        message: 'Provider returned a server error.',
        httpStatusCode: 503,
        retryable: true,
        failoverEligible: true,
        providerId: 'hosted_primary',
      );

      final decision = GatewayNormalizer().decideFallback(
        failure: failure,
        hasConfiguredFallback: true,
        alreadyAttemptedFallback: false,
        fallbackIsDifferentProviderOrModel: true,
      );

      expect(decision.shouldFallback, isTrue);
    });

    test('blocks fallback when no fallback configured', () {
      final failure = CanonicalFailure(
        code: CanonicalErrorCode.timeout,
        message: 'Provider request timed out.',
        httpStatusCode: 504,
        retryable: true,
        failoverEligible: true,
        providerId: 'hosted_primary',
      );

      final decision = GatewayNormalizer().decideFallback(
        failure: failure,
        hasConfiguredFallback: false,
        alreadyAttemptedFallback: false,
        fallbackIsDifferentProviderOrModel: true,
      );

      expect(decision.shouldFallback, isFalse);
      expect(decision.reason, contains('no_fallback_configured'));
    });

    test('blocks fallback when already attempted', () {
      final failure = CanonicalFailure(
        code: CanonicalErrorCode.timeout,
        message: 'Provider request timed out.',
        httpStatusCode: 504,
        retryable: true,
        failoverEligible: true,
        providerId: 'hosted_primary',
      );

      final decision = GatewayNormalizer().decideFallback(
        failure: failure,
        hasConfiguredFallback: true,
        alreadyAttemptedFallback: true,
        fallbackIsDifferentProviderOrModel: true,
      );

      expect(decision.shouldFallback, isFalse);
      expect(decision.reason, contains('already_attempted'));
    });

    test('blocks fallback when fallback is same provider and model', () {
      final failure = CanonicalFailure(
        code: CanonicalErrorCode.timeout,
        message: 'Provider request timed out.',
        httpStatusCode: 504,
        retryable: true,
        failoverEligible: true,
        providerId: 'hosted_primary',
      );

      final decision = GatewayNormalizer().decideFallback(
        failure: failure,
        hasConfiguredFallback: true,
        alreadyAttemptedFallback: false,
        fallbackIsDifferentProviderOrModel: false,
      );

      expect(decision.shouldFallback, isFalse);
      expect(decision.reason, contains('same_provider'));
    });

    test('does not fallback for rate_limited', () {
      final failure = CanonicalFailure(
        code: CanonicalErrorCode.rateLimited,
        message: 'Provider rate limit exceeded.',
        httpStatusCode: 429,
        retryable: true,
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

    test('does not fallback for content_filtered', () {
      final failure = CanonicalFailure(
        code: CanonicalErrorCode.contentFiltered,
        message: 'Request blocked by content filter.',
        httpStatusCode: 422,
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

    test('does not fallback for invalid_provider_response', () {
      final failure = CanonicalFailure(
        code: CanonicalErrorCode.invalidProviderResponse,
        message: 'Provider returned an unrecognized response.',
        httpStatusCode: 502,
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

    test('decideFallback always provides a machine-readable reason', () {
      final failure = CanonicalFailure(
        code: CanonicalErrorCode.timeout,
        message: 'Provider request timed out.',
        httpStatusCode: 504,
        retryable: true,
        failoverEligible: true,
        providerId: 'hosted_primary',
      );

      // All paths should produce a non-empty reason string.
      final permitDecision = GatewayNormalizer().decideFallback(
        failure: failure,
        hasConfiguredFallback: true,
        alreadyAttemptedFallback: false,
        fallbackIsDifferentProviderOrModel: true,
      );
      expect(permitDecision.reason, isNotEmpty);

      final denyDecision = GatewayNormalizer().decideFallback(
        failure: failure,
        hasConfiguredFallback: true,
        alreadyAttemptedFallback: true,
        fallbackIsDifferentProviderOrModel: true,
      );
      expect(denyDecision.reason, isNotEmpty);
    });
  });

  // ── A4: cosineSimilarity tests ──

  group('cosineSimilarity', () {
    test('identical vectors have similarity 1.0', () {
      expect(cosineSimilarity([1, 2, 3], [1, 2, 3]), closeTo(1.0, 1e-10));
    });

    test('opposite vectors have similarity -1.0', () {
      expect(cosineSimilarity([1, 0, 0], [-1, 0, 0]), closeTo(-1.0, 1e-10));
    });

    test('orthogonal vectors have similarity 0.0', () {
      expect(cosineSimilarity([1, 0], [0, 1]), closeTo(0.0, 1e-10));
    });

    test('works with floating-point values', () {
      final result = cosineSimilarity([0.5, 0.5], [0.5, 0.5]);
      expect(result, closeTo(1.0, 1e-10));
    });

    test('works with mixed positive and negative values', () {
      // [3, -4] dot [4, 3] = 12 - 12 = 0 → orthogonal
      expect(cosineSimilarity([3, -4], [4, 3]), closeTo(0.0, 1e-10));
    });

    test('throws for empty left vector', () {
      expect(() => cosineSimilarity([], [1, 2]), throwsArgumentError);
    });

    test('throws for empty right vector', () {
      expect(() => cosineSimilarity([1, 2], []), throwsArgumentError);
    });

    test('throws for both vectors empty', () {
      expect(() => cosineSimilarity([], []), throwsArgumentError);
    });

    test('throws for dimension mismatch', () {
      expect(() => cosineSimilarity([1, 2, 3], [1, 2]), throwsArgumentError);
    });

    test('throws for zero-norm left vector', () {
      expect(() => cosineSimilarity([0, 0, 0], [1, 2, 3]), throwsArgumentError);
    });

    test('throws for zero-norm right vector', () {
      expect(() => cosineSimilarity([1, 2, 3], [0, 0, 0]), throwsArgumentError);
    });

    test('throws for NaN in left vector', () {
      expect(
        () => cosineSimilarity([double.nan, 1], [1, 1]),
        throwsArgumentError,
      );
    });

    test('throws for infinity in right vector', () {
      expect(
        () => cosineSimilarity([1, 1], [double.infinity, 1]),
        throwsArgumentError,
      );
    });

    test('throws for negative infinity', () {
      expect(
        () => cosineSimilarity([1, 1], [double.negativeInfinity, 1]),
        throwsArgumentError,
      );
    });

    test('does not pad shorter vectors to match', () {
      // Explicitly verify: [1,2] vs [1,2,3] must fail, not silently pad.
      expect(() => cosineSimilarity([1, 2], [1, 2, 3]), throwsArgumentError);
    });
  });
}
