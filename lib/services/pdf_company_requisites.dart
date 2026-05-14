/// Реквизиты и ссылки для шапки PDF: значения по умолчанию и разбор ответа API
/// `GET .../settings/company-for-pdf.php` или вложенного объекта **`company_pdf`** из **`GET .../settings/app-manifest.php`**.
class PdfCompanyRequisites {
  const PdfCompanyRequisites({
    required this.legalName,
    required this.innLine,
    required this.phoneLine,
    required this.address,
    required this.areaNote,
    required this.tagline,
    required this.website,
    required this.userAgreementUrl,
  });

  final String legalName;
  final String innLine;
  final String phoneLine;
  final String address;
  final String areaNote;
  final String tagline;
  final String website;
  final String userAgreementUrl;

  /// Совпадает с дефолтами в `company-for-pdf.php` (если API недоступен).
  static const PdfCompanyRequisites fallback = PdfCompanyRequisites(
    legalName: 'ООО «ЭКОСТРОЙЛИДЕР»',
    innLine: 'ИНН 7727316867',
    phoneLine: 'Тел. +7 925 480-36-16',
    address: '119034, Москва, ул. Пречистенка, 31/16',
    areaNote: 'Работаем по Москве, Московской области и близлежащих областях.',
    tagline: 'Фасадные термопанели от производителя',
    website: 'https://термованель.москва',
    userAgreementUrl: 'https://ivnovav.ru/tp_api/agreement.html',
  );

  static String _trim(Object? v) {
    if (v == null) {
      return '';
    }
    return v.toString().trim();
  }

  static String _pickLine(String primary, String fallback) {
    final String p = primary.trim();
    return p.isEmpty ? fallback : p;
  }

  static String _innLineFromApi(String innRaw, String defInnLine) {
    if (innRaw.isEmpty) {
      return defInnLine;
    }
    final String u = innRaw.toUpperCase();
    if (u.contains('ИНН')) {
      return innRaw;
    }
    return 'ИНН $innRaw';
  }

  static String _phoneLineFromApi(String phoneRaw, String defPhoneLine) {
    if (phoneRaw.isEmpty) {
      return defPhoneLine;
    }
    final String low = phoneRaw.toLowerCase();
    if (low.contains('тел') || low.contains('tel.')) {
      return phoneRaw;
    }
    return 'Тел. $phoneRaw';
  }

  factory PdfCompanyRequisites.fromApiMap(Map<String, dynamic> map) {
    const PdfCompanyRequisites d = PdfCompanyRequisites.fallback;
    final String legalName = _pickLine(_trim(map['legal_name']), d.legalName);
    final String innLine = _pickLine(
      _trim(map['inn_line']),
      _innLineFromApi(_trim(map['inn']), d.innLine),
    );
    final String phoneLine = _pickLine(
      _trim(map['phone_line']),
      _phoneLineFromApi(_trim(map['phone']), d.phoneLine),
    );
    final String address = _pickLine(_trim(map['address']), d.address);
    final String areaNote = _pickLine(_trim(map['area_note']), d.areaNote);
    final String tagline = _pickLine(_trim(map['tagline']), d.tagline);
    final String website = _pickLine(_trim(map['website']), d.website);
    final String userAgreementUrl = _pickLine(
      _trim(map['user_agreement_url']),
      d.userAgreementUrl,
    );
    return PdfCompanyRequisites(
      legalName: legalName,
      innLine: innLine,
      phoneLine: phoneLine,
      address: address,
      areaNote: areaNote,
      tagline: tagline,
      website: website,
      userAgreementUrl: userAgreementUrl,
    );
  }
}
