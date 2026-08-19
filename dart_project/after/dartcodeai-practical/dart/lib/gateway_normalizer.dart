import 'dart:math' as math;

enum CanonicalErrorCode {
  rateLimited('rate_limited'),
  contextLengthExceeded('context_length_exceeded'),
  authError('auth_error'),
  contentFiltered('content_filtered'),
  timeout('timeout'),
  providerUnavailable('provider_unavailable'),
  capabilityUnsupported('capability_unsupported'),
  invalidProviderResponse('invalid_provider_response');

  const CanonicalErrorCode(this.wireValue);
  final String wireValue;
}

class TokenUsage {
  const TokenUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  Map<String, Object> toJson() => {
    'promptTokens': promptTokens,
    'completionTokens': completionTokens,
    'totalTokens': totalTokens,
  };
}

class AiRuntimeSuccess {
  const AiRuntimeSuccess({
    required this.requestId,
    required this.providerId,
    required this.text,
    required this.usage,
    required this.metadata,
    required this.completedAt,
    this.finishReason,
  });

  final String requestId;
  final String providerId;
  final String text;
  final TokenUsage usage;
  final String? finishReason;
  final Map<String, Object?> metadata;
  final DateTime completedAt;

  Map<String, Object?> toJson() => {
    'requestId': requestId,
    'providerId': providerId,
    'output': {'text': text},
    'usage': usage.toJson(),
    if (finishReason != null) 'finishReason': finishReason,
    'metadata': metadata,
    'completedAt': completedAt.toUtc().toIso8601String(),
  };
}

class CanonicalFailure {
  const CanonicalFailure({
    required this.code,
    required this.message,
    required this.httpStatusCode,
    required this.retryable,
    required this.failoverEligible,
    required this.providerId,
  });

  final CanonicalErrorCode code;
  final String message;
  final int httpStatusCode;
  final bool retryable;
  final bool failoverEligible;
  final String providerId;

  Map<String, Object> toJson() => {
    'code': code.wireValue,
    'message': message,
    'httpStatusCode': httpStatusCode,
    'retryable': retryable,
    'failoverEligible': failoverEligible,
    'providerId': providerId,
  };
}

class FallbackDecision {
  const FallbackDecision({required this.shouldFallback, required this.reason});

  final bool shouldFallback;
  final String reason;
}

class GatewayNormalizer {
  /// Normalize a successful provider response into the provider-neutral
  /// [AiRuntimeSuccess] envelope.
  ///
  /// Supports two response shapes:
  /// - OpenAI-compatible: text at `choices[0].message.content`, snake_case
  ///   token fields, finish reason at `choices[0].finish_reason`.
  /// - Internal provider: text at `output.text`, camelCase token fields,
  ///   finish reason at top-level `finishReason`.
  ///
  /// Throws [FormatException] for unrecognized or malformed payloads so the
  /// gateway layer can route through [normalizeFailure] with
  /// [CanonicalErrorCode.invalidProviderResponse].
  AiRuntimeSuccess normalizeSuccess({
    required String requestId,
    required String providerId,
    required Map<String, dynamic> payload,
    required Map<String, Object?> routingMetadata,
    required DateTime completedAt,
  }) {
    String? text;
    String? finishReason;
    int? promptTokens;
    int? completionTokens;
    int? totalTokens;

    if (payload.containsKey('choices')) {
      // ── OpenAI-compatible format ──
      final choices = payload['choices'];
      if (choices is! List || choices.isEmpty) {
        throw FormatException(
          'OpenAI-compatible payload has empty or missing choices.',
        );
      }

      final firstChoice = choices[0] as Map<String, dynamic>;
      final message = firstChoice['message'] as Map<String, dynamic>?;
      text = message?['content'] as String?;
      if (text == null) {
        throw FormatException(
          'OpenAI-compatible payload missing message content.',
        );
      }

      finishReason = firstChoice['finish_reason'] as String?;

      final usage = payload['usage'] as Map<String, dynamic>?;
      if (usage == null) {
        throw FormatException('OpenAI-compatible payload missing usage.');
      }

      promptTokens = _requireInt(usage, 'prompt_tokens');
      completionTokens = _requireInt(usage, 'completion_tokens');
      totalTokens = _requireInt(usage, 'total_tokens');
    } else if (payload.containsKey('output')) {
      // ── Internal provider format ──
      final output = payload['output'] as Map<String, dynamic>?;
      text = output?['text'] as String?;
      if (text == null) {
        throw FormatException('Internal payload missing output.text.');
      }

      finishReason = payload['finishReason'] as String?;

      final usage = payload['usage'] as Map<String, dynamic>?;
      if (usage == null) {
        throw FormatException('Internal payload missing usage.');
      }

      promptTokens = _requireInt(usage, 'promptTokens');
      completionTokens = _requireInt(usage, 'completionTokens');
      totalTokens = _requireInt(usage, 'totalTokens');
    } else {
      throw FormatException(
        'Unrecognized provider response format: '
        'missing both "choices" and "output" keys.',
      );
    }

    return AiRuntimeSuccess(
      requestId: requestId,
      providerId: providerId,
      text: text,
      usage: TokenUsage(
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        totalTokens: totalTokens,
      ),
      finishReason: finishReason,
      metadata: routingMetadata,
      completedAt: completedAt.toUtc(),
    );
  }

