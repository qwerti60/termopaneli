import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';

/// Полноэкранный предпросмотр PDF сметы ([pdfx]); отправка — [SharePlus].
///
/// Раньше использовался пакет `printing` (виджет предпросмотра), который на части платформ
/// показывал «Unable to display the document» при `canRaster == false`
/// (например Android API ниже 21, Web без pdf.js).
class EstimatePdfPreviewScreen extends StatefulWidget {
  const EstimatePdfPreviewScreen({
    super.key,
    required this.pdfBytes,
    required this.shareFileName,
    this.shareSubject = 'Смета PDF',
  });

  final Uint8List pdfBytes;
  final String shareFileName;
  final String shareSubject;

  @override
  State<EstimatePdfPreviewScreen> createState() => _EstimatePdfPreviewScreenState();
}

class _EstimatePdfPreviewScreenState extends State<EstimatePdfPreviewScreen> {
  late final PdfControllerPinch _pdfController = PdfControllerPinch(
    document: PdfDocument.openData(widget.pdfBytes),
  );

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.pageBackground,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.headingText,
          ),
        ),
        centerTitle: true,
        title: const Text('Просмотр PDF', style: AppTextTheme.sectionTitle),
        actions: <Widget>[
          IconButton(
            tooltip: 'Поделиться',
            onPressed: () async {
              await SharePlus.instance.share(
                ShareParams(
                  files: <XFile>[
                    XFile.fromData(
                      widget.pdfBytes,
                      name: widget.shareFileName,
                      mimeType: 'application/pdf',
                    ),
                  ],
                  subject: widget.shareSubject,
                ),
              );
            },
            icon: const Icon(Icons.share_outlined, color: AppColors.headingText),
          ),
        ],
      ),
      body: PdfViewPinch(
        controller: _pdfController,
        builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          documentLoaderBuilder: (_) => const Center(
            child: CircularProgressIndicator(),
          ),
          errorBuilder: (BuildContext context, Exception error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Не удалось открыть предпросмотр.\n$error',
                textAlign: TextAlign.center,
                style: AppTextTheme.body32,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
