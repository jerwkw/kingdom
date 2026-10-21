import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tabs hosted by MainShell, in display order.
enum ShellTab { avatar, neighbourhood, tasks, store }

/// The selected MainShell tab. Defaults to Tasks for quick check-ins.
final shellTabProvider = StateProvider<ShellTab>((ref) => ShellTab.tasks);
