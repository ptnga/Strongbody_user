import 'package:get_it/get_it.dart';

import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/network/api.dart';
import 'package:strongbody_buyer/modules/chat/domain/usecases/chat_use_cases.dart';

import '../data/datasources/remote/social_market_remote_datasource.dart';
import '../data/repositories/social_market_repository_impl.dart';
import '../data/services/market_chat_publisher.dart';
import '../domain/entities/market_category.dart';
import '../domain/entities/market_feed_entities.dart';
import '../domain/entities/market_listing_entities.dart';
import '../domain/repositories/social_market_repository.dart';
import '../domain/usecases/social_market_use_cases.dart';
import '../presentation/bloc/category_market/category_market_bloc.dart';
import '../presentation/bloc/engagement/engagement_cubit.dart';
import '../presentation/bloc/inquiry/inquiry_cubit.dart';
import '../presentation/bloc/market_listing/listing_facets_cubit.dart';
import '../presentation/bloc/market_listing/market_listing_bloc.dart';
import '../presentation/bloc/medical_travel/appointment_cubit.dart';
import '../presentation/bloc/medical_travel/destination_cubit.dart';
import '../presentation/bloc/medical_travel/service_detail_cubit.dart';
import '../presentation/market_navigation.dart';

/// Datasource/repository: `registerLazySingleton`; UseCase/Bloc: `registerFactory`.
/// Đăng ký SAU chat module (gửi inquiry mở kênh chat qua `OpenChatSessionUseCase`).
void registerSocialMarketModule(GetIt getIt) {
  getIt
    ..registerLazySingleton<SocialMarketRemoteDataSource>(
      () => SocialMarketRemoteDataSourceImpl(getIt<ApiClient>()),
    )
    ..registerLazySingleton(MarketChatPublisher.new)
    ..registerLazySingleton<SocialMarketRepository>(
      () => SocialMarketRepositoryImpl(
        getIt<SocialMarketRemoteDataSource>(),
        getIt<GlobalStorage>(),
        getIt<OpenChatSessionUseCase>(),
        getIt<MarketChatPublisher>(),
      ),
    )
    ..registerFactory(
      () => GetMarketServicesUseCase(getIt<SocialMarketRepository>()),
    )
    ..registerFactory(
      () => GetMarketExpertsUseCase(getIt<SocialMarketRepository>()),
    )
    ..registerFactory(
      () => GetServicesByCategoryUseCase(getIt<SocialMarketRepository>()),
    )
    ..registerFactory(
      () => GetServiceClassificationsUseCase(getIt<SocialMarketRepository>()),
    )
    ..registerFactory(
      () => GetPublicOffersUseCase(getIt<SocialMarketRepository>()),
    )
    ..registerFactory(
      () => GetPublicRequestsUseCase(getIt<SocialMarketRepository>()),
    )
    ..registerFactory(
      () => GetHealthSolutionsUseCase(getIt<SocialMarketRepository>()),
    )
    ..registerFactory(
      () => GetEngagementUseCase(getIt<SocialMarketRepository>()),
    )
    ..registerFactory(
      () => SetEngagementUseCase(getIt<SocialMarketRepository>()),
    )
    ..registerFactory(() => SendInquiryUseCase(getIt<SocialMarketRepository>()))
    ..registerFactory(
      () => MatchHealthSolutionUseCase(getIt<SocialMarketRepository>()),
    )
    ..registerFactory(
      () => CategoryMarketBloc(
        getServicesByCategory: getIt<GetServicesByCategoryUseCase>(),
        getExperts: getIt<GetMarketExpertsUseCase>(),
        getDestinations: getIt<GetDestinationsUseCase>(),
      ),
    )
    ..registerFactoryParam<EngagementCubit, EngagementTarget, void>(
      (target, _) => EngagementCubit(
        target: target,
        getEngagement: getIt<GetEngagementUseCase>(),
        setEngagement: getIt<SetEngagementUseCase>(),
        storage: getIt<GlobalStorage>(),
      ),
    )
    ..registerFactory(
      () => InquiryCubit(sendInquiry: getIt<SendInquiryUseCase>()),
    )
    // param2: category doanh nghiệp đang chọn (`?category=`) của trang nhãn; bộ lọc
    // phụ của bloc = tab service classification.
    ..registerFactoryParam<
      MarketListingBloc<MarketServiceEntity>,
      MarketPageScope,
      String?
    >(
      (scope, category) => MarketListingBloc<MarketServiceEntity>(
        fetch: (page, classification) => getIt<GetMarketServicesUseCase>()(
          listingParams(
            scope,
            page,
            newestFirst: true,
            subCategory: ListingFacetsCubit.validCategory(scope, category),
            classification: classification,
          ),
        ),
        idOf: (s) => s.id,
      ),
    )
    ..registerFactory(
      () => ListingFacetsCubit(
        getSections: getIt<GetServicesByCategoryUseCase>(),
        getClassifications: getIt<GetServiceClassificationsUseCase>(),
      ),
    )
    ..registerFactoryParam<
      MarketListingBloc<MarketExpertEntity>,
      MarketPageScope,
      void
    >(
      (scope, _) => MarketListingBloc<MarketExpertEntity>(
        fetch: (page, _) =>
            getIt<GetMarketExpertsUseCase>()(listingParams(scope, page)),
        idOf: (e) => e.id,
      ),
    )
    // Medical Travel
    ..registerFactory(
      () => GetCoordinatorsUseCase(getIt<SocialMarketRepository>()),
    )
    ..registerFactory(
      () => GetDestinationsUseCase(getIt<SocialMarketRepository>()),
    )
    ..registerFactory(
      () => GetMedicalServicesUseCase(getIt<SocialMarketRepository>()),
    )
    ..registerFactory(
      () => GetCountrySellersUseCase(getIt<SocialMarketRepository>()),
    )
    ..registerFactory(
      () => GetServiceDetailUseCase(getIt<SocialMarketRepository>()),
    )
    ..registerFactory(
      () => SendAppointmentRequestUseCase(getIt<SocialMarketRepository>()),
    )
    ..registerFactory(() => GetCountryUseCase(getIt<SocialMarketRepository>()))
    ..registerFactory(
      () => GetPhoneCodesUseCase(getIt<SocialMarketRepository>()),
    )
    ..registerFactory(
      () => ServiceDetailCubit(getDetail: getIt<GetServiceDetailUseCase>()),
    )
    ..registerFactory(
      () => AppointmentCubit(
        getPhoneCodes: getIt<GetPhoneCodesUseCase>(),
        getDetail: getIt<GetServiceDetailUseCase>(),
        send: getIt<SendAppointmentRequestUseCase>(),
      ),
    )
    ..registerFactory(
      () => DestinationCubit(
        getCountry: getIt<GetCountryUseCase>(),
        getServices: getIt<GetMedicalServicesUseCase>(),
        getSellers: getIt<GetCountrySellersUseCase>(),
        getDestinations: getIt<GetDestinationsUseCase>(),
      ),
    );
}
