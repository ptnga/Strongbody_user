import 'package:flutter_test/flutter_test.dart';

import 'package:strongbody_buyer/modules/assistant/domain/entities/assistant_entities.dart';
import 'package:strongbody_buyer/modules/post_request/data/mappers/post_request_mapper.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/posted_request_entity.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/request_form_values.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/bloc/request_matches/request_matches_cubit.dart';

const _request = SentRequest(
  id: 42,
  description: 'Physio at home',
  budget: '50-80',
  deliveryTypes: [RequestDeliveryType.atHome, RequestDeliveryType.atClinic],
  sellerLanguages: ['vi'],
  categoryIds: [96654],
  status: 'active',
);

AssistantResult _result(Map<String, dynamic> raw) => AssistantResult(
  branch: 'search',
  kinds: const [],
  cards: const {},
  closeMatches: const {},
  totals: const {},
  raw: raw,
);

void main() {
  group('RequestFormValues (web forms.ts)', () {
    test('description must be 50–1000 characters after trim', () {
      expect(
        RequestFormValues.descriptionError('  '),
        DescriptionError.required,
      );
      expect(
        RequestFormValues.descriptionError('a' * 49),
        DescriptionError.tooShort,
      );
      expect(RequestFormValues.descriptionError('a' * 50), isNull);
      expect(
        RequestFormValues.descriptionError('a' * 1001),
        DescriptionError.tooLong,
      );
    });

    test('budget accepts amount, thousands separator or one range', () {
      for (final ok in ['', '100', '1,000', '120 - 150', '60–80']) {
        expect(RequestFormValues.isValidBudgetText(ok), isTrue, reason: ok);
      }
      for (final bad in ['abc', '1-2-3', '0', '-50', r'$100']) {
        expect(RequestFormValues.isValidBudgetText(bad), isFalse, reason: bad);
      }
    });
  });

  group('PostRequestMapper', () {
    test('form data sends anonymous, currency id and Me too link', () async {
      final form = await PostRequestMapper.createRequestFormData(
        userId: 7,
        values: const RequestFormValues(
          description: 'Need help',
          budget: '100',
          currencyId: 3,
          anonymous: true,
          similarToRequestId: 9,
          deliveryTypes: [RequestDeliveryType.atOffice],
        ),
      );
      final fields = Map.fromEntries(form.fields);
      expect(fields['currency_id'], '3');
      expect(fields['anonymous'], 'true');
      expect(fields['similar_to_request_id'], '9');
      expect(fields['delivery_type'], 'at_office');
    });

    test('created request reads data.data → data → root', () {
      expect(
        PostRequestMapper.createdRequest({
          'data': {
            'data': {'id': 42, 'status': 'active'},
          },
        }),
        const CreatedRequest(id: 42, status: 'active'),
      );
      expect(
        PostRequestMapper.createdRequest({
          'data': {'id': '7', 'status': 'pending'},
        }).id,
        7,
      );
    });

    test('sent request: budget range, all delivery = none, language names', () {
      final r = PostRequestMapper.sentRequest({
        'data': {
          'id': 42,
          'description': 'Physio',
          'min_budget': 50,
          'max_budget': 80,
          'delivery_type': 'all',
          'seller_languages': '["English","vi"]',
          'category_ids': '[96654]',
          'status': 'active',
        },
      })!;
      expect(r.budget, '50-80');
      expect(r.deliveryTypes, isEmpty);
      expect(r.sellerLanguages, ['en', 'vi']);
      expect(r.categoryIds, [96654]);
      expect(r.isLive, isTrue);
    });

    test('currencies: active only, featured first, then ordering', () {
      final list = PostRequestMapper.currencies({
        'data': {
          'list': [
            {'id': 1, 'name': 'usd', 'ordering': 2},
            {'id': 2, 'name': 'VND', 'ordering': 1},
            {'id': 3, 'name': 'EUR', 'is_featured': true},
            {'id': 4, 'name': 'GBP', 'is_active': false},
          ],
        },
      });
      expect(list.map((c) => c.code), ['EUR', 'VND', 'USD']);
    });
  });

  group('RequestMatchesCubit helpers', () {
    test('query adds the form preferences in English', () {
      expect(
        RequestMatchesCubit.requestQuery(_request),
        'Physio at home\n\nPreferences: where: at home, at a clinic; '
        'budget: 50–80 USD; languages: Vietnamese.',
      );
    });

    test('second pass only when the LLM missed a form choice', () {
      expect(
        RequestMatchesCubit.withFormFilters({
          'delivery_types': ['at_home', 'at_office'],
          'languages': ['vi'],
          'category_ids': [1],
        }, _request),
        isNull,
      );
      final strict = RequestMatchesCubit.withFormFilters({
        'delivery_types': ['at_home'],
        'languages': <String>[],
      }, _request)!;
      // at_clinic tìm như at_office (web).
      expect(strict['delivery_types'], ['at_home', 'at_office']);
      expect(strict['languages'], ['vi']);
      expect(strict['category_ids'], [96654]);
      expect(strict['relax'], isTrue);
    });

    test(
      'matches: sellers first, then service providers, no duplicates/self',
      () {
        final matches = RequestMatchesCubit.toMatches(
          _result({
            'cards': {
              'sellers': [
                {'user_id': 1, 'title': 'Ana', 'verified': true},
                {'user_id': 7, 'title': 'Me'},
              ],
              'services': [
                {'user_id': 1, 'id': 10, 'title': 'Massage', 'provider': 'Ana'},
                {
                  'user_id': 2,
                  'id': 11,
                  'title': 'Yoga',
                  'provider': 'Bao',
                  'country': 'Vietnam',
                  'country_code': 'VN',
                },
              ],
            },
          }),
          7,
        );
        expect(matches.map((m) => m.userId), [1, 2]);
        expect(matches.first.verified, isTrue);
        expect(matches.last.serviceTitle, 'Yoga');
        expect(matches.last.flag, 'https://flagcdn.com/w40/vn.png');
      },
    );
  });
}
