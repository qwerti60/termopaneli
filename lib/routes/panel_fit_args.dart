/// Аргументы маршрута примерки: URL изображения термопанели из каталога.
class PanelFitArgs {
  const PanelFitArgs({
    required this.textureImageUrl,
    this.panelTitle,
  });

  final String textureImageUrl;
  final String? panelTitle;
}
