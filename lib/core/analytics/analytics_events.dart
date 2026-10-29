/// Tên event PostHog (snake_case như Multime). Thêm event mới ở đây rồi gọi
/// `AppAnalytics.capture(AnalyticsEvents.x, {...})` tại chỗ xảy ra hành động.
///
/// Mọi event tự có `environment` (dev/prod); screen view (`$screen`) tự ghi theo route.
/// Không gửi nội dung người dùng gõ / nói (có thể là thông tin sức khoẻ) — chỉ gửi độ dài.
abstract final class AnalyticsEvents {
  // ---------------------------------------------------------------- app / phiên
  /// Mở app (sau khi PostHog khởi tạo).
  static const appOpen = 'app_open';

  /// Đăng xuất (tự bấm hoặc hết phiên). Sau event này PostHog reset danh tính.
  static const userLoggedOut = 'user_logged_out';

  // ---------------------------------------------------------------- home
  /// Gửi câu tìm ở Home → danh sách provider.
  /// `source` composer|typing_suggestion|recent_search, `query_length`, `attachments_count`.
  static const homeSearchSubmitted = 'home_search_submitted';

  /// Bấm thẻ gợi ý ở Home (Physiotherapist…) → "Here's what I heard". `prompt`.
  static const homePromptTapped = 'home_prompt_tapped';

  /// Bấm pill "N new offers" ở Home → My requests. `count`.
  static const homeNewOffersTapped = 'home_new_offers_tapped';

  // ---------------------------------------------------------------- voice
  /// Mở màn nói yêu cầu. `source` home|bottom_nav|menu|messages|my_requests|heard|providers|providers_refine, `refine`.
  static const voiceRequestOpened = 'voice_request_opened';

  /// Nói xong, bấm ✓ (hoặc tự dừng) → sang bước sau.
  /// `source`, `refine`, `has_voice_note`, `voice_duration_sec`, `language`, `transcript_words`.
  static const voiceRequestSubmitted = 'voice_request_submitted';

  /// Đóng màn nói khi chưa gửi. `source`.
  static const voiceRequestClosed = 'voice_request_closed';

  /// Hiện màn lỗi giọng nói. `problem` noSpeech|micOff|unavailable, `source`.
  static const voiceProblemShown = 'voice_problem_shown';

  /// Bấm "Type instead" trên màn nói. `source`, `problem`.
  static const voiceTypeInsteadTapped = 'voice_type_instead_tapped';

  // ---------------------------------------------------------------- post request
  /// AI phân tích yêu cầu xong ("Here's what I heard").
  /// `outcome` filled|empty|failed, `notice`, `has_voice`, `transcribed`, `match_count`, `category_id`, `quality_score`.
  static const requestAnalysisCompleted = 'request_analysis_completed';

  /// Bấm nút ở "Here's what I heard". `action` post_request|browse_providers|say_again, `match_count`.
  static const heardActionTapped = 'heard_action_tapped';

  /// Xoá / hoàn tác voice note ở Review.
  static const requestVoiceNoteRemoved = 'request_voice_note_removed';
  static const requestVoiceNoteRestored = 'request_voice_note_restored';

  /// Bấm Post ở Review nhưng form thiếu. `missing` (description,delivery,budget).
  static const requestReviewInvalid = 'request_review_invalid';

  /// Đăng request thành công (event chuyển đổi chính).
  /// `status` (BE: active|pending), `visibility`, `providers_selected`, `has_voice`, `attachments_count`,
  /// `delivery_types`, `has_budget`, `has_schedule`, `category_id`.
  static const requestPosted = 'request_posted';

  /// Đăng request lỗi. `error`.
  static const requestPostFailed = 'request_post_failed';

  /// Bấm nút ở màn "Request posted". `action` my_requests|home.
  static const requestPostedCtaTapped = 'request_posted_cta_tapped';

  // ---------------------------------------------------------------- providers
  /// Tải xong trang đầu danh sách provider. `keyword`, `total`, `active_filters`.
  static const providersResultsLoaded = 'providers_results_loaded';

  /// Sửa từ khoá tìm provider. `keyword`.
  static const providersKeywordEdited = 'providers_keyword_edited';

  /// Bật / tắt chip lọc. `filter` delivery|dates|budget|language|topRated, `active`.
  static const providersFilterToggled = 'providers_filter_toggled';

  /// Lọc bằng giọng nói ("Refine by voice") thành công.
  static const providersRefinedByVoice = 'providers_refined_by_voice';

  /// Bấm nhắn tin (voice message) với provider → chat. `provider_id`.
  static const providerMessageTapped = 'provider_message_tapped';

  /// Bấm "Request offer" ở thẻ provider → Review. `provider_id`.
  static const providerRequestOfferTapped = 'provider_request_offer_tapped';

