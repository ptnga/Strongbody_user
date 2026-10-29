import 'package:get_it/get_it.dart';

import 'package:strongbody_buyer/core/network/api.dart';
import 'package:strongbody_buyer/core/services/stripe_payment_service.dart';
import 'package:strongbody_buyer/modules/account/domain/usecases/account_use_cases.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/my_request_entity.dart';

import '../data/datasources/remote/checkout_remote_datasource.dart';
import '../data/repositories/checkout_repository_impl.dart';
import '../domain/repositories/checkout_repository.dart';
import '../domain/usecases/checkout_use_cases.dart';
import '../presentation/bloc/offer_checkout/offer_checkout_bloc.dart';

/// Datasource/repository/Stripe: `registerLazySingleton`; UseCase/Bloc: `registerFactory`.
void registerCheckoutModule(GetIt getIt) {
  getIt
    ..registerLazySingleton<StripePaymentService>(StripePaymentServiceImpl.new)
    ..registerLazySingleton<CheckoutRemoteDataSource>(
      () => CheckoutRemoteDataSourceImpl(getIt<ApiClient>()),
    )
    ..registerLazySingleton<CheckoutRepository>(
      () => CheckoutRepositoryImpl(
        getIt<CheckoutRemoteDataSource>(),
        getIt<StripePaymentService>(),
      ),
    )
    ..registerFactory(() => GetPaymentCardsUseCase(getIt<CheckoutRepository>()))
    ..registerFactory(() => AddPaymentCardUseCase(getIt<CheckoutRepository>()))
    ..registerFactory(() => PayOfferUseCase(getIt<CheckoutRepository>()))
    ..registerFactoryParam<OfferCheckoutBloc, RequestOfferEntity, void>(
      (offer, _) => OfferCheckoutBloc(
        offer: offer,
        getCards: getIt<GetPaymentCardsUseCase>(),
        addCard: getIt<AddPaymentCardUseCase>(),
        payOffer: getIt<PayOfferUseCase>(),
        getLionPoints: getIt<GetLionPointsUseCase>(),
      ),
    );
}
