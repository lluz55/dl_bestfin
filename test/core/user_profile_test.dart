import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bestfin/core/providers/user_profile_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserProfile', () {
    test('vazio: sem nome, foto, primeiro nome ou iniciais', () {
      const profile = UserProfile();
      expect(profile.hasName, isFalse);
      expect(profile.hasPhoto, isFalse);
      expect(profile.firstName, isNull);
      expect(profile.initials, isNull);
    });

    test('nome em branco é tratado como ausente', () {
      const profile = UserProfile(name: '   ');
      expect(profile.hasName, isFalse);
      expect(profile.firstName, isNull);
      expect(profile.initials, isNull);
    });

    test('firstName retorna só o primeiro nome', () {
      const profile = UserProfile(name: 'Lucas da Luz');
      expect(profile.firstName, 'Lucas');
    });

    test('initials usa primeiro e último nome', () {
      expect(const UserProfile(name: 'Lucas da Luz').initials, 'LL');
      expect(const UserProfile(name: 'lucas').initials, 'L');
      expect(const UserProfile(name: '  Ana  Maria ').initials, 'AM');
    });
  });

  group('UserProfileNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      initialUserName = null;
      initialUserPhotoPath = null;
    });

    test('seed inicial vem das variáveis globais', () {
      initialUserName = 'Lucas';
      initialUserPhotoPath = '/tmp/foto.jpg';
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final profile = container.read(userProfileProvider);
      expect(profile.name, 'Lucas');
      expect(profile.photoPath, '/tmp/foto.jpg');
    });

    test('setName persiste em SharedPreferences e atualiza o estado', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(userProfileProvider.notifier).setName('  Lucas  ');

      expect(container.read(userProfileProvider).name, 'Lucas');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kUserNameKey), 'Lucas');
    });

    test('setName com string vazia remove o nome salvo', () async {
      initialUserName = 'Lucas';
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(userProfileProvider.notifier).setName('');

      expect(container.read(userProfileProvider).name, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kUserNameKey), isNull);
    });
  });
}
