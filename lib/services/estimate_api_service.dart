import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:termopaneli_app/config/api_config.dart';
import 'package:termopaneli_app/services/catalog_api_service.dart';
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
    required this.items,
    this.calculation = const <String, dynamic>{},
    this.requestStatus,
    this.requestComment,
    this.requestCreatedAt,
  });

  final int id;
  final String title;
  final String status;
  final double totalAmount;
  final String createdAt;
  final int itemsCount;
  final List<SavedEstimateItem> items;
  final Map<String, dynamic> calculation;
  final String? requestStatus;
  final String? requestComment;
  final String? requestCreatedAt;

  /// Строка в `estimate_requests` (то, что отдаёт админ-API). Без неё смета в админке не появится,
  /// даже если в БД `estimates.status = submitted`.
  bool get hasEstimateRequest => (requestStatus ?? '').trim().isNotEmpty;

  /// Краткая строка для списка смет / заявок (черновик, статус заявки).
  String get statusSummary {
    if (hasEstimateRequest) {
      switch (requestStatus) {
        case 'new':
        case null:
        case '':
          return 'заявка новая';
        case 'in_work':
          return 'заявка в работе';
        case 'need_info':
          return 'требуется уточнение';
        case 'done':
          return 'заявка обработана';
        case 'closed':
          return 'заявка закрыта';
        case 'cancelled':
          return 'заявка отменена';
        default:
          return 'заявка: $requestStatus';
      }
    }
    if (status == 'submitted') {
      return 'заявка не создана на сервере — отправьте снова';
    }
    switch (status) {
      case 'draft':
      case '':
        return 'черновик';
      default:
        return status;
    }
  }
}

class SavedEstimateItem {
  const SavedEstimateItem({
    required this.name,
    required this.category,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.sku,
    this.description,
    this.material,
    this.color,
    this.raw = const <String, dynamic>{},
  });

  final String name;
  final String category;
  final String unit;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? sku;
  final String? description;
  final String? material;
  final String? color;
  final Map<String, dynamic> raw;
}

abstract final class EstimateApiService {
  EstimateApiService._();

  static Uri _uri(String path, {String? token}) {
    final String base = ApiConfig.baseUrl.trim();
    if (base.isEmpty) {
      throw StateError('API_BASE_URL');
    }
    final String normalized = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final Uri uri = Uri.parse('$normalized$path');
    if (token == null || token.isEmpty) {
      return uri;
    }
    return uri.replace(
      queryParameters: <String, String>{...uri.queryParameters, 'token': token},
    );
  }