  /// Chọn / bỏ chọn provider (chế độ chọn người nhận). `provider_id`, `selected`.
  static const providerSelectionToggled = 'provider_selection_toggled';

  /// Bấm Done sau khi chọn provider. `count`.
  static const providersSelectionDone = 'providers_selection_done';

  /// "Not sure who to pick? · Post request" → đăng cho mọi provider phù hợp. `match_count`.
  static const providersPostToAllTapped = 'providers_post_to_all_tapped';

  // ---------------------------------------------------------------- auth
  /// Mở sheet đăng nhập / đăng ký.
  /// `source` post_request|providers|my_requests|messages|chat|account, `screen` signup|login.
  static const authSheetOpened = 'auth_sheet_opened';

  /// Đóng sheet đăng nhập. `source`, `signed_in`.
  static const authSheetClosed = 'auth_sheet_closed';

  /// Đăng ký xong (đã đăng nhập). `method` email.
  static const signUpCompleted = 'sign_up_completed';

  /// Đăng nhập xong. `method` email|google|apple.
  static const loginCompleted = 'login_completed';

  /// Lỗi ở một bước đăng nhập. `step` sign_up|login|social|otp|forgot_otp|reset_password, `reason`.
  static const authFailed = 'auth_failed';

  /// BE yêu cầu nhập mã OTP xác minh email. `step` sign_up|login.
  static const emailVerificationRequired = 'email_verification_required';

  /// Đặt lại mật khẩu thành công.
  static const passwordResetCompleted = 'password_reset_completed';

  // ---------------------------------------------------------------- my requests / offers
  /// Đổi tab Active / Closed. `tab`.
  static const myRequestsTabChanged = 'my_requests_tab_changed';

  /// Bấm thẻ request → trang Offers. `request_id`, `status`, `offers_count`.
  static const requestCardTapped = 'request_card_tapped';

  /// Đổi cách sắp xếp offer. `sort`.
  static const offersSortChanged = 'offers_sort_changed';

  /// Bấm Reply ở offer → chat. `offer_id`, `request_id`, `seller_id`.
  static const offerReplyTapped = 'offer_reply_tapped';

  /// Bấm "Details" ở dải offer trong chat → trang Offers. `offer_id`, `request_id`.
  static const chatOfferDetailsTapped = 'chat_offer_details_tapped';

  // ---------------------------------------------------------------- checkout
  /// Bấm "Accept & Pay" → mở sheet thanh toán.
  /// `source` offers|chat, `offer_id`, `request_id`, `seller_id`, `price`, `currency`.
  static const checkoutOpened = 'checkout_opened';

  /// Đóng sheet thanh toán mà chưa trả. `offer_id`.
  static const checkoutDismissed = 'checkout_dismissed';

  /// Thêm thẻ (Stripe). `success`.
  static const checkoutCardAdded = 'checkout_card_added';

  /// Bật / tắt dùng Lion Points. `use_points`.
  static const checkoutPointsToggled = 'checkout_points_toggled';

  /// Bấm Pay. `offer_id`, `total`, `points_used`, `method` card|free.
  static const checkoutPayTapped = 'checkout_pay_tapped';

  /// Thanh toán thành công (event doanh thu).
  /// `offer_id`, `request_id`, `seller_id`, `price`, `total`, `points_used`, `points_value`, `currency`, `voucher`.
  static const paymentSucceeded = 'payment_succeeded';

  /// Đã trả nhưng BE chưa xác nhận (đang xử lý). `offer_id`, `total`.
  static const paymentPending = 'payment_pending';

  /// Người dùng huỷ ở bước Stripe. `offer_id`.
  static const paymentCancelled = 'payment_cancelled';

  /// Thanh toán lỗi. `offer_id`, `error`.
  static const paymentFailed = 'payment_failed';

  // ---------------------------------------------------------------- chat
  /// Mở chat 1:1. `source` messages|providers|offer_reply|checkout, `partner_id`, `from_offer`.
  static const chatOpened = 'chat_opened';

  /// Gửi tin thành công. `type` text|voice, `partner_id`, `length` / `duration_sec`.
  static const chatMessageSent = 'chat_message_sent';

  /// Gửi tin lỗi. `type`.
  static const chatMessageFailed = 'chat_message_failed';

  /// Bật / tắt tự dịch trong chat. `enabled`.
  static const chatAutoTranslateToggled = 'chat_auto_translate_toggled';

  // ---------------------------------------------------------------- account
  /// Đổi cài đặt ở Account.
  /// `setting` speaking_language|auto_translate|read_aloud|attach_voice, `value`.
  static const accountSettingChanged = 'account_setting_changed';

  /// Lưu hồ sơ (tên / thành phố) thành công.
  static const profileUpdated = 'profile_updated';
}
