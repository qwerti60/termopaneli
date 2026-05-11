import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:termopaneli_app/config/api_config.dart';

String? _adminJsonOptional(dynamic value) {
  final String text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : text;
}

class AdminRequestItem {
  const AdminRequestItem({
    required this.name,
    required this.unit,
    required this.quantity,
    required this.totalPrice,
    this.sku,
    this.category,
  });

  final String name;
  final String unit;
  final int quantity;
  final double totalPrice;
  final String? sku;
  final String? category;

  factory AdminRequestItem.fromJson(Map<String, dynamic> json) {
    return AdminRequestItem(
      name: '${json['name'] ?? 'Позиция'}',
      unit: '${json['unit'] ?? 'шт'}',
      quantity: int.tryParse('${json['quantity'] ?? 1}') ?? 1,
      totalPrice: double.tryParse('${json['total_price'] ?? 0}') ?? 0,
      sku: _adminJsonOptional(json['sku']),
      category: _adminJsonOptional(json['category']),
    );
  }
}

class AdminEstimateRequest {
  const AdminEstimateRequest({
    required this.id,
    required this.estimateId,
    required this.userId,
    required this.status,
    required this.estimateTitle,
    required this.totalAmount,
    required this.createdAt,
    required this.items,
    this.contactName,
    this.contactPhone,
    this.contactEmail,
    this.comment,
    this.userPhone,
    this.userLastName,
    this.userFirstName,
    this.userMiddleName,
    this.userEmail,
  });

  final int id;
  final int estimateId;
  final int userId;
  final String status;
  final String estimateTitle;
  final double totalAmount;
  final String createdAt;
  final List<AdminRequestItem> items;
  final String? contactName;
  final String? contactPhone;
  final String? contactEmail;
  final String? comment;
  final String? userPhone;
  final String? userLastName;
  final String? userFirstName;
  final String? userMiddleName;
  final String? userEmail;

  factory AdminEstimateRequest.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawItems = json['items'] is List
        ? json['items'] as List
        : const [];
    return AdminEstimateRequest(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      estimateId: int.tryParse('${json['estimate_id'] ?? 0}') ?? 0,
      userId: int.tryParse('${json['user_id'] ?? 0}') ?? 0,
      status: '${json['status'] ?? ''}',
      estimateTitle: '${json['estimate_title'] ?? 'Смета'}',
      totalAmount: double.tryParse('${json['total_amount'] ?? 0}') ?? 0,
      createdAt: '${json['created_at'] ?? ''}',
      contactName: _adminJsonOptional(json['contact_name']),
      contactPhone: _adminJsonOptional(json['contact_phone']),
      contactEmail: _adminJsonOptional(json['contact_email']),
      comment: _adminJsonOptional(json['comment']),
      userPhone: _adminJsonOptional(json['user_phone']),
      userLastName: _adminJsonOptional(json['last_name']),
      userFirstName: _adminJsonOptional(json['first_name']),
      userMiddleName: _adminJsonOptional(json['middle_name']),
      userEmail: _adminJsonOptional(json['email']),
      items: rawItems
          .whereType<Map>()
          .map(
            (Map<dynamic, dynamic> row) =>
                AdminRequestItem.fromJson(row.cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }
}

class AdminRequestListResult {
  const AdminRequestListResult({
    required this.ok,
    this.items = const [],
    this.errorMessage,
  });

  final bool ok;
  final List<AdminEstimateRequest> items;
  final String? errorMessage;
}

class AdminRequestStatusResult {
  const AdminRequestStatusResult({required this.ok, this.errorMessage});

  final bool ok;
  final String? errorMessage;
}

abstract final class AdminRequestsApiService {
  AdminRequestsApiService._();

  static String _normalizedBase() {
    final String base = ApiConfig.baseUrl.trim();
    if (base.isEmpty) {
      throw StateError('API_BASE_URL');
    }
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  static Uri _listUri(String adminToken, {String? status, required int limit}) {
    final Map<String, String> q = <String, String>{
      'token': adminToken,
      'limit': '$limit',
    };
    final String? s = status?.trim();
    if (s != null && s.isNotEmpty) {
      q['status'] = s;
    }
    return Uri.parse(
      '${_normalizedBase()}/api/v1/admin/requests/list.php',
    ).replace(queryParameters: q);
  }

  static Uri _statusUri(String adminToken) {
    return Uri.parse(
      '${_normalizedBase()}/api/v1/admin/requests/status.php',
    ).replace(queryParameters: <String, String>{'token': adminToken});
  }

  static Future<AdminRequestListResult> fetchRequests(
    String adminToken, {
    String? status,
    int limit = 100,
  }) async {
    final String t = adminToken.trim();
    if (t.isEmpty) {
      return const AdminRequestListResult(
        ok: false,
        errorMessage: 'Введите admin token',
      );
    }
    try {
      final Uri uri = _listUri(t, status: status, limit: limit);
      final http.Response res = await http
          .get(
            uri,
            headers: <String, String>{
              'Accept': 'application/json',
              'Authorization': 'Bearer $t',
            },
          )
          .timeout(const Duration(seconds: 30));
      final dynamic data = _decodeBody(res.body);
      if (res.statusCode == 200 && data is Map<String, dynamic>) {
        final List<dynamic> list = data['items'] is List
            ? data['items'] as List
            : const [];
        final List<AdminEstimateRequest> items = list
            .whereType<Map>()
            .map(
              (Map row) =>
                  AdminEstimateRequest.fromJson(row.cast<String, dynamic>()),
            )
            .toList(growable: false);
        return AdminRequestListResult(ok: true, items: items);
      }
      return AdminRequestListResult(
        ok: false,
        errorMessage: _messageFrom(data) ?? 'Ошибка ${res.statusCode}',
      );
    } catch (e) {
      return AdminRequestListResult(
        ok: false,
        errorMessage: 'Нет связи с сервером: $e',
      );
    }
  }

  static Future<AdminRequestStatusResult> updateStatus(
    String adminToken, {
    required int requestId,
    required String status,
  }) async {
    final String t = adminToken.trim();
    if (t.isEmpty) {
      return const AdminRequestStatusResult(
        ok: false,
        errorMessage: 'Введите admin token',
      );
    }
    if (requestId <= 0) {
      return const AdminRequestStatusResult(
        ok: false,
        errorMessage: 'Некорректная заявка',
      );
    }
    try {
      final http.Response res = await http
          .post(
            _statusUri(t),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $t',
            },
            body: jsonEncode(<String, Object?>{
              'request_id': requestId,
              'status': status,
            }),
          )
          .timeout(const Duration(seconds: 30));
      final dynamic data = _decodeBody(res.body);
      if (res.statusCode == 200 && data is Map<String, dynamic>) {
        return const AdminRequestStatusResult(ok: true);
      }
      return AdminRequestStatusResult(
        ok: false,
        errorMessage: _messageFrom(data) ?? 'Ошибка ${res.statusCode}',
      );
    } catch (e) {
      return AdminRequestStatusResult(
        ok: false,
        errorMessage: 'Нет связи с сервером: $e',
      );
    }
  }

  static dynamic _decodeBody(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  static String? _messageFrom(dynamic data) {
    if (data is Map) {
      return (data['message'] ?? data['error'])?.toString();
    }
    if (data is String && data.isNotEmpty) {
      return data;
    }
    return null;
  }
}
