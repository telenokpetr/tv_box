import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/shared/keyboard/remote_shortcuts.dart';
import 'package:tonkatsu_box/shared/navigation/nav_icon_button.dart';
import 'package:tonkatsu_box/shared/navigation/nav_tab.dart';
import 'package:tonkatsu_box/shared/theme/app_theme.dart';

void main() {
  testWidgets('TV arrows move focus and OK activates the destination', (
    WidgetTester tester,
  ) async {
    final List<int> selected = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        shortcuts: remoteShortcuts,
        home: Scaffold(
          body: FocusTraversalGroup(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < 2; i++)
                  NavIconButton(
                    destination: NavDestination(
                      tab: NavTab.values[i],
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home,
                      label: i == 0 ? 'Library' : 'Collections',
                    ),
                    active: i == 0,
                    width: 176,
                    height: 80,
                    onTap: () => selected.add(i),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    final BuildContext context = tester.element(
      find.byType(NavIconButton).first,
    );
    FocusScope.of(context).nextFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(selected, <int>[0]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(selected, <int>[0, 1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long Russian menu labels fit in a short TV sidebar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.15)),
            child: NavIconButton(
              destination: const NavDestination(
                tab: NavTab.collections,
                icon: Icons.folder,
                selectedIcon: Icons.folder,
                label: 'Мои коллекции',
              ),
              active: true,
              width: 176,
              height: 48,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
