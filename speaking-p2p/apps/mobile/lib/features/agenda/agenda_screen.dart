import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/ui/placeholder_screen.dart';

class AgendaScreen extends StatelessWidget {
  const AgendaScreen({super.key});
  @override
  Widget build(BuildContext context) => PlaceholderScreen(title: context.l10n.agendaTitle);
}
