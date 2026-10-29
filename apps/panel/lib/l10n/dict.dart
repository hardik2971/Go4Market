import 'dict_pages.dart';
import 'dict_shell.dart';

/// English UI string → [Hindi, Gujarati, Arabic]. Missing keys fall back to English.
final Map<String, List<String>> kDict = {...dictPages, ...dictShell};
