import '../errors/app_exception.dart';

/// Strict inventory RPC gate — only `success == true` counts.
bool inventoryRpcSucceeded(
  dynamic response, {
  required String fallbackError,
  String code = 'INVENTORY_RPC_FAILED',
}) {
  if (response is Map) {
    final Map<String, dynamic> data = Map<String, dynamic>.from(response);
    if (data['success'] == true) {
      return true;
    }
    throw AppException(
      (data['error'] as String?) ?? fallbackError,
      code: code,
    );
  }
  throw AppException(fallbackError, code: code);
}

/// Non-throwing variant for result wrappers (sell, etc.).
bool inventoryRpcSuccessFlag(dynamic response) {
  if (response is Map) {
    return Map<String, dynamic>.from(response)['success'] == true;
  }
  return false;
}