  /// Map an upstream failure into the canonical error taxonomy.
  ///
  /// Messages are safe, static strings — no upstream body content,
  /// credentials, or authorization headers are ever included.
  CanonicalFailure normalizeFailure({
    required String providerId,
    required int? upstreamStatusCode,
    required Map<String, dynamic>? payload,
    required bool timedOut,
  }) {
    // Check payload-signalled error codes first: these take priority because
    // a provider may signal content_filtered or capability_unsupported
    // alongside various HTTP status codes.
    final errorCode = _extractErrorCode(payload);

    if (errorCode == 'content_filtered') {
      return CanonicalFailure(
        code: CanonicalErrorCode.contentFiltered,
        message: 'Request blocked by content filter.',
        httpStatusCode: 422,
        retryable: false,
        failoverEligible: false,
        providerId: providerId,
      );
    }

    if (errorCode == 'capability_unsupported') {
      return CanonicalFailure(
        code: CanonicalErrorCode.capabilityUnsupported,
        message: 'Requested capability is not supported.',
        httpStatusCode: 422,
        retryable: false,
        failoverEligible: false,
        providerId: providerId,
      );
    }

    // Timeout: check the boolean flag, which covers cases where we may not
    // have received a status code at all.
    if (timedOut || upstreamStatusCode == 504) {
      return CanonicalFailure(
        code: CanonicalErrorCode.timeout,
        message: 'Provider request timed out.',
        httpStatusCode: 504,
        retryable: true,
        failoverEligible: true,
        providerId: providerId,
      );
    }

    // HTTP status code mapping.
    if (upstreamStatusCode != null) {
      switch (upstreamStatusCode) {
        case 429:
          return CanonicalFailure(
            code: CanonicalErrorCode.rateLimited,
            message: 'Provider rate limit exceeded.',
            httpStatusCode: 429,
            retryable: true,
            failoverEligible: false,
            providerId: providerId,
          );
        case 413:
          return CanonicalFailure(
            code: CanonicalErrorCode.contextLengthExceeded,
            message: 'Request exceeds provider context length.',
            httpStatusCode: 413,
            retryable: false,
            failoverEligible: false,
            providerId: providerId,
          );
        case 401:
        case 403:
          return CanonicalFailure(
            code: CanonicalErrorCode.authError,
            message: 'Provider authentication failed.',
            httpStatusCode: 401,
            retryable: false,
            failoverEligible: false,
            providerId: providerId,
          );
        default:
          if (upstreamStatusCode >= 500 && upstreamStatusCode < 600) {
            return CanonicalFailure(
              code: CanonicalErrorCode.providerUnavailable,
              message: 'Provider returned a server error.',
              httpStatusCode: 503,
              retryable: true,
              failoverEligible: true,
              providerId: providerId,
            );
          }
      }
    }

    // Anything we cannot map is treated as a malformed/unrecognized response.
    return CanonicalFailure(
      code: CanonicalErrorCode.invalidProviderResponse,
      message: 'Provider returned an unrecognized response.',
      httpStatusCode: 502,
      retryable: false,
      failoverEligible: false,
      providerId: providerId,
    );
  }

