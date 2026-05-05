import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:termopaneli_app/config/api_config.dart';
import 'package:termopaneli_app/services/estimate_service.dart';
import 'package:termopaneli_app/services/session_service.dart';

class SaveEstimateResult {
  const SaveEstimateResult({
    required this.ok,
    this.estimateId,
    this.errorMessage,
  });

  final bool ok;
  final int? estimateId;
  final String? errorMessage;
}

class SavedEstimate {
  const SavedEstimate({
    required this.id,
    required this.title,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
    required this.itemsCount,
  });

  final int id;
  final String title;
  final String status;
  final double totalAmount;
  final String createdAt;
  final int itemsCount;
}

abstract final class EstimateApiService {
  EstimateApiService._();

  static Uri _uri(String path) {
    final String base = ApiConfig.baseUrl.trim();
    if (base.isEmpty) {
      throw StateError('API_BASE_URL');
    }
    final String normalized = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    return Uri.parse('$normalized$path');
  }

  static Future<SaveEstimateResult> saveCurrent({
    required List<EstimateLine> lines,
    String title = 'Смета',
  }) async {
    final String? token = await SessionService.getToken();
    if (token == null || token.isEmpty) {
      return const SaveEstimateResult(
        ok: false,
        errorMessage: 'Нужно войти в аккаунт',
      );
    }
    if (lines.isEmpty) {
      return const SaveEstimateResult(ok: false, errorMessage: 'Смета пустая');
    }

    try {
      final http.Response res = await http
          .post(
            _uri('/api/v1/estimates/save.php'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(<String, Object?>{
              'title': title,
              'items': lines.map(_lineToJson).toList(growable: false),
            }),
          )
          .timeout(const Duration(seconds: 30));

      final dynamic data = _decodeBody(res.body);
      if (res.statusCode == 200 && data is Map<String, dynamic>) {
        final int? estimateId = int.tryParse('${data['estimate_id'] ?? ''}');
        return SaveEstimateResult(ok: true, estimateId: estimateId);
      }
      return SaveEstimateResult(
        ok: false,
        errorMessage: _messageFrom(data) ?? 'Ошибка ${res.statusCode}',
      );
    } catch (e) {
      return SaveEstimateResult(
        ok: false,
        errorMessage: 'Нет связи с сервером: $e',
      );
    }
  }

  static Future<List<SavedEstimate>> fetchSaved() async {
    final String? token = await SessionService.getToken();
    if (token == null || token.isEmpty) {
      return const <SavedEstimate>[];
    }

    final http.Response res = await http
        .get(
          _uri('/api/v1/estimates/list.php'),
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      throw Exception('Ошибка загрузки смет: ${res.statusCode}');
    }
    final dynamic data = jsonDecode(res.body);
    if (data is! Map<String, dynamic> || data['items'] is! List) {
      throw Exception('Некорректный формат смет');
    }
    return (data['items'] as List)
        .whereType<Map>()
        .map((Map row) => _savedFromJson(row.cast<String, dynamic>()))
        .toList(growable: false);
  }

  static Map<String, Object?> _lineToJson(EstimateLine line) {
    return <String, Object?>{
      'key': line.key,
      'category': line.item.category,
      'sku':
          line.item.raw['sku'] ??
          line.item.raw['article'] ??
          line.item.raw['id'],
      'name': line.item.title,
      'description': line.item.subtitle,
      'material': line.item.raw['material'],
      'color': line.item.raw['color'] ?? line.item.raw['color_description'],
      'unit': line.item.unit ?? 'шт',
      'quantity': line.quantity,
      'unit_price': line.price,
      'raw': line.item.raw,
    };
  }

  static SavedEstimate _savedFromJson(Map<String, dynamic> row) {
    final List items = row['items'] is List ? row['items'] as List : const [];
    return SavedEstimate(
      id: int.tryParse('${row['id'] ?? 0}') ?? 0,
      title: '${row['title'] ?? 'Смета'}',
      status: '${row['status'] ?? ''}',
      totalAmount: double.tryParse('${row['total_amount'] ?? 0}') ?? 0,
      createdAt: '${row['created_at'] ?? ''}',
      itemsCount: items.length,
    );
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
