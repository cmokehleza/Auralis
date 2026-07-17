import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);
  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('ar'), Locale('es')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const _values = <String, Map<String, String>>{
    'en': {
      'home': 'Home',
      'library': 'Library',
      'search': 'Search',
      'settings': 'Settings',
      'nowPlaying': 'Now playing',
      'tracks': 'tracks',
      'scan': 'Scan this phone',
      'phase3': 'Performance & connected devices',
    },
    'ar': {
      'home': 'الرئيسية',
      'library': 'المكتبة',
      'search': 'بحث',
      'settings': 'الإعدادات',
      'nowPlaying': 'قيد التشغيل',
      'tracks': 'مقاطع',
      'scan': 'فحص هذا الهاتف',
      'phase3': 'الأداء والأجهزة المتصلة',
    },
    'es': {
      'home': 'Inicio',
      'library': 'Biblioteca',
      'search': 'Buscar',
      'settings': 'Ajustes',
      'nowPlaying': 'Reproduciendo',
      'tracks': 'pistas',
      'scan': 'Escanear este teléfono',
      'phase3': 'Rendimiento y dispositivos conectados',
    },
  };

  String text(String key) =>
      _values[locale.languageCode]?[key] ?? _values['en']![key] ?? key;

  String number(num value) =>
      NumberFormat.decimalPattern(locale.toString()).format(value);
  String date(DateTime value) =>
      DateFormat.yMMMd(locale.toString()).format(value);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (item) => item.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