  /// Decide whether to attempt fallback to an alternative provider.
  ///
  /// Fallback is permitted **only** when all conditions hold:
  /// 1. A different fallback provider/model is configured.
  /// 2. Fallback has not already been attempted (at most one fallback).
  /// 3. The canonical error is `timeout` or `providerUnavailable`.
  FallbackDecision decideFallback({
    required CanonicalFailure failure,
    required bool hasConfiguredFallback,
    required bool alreadyAttemptedFallback,
    required bool fallbackIsDifferentProviderOrModel,
  }) {
    if (!hasConfiguredFallback) {
      return const FallbackDecision(
        shouldFallback: false,
        reason: 'no_fallback_configured',
      );
    }

    if (!fallbackIsDifferentProviderOrModel) {
      return const FallbackDecision(
        shouldFallback: false,
        reason: 'fallback_same_provider_and_model',
      );
    }

    if (alreadyAttemptedFallback) {
      return const FallbackDecision(
        shouldFallback: false,
        reason: 'fallback_already_attempted',
      );
    }

    // Only timeout and provider_unavailable are eligible for failover.
    if (!failure.failoverEligible) {
      return FallbackDecision(
        shouldFallback: false,
        reason: 'error_not_failover_eligible:${failure.code.wireValue}',
      );
    }

    if (failure.code != CanonicalErrorCode.timeout &&
        failure.code != CanonicalErrorCode.providerUnavailable) {
      return FallbackDecision(
        shouldFallback: false,
        reason: 'error_code_not_eligible:${failure.code.wireValue}',
      );
    }

    return const FallbackDecision(
      shouldFallback: true,
      reason: 'fallback_permitted',
    );
  }

  // ── Private helpers ──

  /// Safely extract an integer from a map, throwing [FormatException] if the
  /// value is missing or not an integer.
  static int _requireInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is int) return value;
    throw FormatException(
      'Expected integer for "$key", got ${value.runtimeType}: $value',
    );
  }

  /// Safely extract an error code string from a provider error payload.
  /// Returns null if the payload does not contain a recognizable error code.
  static String? _extractErrorCode(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    final error = payload['error'];
    if (error is Map<String, dynamic>) {
      final code = error['code'];
      if (code is String) return code;
    }
    return null;
  }
}

/// Calculate cosine similarity between two numeric vectors.
///
/// Throws [ArgumentError] for:
/// - empty vectors
/// - dimension mismatch
/// - zero-norm vectors
/// - non-finite values (NaN, infinity)
double cosineSimilarity(List<num> left, List<num> right) {
  if (left.isEmpty || right.isEmpty) {
    throw ArgumentError('Vectors must not be empty.');
  }

  if (left.length != right.length) {
    throw ArgumentError(
      'Dimension mismatch: left has ${left.length} elements, '
      'right has ${right.length} elements. '
      'Never pad or truncate vectors to make dimensions match.',
    );
  }

  double dot = 0.0;
  double normLeft = 0.0;
  double normRight = 0.0;

  for (int i = 0; i < left.length; i++) {
    final l = left[i].toDouble();
    final r = right[i].toDouble();

    if (l.isNaN || l.isInfinite) {
      throw ArgumentError('Non-finite value in left vector at index $i: $l');
    }
    if (r.isNaN || r.isInfinite) {
      throw ArgumentError('Non-finite value in right vector at index $i: $r');
    }

    dot += l * r;
    normLeft += l * l;
    normRight += r * r;
  }

  final magnitudeLeft = math.sqrt(normLeft);
  final magnitudeRight = math.sqrt(normRight);

  if (magnitudeLeft == 0.0) {
    throw ArgumentError('Left vector has zero norm (all zeros).');
  }
  if (magnitudeRight == 0.0) {
    throw ArgumentError('Right vector has zero norm (all zeros).');
  }

  return dot / (magnitudeLeft * magnitudeRight);
}
