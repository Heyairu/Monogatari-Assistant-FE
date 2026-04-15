import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monogatari_assistant/presentation/providers/project_state_providers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('CharacterView provider state persistence', () async {
    final container = ProviderContainer();

    final initialData = {
      'character1': {
        'name': '角色一',
        'age': '25',
        'gender': '女性',
      },
    };

    // 設置初始狀態
    container.read(characterDataProvider.notifier).state = initialData;

    // 驗證初始狀態
    expect(
      container.read(characterDataProvider)['character1']?['name'],
      '角色一',
    );

    // 驗證可以修改狀態
    final updatedData = {
      'character1': {
        'name': '修改後的角色',
        'age': '26',
        'gender': '女性',
      },
    };

    container.read(characterDataProvider.notifier).state = updatedData;

    // 驗證狀態已更新
    expect(
      container.read(characterDataProvider)['character1']?['name'],
      '修改後的角色',
    );
  });
}
