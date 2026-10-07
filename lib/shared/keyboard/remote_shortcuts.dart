import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Root shortcuts also cover dialogs, setup and nested navigators on TV.
final Map<ShortcutActivator, Intent> remoteShortcuts =
    <ShortcutActivator, Intent>{
      ...WidgetsApp.defaultShortcuts,
      const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
    };
