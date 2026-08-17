import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnplay/core/theme/app_theme.dart';
import 'package:gnplay/shared/widgets/design_system/gn_design_system.dart';

void main() {
  testWidgets('design system primitives mount together', (tester) async {
    final controller = TextEditingController(text: '+224 621 45 88 07');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: GnAppBackground(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GnTextField(
                    controller: controller,
                    label: 'Numéro de téléphone',
                  ),
                  const SizedBox(height: 12),
                  GnButton(label: 'Continuer', onPressed: () {}),
                  const SizedBox(height: 12),
                  const GnCard(child: Text('Surface')),
                  const SizedBox(height: 12),
                  const GnStatTile(
                    value: '38 942',
                    label: 'Vues totales',
                    icon: Icon(Icons.visibility_outlined),
                  ),
                  const SizedBox(height: 12),
                  const GnStatusPill(
                    label: 'CRÉATEUR',
                    tone: GnStatusTone.brand,
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: GnBottomNav(
            currentIndex: 0,
            onTap: (_) {},
            items: const [
              GnBottomNavItem(
                label: 'Accueil',
                icon: Icon(Icons.home_outlined),
              ),
              GnBottomNavItem(
                label: 'Publier',
                icon: Icon(Icons.add),
                isFab: true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Continuer'), findsOneWidget);
    expect(find.text('Surface'), findsOneWidget);
    expect(find.text('CRÉATEUR'), findsOneWidget);
    expect(find.text('Accueil'), findsOneWidget);
  });
}
