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
  AiRuntimeSuccess normalizeSuccess({
    required String requestId,
    required String providerId,
    required Map<String, dynamic> payload,
    required Map<String, Object?> routingMetadata,
    required DateTime completedAt,
  }) {
    // TODO: Normalize both supplied provider success fixtures.
    throw UnimplementedError();
  }

  CanonicalFailure normalizeFailure({
    required String providerId,
    required int? upstreamStatusCode,
    required Map<String, dynamic>? payload,
    required bool timedOut,
  }) {
    // TODO: Apply the canonical taxonomy without leaking upstream secrets/body.
    throw UnimplementedError();
  }

  FallbackDecision decideFallback({
    required CanonicalFailure failure,
    required bool hasConfiguredFallback,
    required bool alreadyAttemptedFallback,
    required bool fallbackIsDifferentProviderOrModel,
  }) {
    // TODO: Permit one deterministic fallback only for documented conditions.
    throw UnimplementedError();
  }
}

double cosineSimilarity(List<num> left, List<num> right) {
  // TODO: Validate vectors and calculate cosine similarity.
  throw UnimplementedError();
}