  static Future<SaveEstimateResult> saveCurrent({
    required List<EstimateLine> lines,
    String title = 'Смета',
    Map<String, Object?>? calculation,
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
      final Map<String, Object?> payload = <String, Object?>{
        'title': title,
        'items': lines.map(_lineToJson).toList(growable: false),
      };
      if (calculation != null) {
        payload['calculation'] = calculation;
      }
      final http.Response res = await http
          .post(
            _uri('/api/v1/estimates/save.php', token: token),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
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
          _uri('/api/v1/estimates/list.php', token: token),
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

  static Future<SaveEstimateResult> submitSaved(
    int estimateId, {
    String comment = '',
  }) async {
    final String? token = await SessionService.getToken();
    if (token == null || token.isEmpty) {
      return const SaveEstimateResult(
        ok: false,
        errorMessage: 'Нужно войти в аккаунт',
      );
    }
    if (estimateId <= 0) {
      return const SaveEstimateResult(
        ok: false,
        errorMessage: 'Некорректная смета',
      );
    }

    try {
      final http.Response res = await http
          .post(
            _uri('/api/v1/estimates/submit.php', token: token),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(<String, Object?>{
              'estimate_id': estimateId,
              'comment': comment,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final dynamic data = _decodeBody(res.body);
      if (res.statusCode == 200) {
        if (data is Map) {
          final Map<String, dynamic> map = Map<String, dynamic>.from(data);
          if (map['ok'] == true) {
            return SaveEstimateResult(ok: true, estimateId: estimateId);
          }
          return SaveEstimateResult(
            ok: false,
            errorMessage: _messageFrom(map) ?? 'Ошибка ответа сервера',
          );
        }
        return const SaveEstimateResult(
          ok: false,
          errorMessage: 'Некорректный ответ сервера',
        );
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

  /// Удаляет сохранённую смету текущего пользователя на сервере (позиции и заявка снимаются каскадом).
  static Future<SaveEstimateResult> deleteSaved(int estimateId) async {
    final String? token = await SessionService.getToken();
    if (token == null || token.isEmpty) {
      return const SaveEstimateResult(
        ok: false,
        errorMessage: 'Нужно войти в аккаунт',
      );
    }
    if (estimateId <= 0) {
      return const SaveEstimateResult(
        ok: false,
        errorMessage: 'Некорректная смета',
      );
    }

    try {
      final http.Response res = await http
          .post(
            _uri('/api/v1/estimates/delete.php', token: token),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(<String, Object?>{
              'estimate_id': estimateId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final dynamic data = _decodeBody(res.body);
      if (res.statusCode == 200) {
        if (data is Map) {
          final Map<String, dynamic> map = Map<String, dynamic>.from(data);
          if (map['ok'] == true) {
            return SaveEstimateResult(ok: true, estimateId: estimateId);
          }
          return SaveEstimateResult(
            ok: false,
            errorMessage: _messageFrom(map) ?? 'Ошибка ответа сервера',
          );
        }
        return const SaveEstimateResult(
          ok: false,
          errorMessage: 'Некорректный ответ сервера',
        );
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
    final Map<String, dynamic> estimateRaw = _decodeRawMap(row['raw_json']);
    final Map<String, dynamic> calculation = estimateRaw['calculation'] is Map
        ? (estimateRaw['calculation'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final List<SavedEstimateItem> parsedItems = items
        .whereType<Map>()
        .map((Map item) => _savedItemFromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
    return SavedEstimate(
      id: int.tryParse('${row['id'] ?? 0}') ?? 0,
      title: '${row['title'] ?? 'Смета'}',
      status: '${row['status'] ?? ''}',
      totalAmount: double.tryParse('${row['total_amount'] ?? 0}') ?? 0,
      createdAt: '${row['created_at'] ?? ''}',
      itemsCount: parsedItems.length,
      items: parsedItems,
      calculation: calculation,
      requestStatus: _requestFieldFromJson(row, 'status'),
      requestComment: _requestCommentFromJson(row),
      requestCreatedAt: _requestFieldFromJson(row, 'created_at'),
    );
  }

  static String? _requestFieldFromJson(Map<String, dynamic> row, String field) {
    if (row['request'] case final Map request) {
      return _optionalString(request[field]);
    }
    return _optionalString(row['request_$field']);
  }

  static String? _requestCommentFromJson(Map<String, dynamic> row) {
    return _requestFieldFromJson(row, 'comment');
  }

  static SavedEstimateItem _savedItemFromJson(Map<String, dynamic> row) {
    final Map<String, dynamic> raw = _decodeRawMap(row['raw_json']);
    return SavedEstimateItem(
      name: '${row['name'] ?? 'Позиция'}',
      category: '${row['category'] ?? ''}',
      unit: '${row['unit'] ?? 'шт'}',
      quantity: int.tryParse('${row['quantity'] ?? 1}') ?? 1,
      unitPrice: double.tryParse('${row['unit_price'] ?? 0}') ?? 0,
      totalPrice: double.tryParse('${row['total_price'] ?? 0}') ?? 0,
      sku: _optionalString(row['sku']),
      description: _optionalString(row['description']),
      material: _optionalString(row['material']),
      color: _optionalString(row['color']),
      raw: raw,
    );
  }

  static List<EstimateLine> linesFromSaved(SavedEstimate estimate) {
    return estimate.items
        .map((SavedEstimateItem item) {
          final CatalogItem catalogItem = CatalogItem(
            title: item.name,
            category: item.category.isEmpty ? 'panel' : item.category,
            subtitle: item.description,
            categoryLabel: item.category == 'work' ? 'Работы' : null,
            price: item.unitPrice.toString(),
            unit: item.unit,
            raw: item.raw.isEmpty
                ? <String, dynamic>{
                    'sku': item.sku,
                    'category': item.category,
                    'name': item.name,
                    'description': item.description,
                    'material': item.material,
                    'color': item.color,
                    'unit': item.unit,
                    'price': item.unitPrice,
                  }
                : item.raw,
          );
          return EstimateLine(item: catalogItem, quantity: item.quantity);
        })
        .toList(growable: false);
  }

  static String? _optionalString(dynamic value) {
    final String text = '${value ?? ''}'.trim();
    return text.isEmpty ? null : text;
  }

  static dynamic _decodeBody(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  static Map<String, dynamic> _decodeRawMap(dynamic value) {
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(value);
        if (decoded is Map) {
          return decoded.cast<String, dynamic>();
        }
      } catch (_) {
        return const <String, dynamic>{};
      }
    }
    return const <String, dynamic>{};
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
