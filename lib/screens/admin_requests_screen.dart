import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/design/app_text_sizes.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';
import 'package:termopaneli_app/services/admin_requests_api_service.dart';
import 'package:termopaneli_app/services/session_service.dart';

const List<String> _adminStatusValues = <String>[
  'new',
  'in_work',
  'need_info',
  'done',
  'closed',
  'cancelled',
];

String _adminStatusLabelRu(String code) {
  switch (code) {
    case 'new':
      return 'новая';
    case 'in_work':
      return 'в работе';
    case 'need_info':
      return 'нужны уточнения';
    case 'done':
      return 'обработана';
    case 'closed':
      return 'закрыта';
    case 'cancelled':
      return 'отменена';
    default:
      return code;
  }
}

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  final TextEditingController _tokenController = TextEditingController();
  late Future<AdminRequestListResult> _future;
  String? _filterStatus;
  bool _tokenLoaded = false;

  @override
  void initState() {
    super.initState();
    _future = Future<AdminRequestListResult>.value(
      const AdminRequestListResult(ok: true, items: []),
    );
    _loadToken();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadToken() async {
    final String? t = await SessionService.getAdminApiToken();
    if (!mounted) {
      return;
    }
    setState(() {
      if (t != null && t.isNotEmpty) {
        _tokenController.text = t;
      }
      _tokenLoaded = true;
    });
    _reloadList();
  }

  String _money(double value) {
    if (value == 0) {
      return 'по запросу';
    }
    return '${value.toStringAsFixed(0)} ₽';
  }

  void _reloadList() {
    final String token = _tokenController.text.trim();
    setState(() {
      _future = AdminRequestsApiService.fetchRequests(
        token,
        status: _filterStatus,
        limit: 100,
      );
    });
  }

  Future<void> _saveToken() async {
    await SessionService.saveAdminApiToken(_tokenController.text);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Токен сохранен на устройстве')),
    );
    _reloadList();
  }

  Future<void> _clearToken() async {
    await SessionService.clearAdminApiToken();
    _tokenController.clear();
    if (!mounted) {
      return;
    }
    setState(_reloadList);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Токен удален')));
  }

  Future<void> _applyStatus(AdminEstimateRequest request, String status) async {
    final AdminRequestStatusResult r =
        await AdminRequestsApiService.updateStatus(
          _tokenController.text.trim(),
          requestId: request.id,
          status: status,
        );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(r.ok ? 'Статус обновлен' : (r.errorMessage ?? 'Ошибка')),
      ),
    );
    if (r.ok) {
      Navigator.of(context).pop();
      _reloadList();
    }
  }

  void _openDetails(AdminEstimateRequest request) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.pageBackground,
      builder: (BuildContext context) {
        return _AdminRequestDetailsSheet(
          request: request,
          money: _money,
          onApplyStatus: (String s) => _applyStatus(request, s),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.pageBackground,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.headingText,
          ),
        ),
        title: const Text('Заявки (админ)', style: AppTextTheme.screenTitle),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Токен из admin_api_token в config.php на сервере. Хранится только на этом устройстве.',
                style: AppTextTheme.body32.copyWith(fontSize: AppTextSizes.s28),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _tokenController,
                obscureText: true,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Admin API token',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _saveToken(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _tokenLoaded ? _saveToken : null,
                      child: const Text('Сохранить токен'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: _clearToken,
                    child: const Text('Сбросить'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: const Text('Все'),
                        selected: _filterStatus == null,
                        onSelected: (_) {
                          setState(() => _filterStatus = null);
                          _reloadList();
                        },
                      ),
                    ),
                    for (final String s in _adminStatusValues)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(_adminStatusLabelRu(s)),
                          selected: _filterStatus == s,
                          onSelected: (_) {
                            setState(() => _filterStatus = s);
                            _reloadList();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: OutlinedButton.icon(
                onPressed: _reloadList,
                icon: const Icon(Icons.refresh),
                label: const Text('Обновить список'),
              ),
            ),
            Expanded(
              child: FutureBuilder<AdminRequestListResult>(
                future: _future,
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<AdminRequestListResult> snapshot,
                    ) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final AdminRequestListResult? r = snapshot.data;
                      if (r == null) {
                        return const SizedBox.shrink();
                      }
                      if (!r.ok) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              r.errorMessage ?? 'Ошибка загрузки',
                              textAlign: TextAlign.center,
                              style: AppTextTheme.body32,
                            ),
                          ),
                        );
                      }
                      if (r.items.isEmpty) {
                        return Center(
                          child: Text(
                            _tokenController.text.trim().isEmpty
                                ? 'Введите и сохраните токен, затем обновите список.'
                                : 'Заявок нет.',
                            style: AppTextTheme.body32,
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: r.items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (BuildContext context, int index) {
                          final AdminEstimateRequest item = r.items[index];
                          return Material(
                            color: Colors.white,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(8),
                            ),
                            child: InkWell(
                              borderRadius: const BorderRadius.all(
                                Radius.circular(8),
                              ),
                              onTap: () => _openDetails(item),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.estimateTitle,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextTheme.body34.copyWith(
                                              color: AppColors.headingText,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _money(item.totalAmount),
                                          style: AppTextTheme.body34,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '#${item.id} • смета #${item.estimateId} • ${_adminStatusLabelRu(item.status)}',
                                      style: const TextStyle(
                                        color: Color(0xFF757575),
                                        fontSize: AppTextSizes.s28,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.createdAt,
                                      style: AppTextTheme.body32,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminRequestDetailsSheet extends StatefulWidget {
  const _AdminRequestDetailsSheet({
    required this.request,
    required this.money,
    required this.onApplyStatus,
  });

  final AdminEstimateRequest request;
  final String Function(double value) money;
  final Future<void> Function(String status) onApplyStatus;

  @override
  State<_AdminRequestDetailsSheet> createState() =>
      _AdminRequestDetailsSheetState();
}

class _AdminRequestDetailsSheetState extends State<_AdminRequestDetailsSheet> {
  late String _selectedStatus;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.request.status;
    if (!_adminStatusValues.contains(_selectedStatus)) {
      _selectedStatus = 'new';
    }
  }

  @override
  Widget build(BuildContext context) {
    final AdminEstimateRequest r = widget.request;
    final String fio =
        <String?>[r.userLastName, r.userFirstName, r.userMiddleName]
            .map((String? e) => e?.trim() ?? '')
            .where((String s) => s.isNotEmpty)
            .join(' ');
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController scrollController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      r.estimateTitle,
                      style: AppTextTheme.sectionTitle,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Заявка #${r.id} • ${_adminStatusLabelRu(r.status)} • ${widget.money(r.totalAmount)}',
                style: AppTextTheme.body32,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  _detailBlock('Пользователь', [
                    if (fio.isNotEmpty) fio,
                    if (r.userPhone != null) 'тел. ${r.userPhone}',
                    if (r.userEmail != null) r.userEmail!,
                    'user_id: ${r.userId}',
                  ]),
                  if (r.contactName != null ||
                      r.contactPhone != null ||
                      r.contactEmail != null)
                    _detailBlock('Контакты в заявке', [
                      if (r.contactName != null) r.contactName!,
                      if (r.contactPhone != null) 'тел. ${r.contactPhone}',
                      if (r.contactEmail != null) r.contactEmail!,
                    ]),
                  if (r.comment != null && r.comment!.isNotEmpty)
                    _detailBlock('Комментарий', [r.comment!]),
                  const SizedBox(height: 8),
                  Text(
                    'Статус',
                    style: AppTextTheme.body34.copyWith(
                      color: AppColors.headingText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedStatus,
                        items: _adminStatusValues
                            .map(
                              (String s) => DropdownMenuItem<String>(
                                value: s,
                                child: Text(_adminStatusLabelRu(s)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: _busy
                            ? null
                            : (String? v) {
                                if (v != null) {
                                  setState(() => _selectedStatus = v);
                                }
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy || _selectedStatus == r.status
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            await widget.onApplyStatus(_selectedStatus);
                            if (mounted) {
                              setState(() => _busy = false);
                            }
                          },
                    child: Text(_busy ? 'Сохранение...' : 'Применить статус'),
                  ),
                  const SizedBox(height: 16),
                  Text('Позиции сметы', style: AppTextTheme.sectionTitle),
                  const SizedBox(height: 8),
                  for (final AdminRequestItem it in r.items) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(it.name, style: AppTextTheme.body34),
                      subtitle: () {
                        final String sub = [
                          if (it.sku != null) 'арт. ${it.sku}',
                          if (it.category != null) it.category!,
                        ].join(' • ');
                        return sub.isEmpty
                            ? null
                            : Text(sub, style: AppTextTheme.body32);
                      }(),
                      trailing: Text(
                        '${it.quantity} ${it.unit} • ${widget.money(it.totalPrice)}',
                        style: AppTextTheme.body32,
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _detailBlock(String title, List<String> lines) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFFF4F1EA),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: AppTextTheme.body34.copyWith(
                  color: AppColors.headingText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              for (final String line in lines)
                Text(line, style: AppTextTheme.body32),
            ],
          ),
        ),
      ),
    );
  }
}
