import 'package:flutter_test/flutter_test.dart';
import 'package:strongbody_buyer/core/utils/language_names.dart';
import 'package:strongbody_buyer/modules/social_market/data/mappers/market_mapper.dart';

void main() {
  group('languageLabel', () {
    test('code → English name, any case / region', () {
      expect(languageLabel('EN'), 'English');
      expect(languageLabel('en'), 'English');
      expect(languageLabel(' vi '), 'Vietnamese');
      expect(languageLabel('pt-BR'), 'Portuguese');
      expect(languageLabel('zh_CN'), 'Chinese (Simplified)');
    });

    test('names and unknown codes stay as they are', () {
      expect(languageLabel('English'), 'English');
      expect(languageLabel('Tiếng Việt'), 'Tiếng Việt');
      expect(languageLabel('xx'), 'xx');
    });
  });

  test('seller languages show names, not codes', () {
    expect(MarketMapper.sellerLanguageLabels(['en', 'VI'], null), [
      'English',
      'Vietnamese',
    ]);
    expect(
      MarketMapper.sellerLanguageLabels(null, [
        {'code': 'en', 'title': 'EN'},
        {'code': 'th'},
      ]),
      ['English', 'Thai'],
    );
  });

  test('service place = seller country → seller flag; address → no flag', () {
    final seller = {
      'id': 9,
      'seller_profile': {
        'shop_name': 'Ana',
        'country': {'title': 'Vietnam', 'code': 'VN'},
      },
    };
    final s = MarketMapper.service({'id': 1, 'title': 'Yoga', 'user': seller});
    expect(s.place, 'Vietnam');
    expect(s.placeFlag, 'https://flagcdn.com/w40/vn.png');

    final atAddress = MarketMapper.service({
      'id': 2,
      'title': 'Yoga',
      'address': '12 Le Loi, Hanoi',
      'user': seller,
    });
    expect(atAddress.place, '12 Le Loi, Hanoi');
    expect(atAddress.placeFlag, isNull);
  });
}
