import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/design/app_text_sizes.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';
import 'package:termopaneli_app/routes/app_router.dart';
import 'package:termopaneli_app/screens/estimate_pdf_preview_screen.dart';
import 'package:termopaneli_app/services/company_pdf_api_service.dart';
import 'package:termopaneli_app/services/estimate_api_service.dart';
import 'package:termopaneli_app/services/estimate_pdf_export.dart';
import 'package:termopaneli_app/services/estimate_share_text.dart';

class SavedEstimatesScreen extends StatefulWidget {
  const SavedEstimatesScreen({super.key});

  @override
  State<SavedEstimatesScreen> createState() => _SavedEstimatesScreenState();
}

class _SavedEstimatesScreenState extends State<SavedEstimatesScreen> {
  late Future<List<SavedEstimate>> _future;
  int? _submittingEstimateId;
  bool _showRequests = false;

  @override
  void initState() {
    super.initState();
    _future = EstimateApiService.fetchSaved();
  }

  String _money(double value) {
    if (value == 0) {
      return 'по запросу';
    }
    return '${value.toStringAsFixed(0)} ₽';
  }

  void _refresh() {
    setState(() {
      _future = EstimateApiService.fetchSaved();
    });
  }

  Future<void> _submit(SavedEstimate estimate, {String comment = ''}) async {
    if (_submittingEstimateId != null) {
      return;
    }
    setState(() => _submittingEstimateId = estimate.id);
    final SaveEstimateResult result = await EstimateApiService.submitSaved(
      estimate.id,
      comment: comment,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _submittingEstimateId = null;
      if (result.ok) {
        _future = EstimateApiService.fetchSaved();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.ok
              ? 'Смета отправлена как заявка'
              : (result.errorMessage ?? 'Не удалось отправить заявку'),
        ),
      ),
    );
  }

  Future<void> _showSubmitDialog(SavedEstimate estimate) async {
    final String? comment = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      // Иначе смахивание / тап вне листа даёт null и заявка не уходит, хотя пользователь «уже отправлял».
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.pageBackground,
      builder: (BuildContext context) => const _SubmitEstimateSheet(),
    );
    if (comment == null) {
      return;
    }
    await _submit(estimate, comment: comment);
  }

  void _openDetails(SavedEstimate estimate) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.pageBackground,
      builder: (BuildContext context) {
        return _SavedEstimateDetails(
          estimate: estimate,
          money: _money,
          isSubmitting: _submittingEstimateId == estimate.id,
          onSubmit: () => _showSubmitDialog(estimate),
        );
      },
    );
  }

  void _editEstimate(SavedEstimate estimate) {
    AppRouter.pushEstimate(context, estimate: estimate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 22,
                      color: AppColors.headingText,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Сохраненные сметы',
                      textAlign: TextAlign.center,
                      style: AppTextTheme.screenTitle,
                    ),
                  ),
                  IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ModeButton(
                          text: 'Сметы',
                          isSelected: !_showRequests,
                          onTap: () => setState(() => _showRequests = false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ModeButton(
                          text: 'Заявки',
                          isSelected: _showRequests,
                          onTap: () => setState(() => _showRequests = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () => AppRouter.pushEstimate(context),
                    child: const Text('Открыть текущую смету'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<SavedEstimate>>(
                future: _future,
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<SavedEstimate>> snapshot,
                    ) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return _SavedEmptyState(
                          title: 'Не удалось загрузить сметы',
                          subtitle: '${snapshot.error}',
                          actionText: 'Повторить',
                          onAction: _refresh,
                        );
                      }
                      final List<SavedEstimate> estimates =
                          snapshot.data ?? const <SavedEstimate>[];
                      final List<SavedEstimate> filtered = estimates
                          .where(
                            (SavedEstimate estimate) => _showRequests
                                ? estimate.hasEstimateRequest
                                : !estimate.hasEstimateRequest,
                          )
                          .toList(growable: false);
                      if (filtered.isEmpty) {
                        return _SavedEmptyState(
                          title: _showRequests
                              ? 'Отправленных заявок пока нет'
                              : 'Сохраненных смет пока нет',
                          subtitle: _showRequests
                              ? 'Отправьте сохраненную смету как заявку, чтобы она появилась здесь.'
                              : 'Откройте текущую смету, добавьте материалы и сохраните ее.',
                          actionText: _showRequests
                              ? 'К сметам'
                              : 'Открыть смету',
                          onAction: _showRequests
                              ? () => setState(() => _showRequests = false)
                              : () => AppRouter.pushEstimate(context),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (BuildContext context, int index) {
                          final SavedEstimate estimate = filtered[index];
                          final bool isSubmitted = estimate.hasEstimateRequest;
                          final bool isSubmitting =
                              _submittingEstimateId == estimate.id;
                          return _SavedEstimateCard(
                            estimate: estimate,
                            money: _money,
                            isSubmitted: isSubmitted,
                            isSubmitting: isSubmitting,
                            showRequestActions: !_showRequests,
                            onOpen: () => _openDetails(estimate),
                            onEdit: () => _editEstimate(estimate),
                            onSubmit: () => _showSubmitDialog(estimate),
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

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: isSelected
            ? AppColors.onAccent
            : AppColors.headingText,
        backgroundColor: isSelected
            ? AppColors.primaryButtonBackground
            : AppColors.pageBackground,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          side: BorderSide(
            color: isSelected
                ? AppColors.primaryButtonBackground
                : const Color(0xFFC9C9C9),
          ),
        ),
      ),
      child: Text(text, style: const TextStyle(fontSize: AppTextSizes.s34)),
    );
  }
}

class _SubmitEstimateSheet extends StatefulWidget {
  const _SubmitEstimateSheet();

  @override
  State<_SubmitEstimateSheet> createState() => _SubmitEstimateSheetState();
}

class _SubmitEstimateSheetState extends State<_SubmitEstimateSheet> {
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_commentController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets viewInsets = MediaQuery.viewInsetsOf(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Отправить заявку',
                    style: AppTextTheme.sectionTitle,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Контакты будут взяты из профиля пользователя.',
              style: AppTextTheme.body32,
            ),
            const SizedBox(height: 12),
            _SubmitField(
              controller: _commentController,
              label: 'Комментарий',
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submit,
              child: const Text('Отправить заявку'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmitField extends StatelessWidget {
  const _SubmitField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _SavedEstimateCard extends StatelessWidget {
  const _SavedEstimateCard({
    required this.estimate,
    required this.money,
    required this.isSubmitted,
    required this.isSubmitting,
    required this.showRequestActions,
    required this.onOpen,
    required this.onEdit,
    required this.onSubmit,
  });

  final SavedEstimate estimate;
  final String Function(double value) money;
  final bool isSubmitted;
  final bool isSubmitting;
  final bool showRequestActions;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  estimate.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextTheme.body34.copyWith(
                    color: AppColors.headingText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(money(estimate.totalAmount), style: AppTextTheme.body34),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${estimate.itemsCount} поз. • ${_statusLabel(estimate)}',
            style: const TextStyle(
              color: Color(0xFF757575),
              fontSize: AppTextSizes.s28,
            ),
          ),
          if (EstimateShareText.estimateDiscountCaption(
                lineItemsSum: estimate.items.fold<double>(
                  0,
                  (double s, SavedEstimateItem i) => s + i.totalPrice,
                ),
                totalAmount: estimate.totalAmount,
                calculation: estimate.calculation,
              )
              case final String discountLine) ...[
            const SizedBox(height: 2),
            Text(
              discountLine,
              style: const TextStyle(
                color: Color(0xFF8D6E63),
                fontSize: AppTextSizes.s28,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onOpen,
                  child: const Text('Открыть'),
                ),
              ),
              if (showRequestActions) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onEdit,
                    child: const Text('Редактировать'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: isSubmitted || isSubmitting ? null : onSubmit,
                    child: Text(
                      isSubmitted
                          ? 'Заявка'
                          : isSubmitting
                          ? 'Отправка...'
                          : 'В заявку',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SavedEstimateDetails extends StatelessWidget {
  const _SavedEstimateDetails({
    required this.estimate,
    required this.money,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final SavedEstimate estimate;
  final String Function(double value) money;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final bool isSubmitted = estimate.hasEstimateRequest;
    final String? requestComment = estimate.requestComment;
    final double linesSum = estimate.items.fold<double>(
      0,
      (double s, SavedEstimateItem i) => s + i.totalPrice,
    );
    final String? discountCaption = EstimateShareText.estimateDiscountCaption(
      lineItemsSum: linesSum,
      totalAmount: estimate.totalAmount,
      calculation: estimate.calculation,
    );
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (BuildContext context, ScrollController scrollController) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        estimate.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextTheme.sectionTitle,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Поделиться текстом',
                      onPressed: () async {
                        final String text = EstimateShareText.fromSaved(
                          estimate: estimate,
                          statusLine: _statusLabel(estimate),
                          requestComment: estimate.requestComment,
                        );
                        await SharePlus.instance.share(
                          ShareParams(
                            text: text,
                            subject: estimate.title,
                          ),
                        );
                      },
                      icon: const Icon(Icons.share_outlined),
                    ),
                    IconButton(
                      tooltip: 'Поделиться PDF',
                      onPressed: () async {
                        try {
                          final company = await CompanyPdfApiService.fetchForPdf();
                          final Uint8List bytes =
                              await EstimatePdfExport.buildFromSaved(
                            estimate: estimate,
                            statusLine: _statusLabel(estimate),
                            company: company,
                            requestComment: estimate.requestComment,
                          );
                          if (!context.mounted) {
                            return;
                          }
                          final String name = 'smeta_${estimate.id}.pdf';
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => EstimatePdfPreviewScreen(
                                pdfBytes: bytes,
                                shareFileName: name,
                                shareSubject: estimate.title,
                              ),
                            ),
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Не удалось создать PDF: $e'),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      '${_statusLabel(estimate)} • ${money(estimate.totalAmount)}',
                      style: AppTextTheme.body32,
                    ),
                    if (discountCaption != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        discountCaption,
                        style: const TextStyle(
                          color: Color(0xFF8D6E63),
                          fontSize: AppTextSizes.s28,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount:
                      estimate.items.length + (requestComment == null ? 0 : 1),
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    if (requestComment != null && index == 0) {
                      return _RequestCommentBlock(comment: requestComment);
                    }
                    final int itemIndex = requestComment == null
                        ? index
                        : index - 1;
                    final SavedEstimateItem item = estimate.items[itemIndex];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            item.name,
                            style: AppTextTheme.body34.copyWith(
                              color: AppColors.headingText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.quantity} ${item.unit} • ${money(item.totalPrice)}',
                            style: AppTextTheme.body32,
                          ),
                          if (item.sku != null || item.color != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (item.sku != null) 'арт. ${item.sku}',
                                if (item.color != null) item.color!,
                              ].join(' • '),
                              style: const TextStyle(
                                color: Color(0xFF757575),
                                fontSize: AppTextSizes.s28,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton(
                  onPressed: isSubmitted || isSubmitting ? null : onSubmit,
                  child: Text(
                    isSubmitted
                        ? 'Уже отправлена как заявка'
                        : isSubmitting
                        ? 'Отправка...'
                        : 'Отправить как заявку',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RequestCommentBlock extends StatelessWidget {
  const _RequestCommentBlock({required this.comment});

  final String comment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
                'Комментарий к заявке',
                style: AppTextTheme.body34.copyWith(
                  color: AppColors.headingText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(comment, style: AppTextTheme.body32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedEmptyState extends StatelessWidget {
  const _SavedEmptyState({
    required this.title,
    required this.subtitle,
    required this.actionText,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionText;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 72,
              color: Color(0xFF8D8D8D),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextTheme.sectionTitle,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextTheme.body32,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionText)),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(SavedEstimate estimate) {
  if (estimate.hasEstimateRequest) {
    switch (estimate.requestStatus) {
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
        return 'заявка: ${estimate.requestStatus}';
    }
  }
  if (estimate.status == 'submitted') {
    return 'заявка не создана на сервере — отправьте снова';
  }
  switch (estimate.status) {
    case 'draft':
    case '':
      return 'черновик';
    default:
      return estimate.status;
  }
}
