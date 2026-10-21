import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';

/// A failed Functions API call. [code] is the server's stable error code
/// (see functions/lib/http.js); [message] is safe to show to the user.
class ApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  const ApiException(this.code, this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// User-facing copy for server error codes. Unknown codes fall back to the
/// server's own message, then to a generic one.
String messageForApiError(String code, {String? serverMessage}) {
  switch (code) {
    case 'UNAUTHENTICATED':
      return 'Your session has expired. Please sign in again.';
    case 'RATE_LIMITED':
      return 'You are doing that a lot. Please wait a little and try again.';
    case 'ALREADY_COMPLETED':
      return 'Already completed for this period.';
    case 'GOAL_ARCHIVED':
      return 'Restore this goal before completing it.';
    case 'INSUFFICIENT_FUNDS':
      return 'You do not have enough fish for that.';
    case 'INVALID_AMOUNT':
      return 'Enter a whole number of fish.';
    case 'NOT_A_MEMBER':
      return 'You are not a member of this neighbourhood.';
    case 'NOT_ADMIN':
      return 'Only neighbourhood admins can do that.';
    case 'NOT_LEADER':
      return 'Only the neighbourhood leader can do that.';
    case 'ALREADY_IN_BUILDING':
      return 'Leave your current neighbourhood first.';
    case 'ALREADY_MEMBER':
      return 'Already a member of this neighbourhood.';
    case 'REQUEST_PENDING':
      return 'Your join request is already waiting for approval.';
    case 'NO_PENDING_REQUEST':
      return 'That request has already been handled.';
    case 'TARGET_IN_OTHER_BUILDING':
      return 'That person has joined another neighbourhood. Reject the request instead.';
    case 'INVALID_INVITE_CODE':
      return serverMessage ?? 'That invite code is not valid.';
    case 'INVITE_CODE_TAKEN':
      return 'That invite code is already in use. Choose another.';
    case 'ALREADY_OWNED':
      return 'You already own this item.';
    case 'NOT_OWNED':
      return 'Purchase this item before equipping it.';
    case 'UNKNOWN_ITEM':
      return 'That item is no longer available.';
    case 'NETWORK':
      return 'Could not reach the server. Check your connection and try again.';
    default:
      return serverMessage ?? 'Something went wrong. Please try again.';
  }
}

/// Thin wrapper over the Functions API: attaches the Firebase ID token and
/// converts failures into [ApiException].
class ApiClient {
  final Ref _ref;
  final http.Client _http;

  ApiClient(this._ref, [http.Client? client]) : _http = client ?? http.Client();

  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) => _send('POST', path, body);

  Future<Map<String, dynamic>> get(String path) => _send('GET', path, null);

  Future<Map<String, dynamic>> _send(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
    final user = _ref.read(authStateProvider).value;
    if (user == null) {
      throw ApiException(
        'UNAUTHENTICATED',
        messageForApiError('UNAUTHENTICATED'),
      );
    }

    final http.Response response;
    try {
      final token = await user.getIdToken();
      final uri = Uri.parse('${_ref.read(backendBaseUrlProvider)}/$path');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      response = method == 'GET'
          ? await _http.get(uri, headers: headers)
          : await _http.post(
              uri,
              headers: headers,
              body: jsonEncode(body ?? {}),
            );
    } catch (_) {
      throw ApiException('NETWORK', messageForApiError('NETWORK'));
    }
    return decodeApiResponse(response.statusCode, response.body);
  }
}

/// Parses an API response body, throwing [ApiException] for non-2xx results.
Map<String, dynamic> decodeApiResponse(int statusCode, String body) {
  Map<String, dynamic> data = const {};
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) data = decoded;
  } catch (_) {
    // Non-JSON error pages fall through to a generic error below.
  }
  if (statusCode >= 200 && statusCode < 300) return data;

  final code = data['code'] is String
      ? data['code'] as String
      : 'HTTP_$statusCode';
  final serverMessage = data['error'] is String
      ? data['error'] as String
      : null;
  throw ApiException(
    code,
    messageForApiError(code, serverMessage: serverMessage),
    statusCode: statusCode,
  );
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref));
