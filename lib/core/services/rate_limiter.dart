import 'dart:async';
import 'dart:collection';

/// Rate limiter for sensitive operations
/// Prevents abuse by limiting the frequency of operations per user or per operation type
class RateLimiter {
  final int maxRequests;
  final Duration window;
  
  final _requestTimes = Queue<DateTime>();
  final _userRequestCounts = <String, Queue<DateTime>>{};
  final _operationCounts = <String, Queue<DateTime>>{};

  RateLimiter({
    this.maxRequests = 10,
    this.window = const Duration(minutes: 1),
  });

  /// Check if a request is allowed
  /// Returns true if allowed, false if rate limit exceeded
  bool checkRequest({String? userId, String? operation}) {
    final now = DateTime.now();
    
    // Check global rate limit
    if (!_checkWindow(_requestTimes, now)) {
      return false;
    }
    
    // Check per-user rate limit
    if (userId != null) {
      final userQueue = _userRequestCounts.putIfAbsent(userId, () => Queue<DateTime>());
      if (!_checkWindow(userQueue, now)) {
        return false;
      }
    }
    
    // Check per-operation rate limit
    if (operation != null) {
      final opQueue = _operationCounts.putIfAbsent(operation, () => Queue<DateTime>());
      if (!_checkWindow(opQueue, now)) {
        return false;
      }
    }
    
    // Record the request
    _recordRequest(now, userId, operation);
    return true;
  }

  /// Check if the window has capacity
  bool _checkWindow(Queue<DateTime> queue, DateTime now) {
    // Remove requests outside the window
    while (queue.isNotEmpty && now.difference(queue.first) > window) {
      queue.removeFirst();
    }
    
    return queue.length < maxRequests;
  }

  /// Record a request
  void _recordRequest(DateTime now, String? userId, String? operation) {
    _requestTimes.addLast(now);
    
    if (userId != null) {
      _userRequestCounts[userId]!.addLast(now);
    }
    
    if (operation != null) {
      _operationCounts[operation]!.addLast(now);
    }
  }

  /// Get remaining requests for a user
  int getRemainingRequests({String? userId, String? operation}) {
    final now = DateTime.now();
    Queue<DateTime>? queue;
    
    if (operation != null) {
      queue = _operationCounts[operation];
    } else if (userId != null) {
      queue = _userRequestCounts[userId];
    } else {
      queue = _requestTimes;
    }
    
    if (queue == null) return maxRequests;
    
    // Remove requests outside the window
    while (queue.isNotEmpty && now.difference(queue.first) > window) {
      queue.removeFirst();
    }
    
    return maxRequests - queue.length;
  }

  /// Get time until next request is allowed
  Duration? getTimeUntilNextRequest({String? userId, String? operation}) {
    final now = DateTime.now();
    Queue<DateTime>? queue;
    
    if (operation != null) {
      queue = _operationCounts[operation];
    } else if (userId != null) {
      queue = _userRequestCounts[userId];
    } else {
      queue = _requestTimes;
    }
    
    if (queue == null || queue.isEmpty) return null;
    
    // Remove requests outside the window
    while (queue.isNotEmpty && now.difference(queue.first) > window) {
      queue.removeFirst();
    }
    
    if (queue.length < maxRequests) return null;
    
    // Calculate time until the oldest request falls outside the window
    final oldestRequest = queue.first;
    final windowEnd = oldestRequest.add(window);
    return windowEnd.difference(now);
  }

  /// Reset rate limits for a user
  void resetUser(String userId) {
    _userRequestCounts.remove(userId);
  }

  /// Reset rate limits for an operation
  void resetOperation(String operation) {
    _operationCounts.remove(operation);
  }

  /// Clear all rate limits
  void clear() {
    _requestTimes.clear();
    _userRequestCounts.clear();
    _operationCounts.clear();
  }
}

/// Pre-configured rate limiters for different operation types
class RateLimiters {
  /// Strict rate limiter for very sensitive operations (e.g., school switching)
  static final schoolSwitch = RateLimiter(
    maxRequests: 5,
    window: const Duration(minutes: 5),
  );

  /// Moderate rate limiter for data modifications
  static final dataModification = RateLimiter(
    maxRequests: 20,
    window: const Duration(minutes: 1),
  );

  /// Lenient rate limiter for data access
  static final dataAccess = RateLimiter(
    maxRequests: 100,
    window: const Duration(minutes: 1),
  );

  /// Strict rate limiter for authentication attempts
  static final authentication = RateLimiter(
    maxRequests: 5,
    window: const Duration(minutes: 15),
  );

  /// Rate limiter for bulk operations
  static final bulkOperations = RateLimiter(
    maxRequests: 3,
    window: const Duration(hours: 1),
  );
}

/// Rate limit exception
class RateLimitExceededException implements Exception {
  final String message;
  final Duration? retryAfter;
  
  RateLimitExceededException(this.message, {this.retryAfter});
  
  @override
  String toString() => 'RateLimitExceededException: $message';
}

/// Utility class for rate limiting operations
class RateLimitHelper {
  /// Execute an operation with rate limiting
  /// Throws RateLimitExceededException if rate limit exceeded
  static Future<T> executeWithRateLimit<T>(
    RateLimiter limiter, {
    String? userId,
    String? operation,
    required Future<T> Function() operationFn,
  }) async {
    if (!limiter.checkRequest(userId: userId, operation: operation)) {
      final retryAfter = limiter.getTimeUntilNextRequest(userId: userId, operation: operation);
      throw RateLimitExceededException(
        'Rate limit exceeded for ${operation ?? "operation"}',
        retryAfter: retryAfter,
      );
    }
    
    return await operationFn();
  }

  /// Execute an operation with rate limiting and fallback
  /// Returns null if rate limit exceeded instead of throwing
  static Future<T?> executeWithRateLimitFallback<T>(
    RateLimiter limiter, {
    String? userId,
    String? operation,
    required Future<T> Function() operationFn,
  }) async {
    if (!limiter.checkRequest(userId: userId, operation: operation)) {
      return null;
    }
    
    return await operationFn();
  }

  /// Get rate limit status for display
  static Map<String, dynamic> getRateLimitStatus(
    RateLimiter limiter, {
    String? userId,
    String? operation,
  }) {
    final remaining = limiter.getRemainingRequests(userId: userId, operation: operation);
    final retryAfter = limiter.getTimeUntilNextRequest(userId: userId, operation: operation);
    
    return {
      'remaining': remaining,
      'max': limiter.maxRequests,
      'window': limiter.window.inSeconds,
      'retryAfter': retryAfter?.inSeconds,
      'limited': remaining == 0,
    };
  }
}
