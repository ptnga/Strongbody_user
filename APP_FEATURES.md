# StrongBody Buyer — Mô tả ứng dụng và chức năng

## 1. Tổng quan

**StrongBody Buyer** là ứng dụng di động (iOS và Android) dành cho **người mua dịch vụ** trên nền tảng StrongBody, gồm dịch vụ sức khỏe, chăm sóc, làm đẹp, thể chất và du lịch y tế. Người dùng nói hoặc gõ điều mình cần bằng ngôn ngữ của mình. Ứng dụng dùng AI để hiểu yêu cầu, tìm nhà cung cấp phù hợp, gửi yêu cầu để nhận báo giá (offer), trò chuyện có dịch tự động, rồi chấp nhận và thanh toán ngay trong app.

**Ý tưởng chính:** "Nói điều bạn cần, nhà cung cấp sẽ đến với bạn."

- **Ưu tiên giọng nói:** bấm "Get help" và nói yêu cầu; AI chuyển giọng nói thành chữ và tự điền form yêu cầu.
- **Không rào cản ngôn ngữ:** tin nhắn được dịch tự động hai chiều, có thể nghe đọc to câu trả lời.
- **Trợ lý AI:** hỏi đáp theo kiểu trò chuyện để tìm chuyên gia, dịch vụ hoặc soạn sẵn yêu cầu.
- **Thanh toán an toàn:** trả bằng thẻ, tiền được giữ qua Smart Escrow và chỉ chuyển cho nhà cung cấp khi buổi dịch vụ hoàn tất.

**Ngôn ngữ giao diện:** tiếng Anh và tiếng Việt.

**Hai phiên bản cài đặt:**
- Bản thử nghiệm (Dev), tên hiển thị "StrongBody Buyer Dev".
- Bản chính thức (Prod).

Hai bản có thể cài song song trên cùng một máy.

---

## 2. Điều hướng chính

### 2.1 Thanh điều hướng dưới
Ứng dụng có 4 tab và 1 nút ở giữa:

| Vị trí | Tên | Chức năng |
|---|---|---|
| 1 | **Discover** | Trang chủ: board Requests và Offers |
| 2 | **Requests** | Các yêu cầu đã đăng; badge hiện số offer mới |
| Giữa | **Get help** (nút micro nổi) | Mở sheet ghi âm để đăng yêu cầu |
| 3 | **Messages** | Danh sách hội thoại; badge hiện số tin chưa đọc |
| 4 | **Account** | Tài khoản, Lion Points, cài đặt |

- Thanh dưới hiện ở mọi tab, kể cả trang chủ (giống fly-bar của web).
- Mỗi tab giữ nguyên trạng thái khi chuyển qua lại, kể cả vị trí cuộn và dữ liệu đã tải.
- Bấm Back ở một tab khác Home sẽ quay về Home.

### 2.2 Menu ☰ ở Home
- **New request:** mở sheet ghi âm "Get help".
- **My requests:** kèm badge số offer mới.
- **Messages:** kèm badge số tin chưa đọc.
- **Social Market:** mở rộng ra danh sách các chợ: Longevity, Health Pro Advisory, Personal Helper, Medical Travel.
- **Browse providers:** duyệt danh sách nhà cung cấp.
- **Recent:** các yêu cầu gần đây, chạm vào để xem offer của yêu cầu đó.
- **Hồ sơ người dùng** ở cuối menu: tên và số Lion Points. Khi chưa đăng nhập thì hiện "Sign in".

### 2.3 Màn khởi động (Splash)
Nền trắng, logo StrongBody ở giữa, hiện trong thời gian ngắn rồi tự chuyển vào Home.

---

## 3. Trang chủ (Discover)

Giống trang chủ web: không còn ô hỏi trợ lý, mở đầu bằng thanh tab **Requests · Offers** (mặc định Requests). Mỗi board có ô tìm kiếm, nút **Filters**, cuộn để tải thêm (10 mục mỗi lần) và kéo xuống để làm mới.

### 3.1 Board Requests ("Community health requests")
- Nút **Post a request** ở đầu board mở sheet "Get help".
- **Chủ đề:** Longevity, Medical Travel, Health Pro Advisory, Personal Helper. Chạm để lọc, chạm lại để bỏ. Chọn chủ đề thì bỏ tìm kiếm/bộ lọc, và ngược lại.
- **Mỗi thẻ request:**
  - Người đăng (ẩn danh hiện "***"), cờ và nước, thời gian đăng; badge "Closed" và chủ đề.
  - Nội dung 3 dòng kèm "See more"; ảnh (chạm để xem lớn) và file đính kèm.
  - Hình thức nhận dịch vụ, tối đa 2 ngôn ngữ, "Willing to pay" kèm ngân sách.
  - **Me too:** mở form "Post a request" điền sẵn nội dung và hình thức của request đó, để đăng request tương tự.
  - Request của chính mình: nút **Manage my request** (về My requests).
  - Request đã giải quyết hiện "✓ Solved".
  - Dải hoạt động: avatar người đã trả lời và "{n} replied" (hoặc "Be the first to respond"), "{n} need this too", "{n} likes"; nút **Like** và **Save** (khách sẽ được mời đăng nhập).
- **Bộ lọc:** Sort by, Posted, Delivery, Budget, Responses, Country.

### 3.2 Board Offers ("Offers from real experts")
- **Mỗi dòng offer:** ảnh, tên dịch vụ, nhà cung cấp (cờ, "Verified"), mô tả; giá thấp nhất ("From" khi có nhiều mức giá) hoặc "✈ Medical Travel"; hình thức cung cấp.
- **Book** mở trang dịch vụ. **Free consult** (dịch vụ có tư vấn miễn phí) mở form gửi yêu cầu với lời nhắn soạn sẵn.
- **Bộ lọc:** Sort by, Posted, Delivery, Price, Provider (đã xác minh / có lựa chọn miễn phí), Language, Country.

### 3.3 Tìm kiếm và bộ lọc
- Ô tìm kiếm chạy sau khi ngừng gõ 400ms (hoặc bấm Enter).
- Có từ khóa hoặc bộ lọc thì hiện số kết quả và chip từng bộ lọc (bỏ được từng cái), kèm "Clear filters".
- Không có kết quả: gợi ý **Clear filters** và **+ Post a request**.

---

## 4. Trợ lý AI (StrongBody assistant)

Mở từ ô nhập ở đầu các trang Social Market.

### 4.1 Hỏi đáp nhiều lượt
- Người dùng có thể hỏi về nhà cung cấp, dịch vụ hoặc bất cứ điều gì về StrongBody.
- Có thể hỏi tiếp không giới hạn để thu hẹp kết quả. Ví dụ: "cheaper", "online only", "does the second one speak English?". Trợ lý hiểu câu hỏi theo ngữ cảnh các lượt trước.
- Màn trống có sẵn câu ví dụ ("Try asking"): tìm health coach, lên kế hoạch du lịch y tế, cải thiện giấc ngủ, tìm dịch vụ Longevity Companion.
- Câu trả lời hiện dần trong lúc AI đang trả lời (streaming). Trạng thái được hiển thị rõ: "Understanding your question…", "Finding providers for you…", "Looking it up in StrongBody guides…", "Preparing your request…".
- Các nút **Stop** (dừng câu trả lời), **Try again** (khi lỗi) và **New chat** (xóa hội thoại, có hỏi xác nhận).
- Hội thoại được lưu trên máy để lần sau mở lại vẫn còn. Hội thoại bị xóa khi đăng xuất.

### 4.2 Các kiểu câu trả lời
- **Kết quả tìm kiếm:** chia nhóm Services, Providers và Offers, mỗi nhóm hiện "x of y".
  - Thẻ kết quả giống thẻ của Social Market nhưng không có nút thích/lưu.
  - Nhóm **"Close matches"** là các kết quả gần đúng, ghi rõ tiêu chí chưa khớp: ngôn ngữ, giới tính, hình thức gặp, ngân sách, đã xác minh, kinh nghiệm.
  - Nút **See all results** để xem toàn bộ kết quả.
- **Soạn yêu cầu:** trợ lý điền sẵn form yêu cầu và gợi ý cách viết để nhận offer tốt hơn ("To get better offers: …"). Kèm danh sách nhà cung cấp có thể giúp và nút **Review & post request** mở thẳng form "Post a request" với nội dung đã điền.
- **Không có kết quả:** gợi ý **Post a request instead** để nhà cung cấp chủ động gửi offer.
- **Câu hỏi về StrongBody:** trả lời từ tài liệu hướng dẫn của StrongBody.
- **Ngoài phạm vi:** trợ lý cho biết chỉ hỗ trợ các chủ đề sức khỏe, wellness và dịch vụ StrongBody.

### 4.3 Tìm theo vị trí
Khi câu hỏi cần vị trí ("gần tôi"), trợ lý xin quyền dùng vị trí hiện tại. Vị trí chỉ dùng cho lần tìm đó.
- Nếu người dùng từ chối hoặc không lấy được vị trí, trợ lý gợi ý nói tên khu vực, ví dụ "near District 1".
- Nếu không có ai ngay tại khu vực, trợ lý ghi rõ đang hiển thị các lựa chọn gần nhất hoặc online.

### 4.4 Giới hạn
Khi người dùng gửi quá nhiều tin trong thời gian ngắn, app báo cần chờ một lát rồi thử lại.

---

## 5. Đăng yêu cầu (Post Request)

Giống luồng web: **Get help (nói hoặc gõ) → AI soạn form → kiểm tra → đăng → Providers for your request.**

### 5.1 Sheet "Get help"
Mở từ nút giữa thanh dưới, "Post a request" trên board, menu "New request", My requests và Messages.

- Mở ra là bật micro ngay, kèm sóng âm theo giọng nói thật và bộ đếm thời gian. Không hiện chữ trong lúc nói.
- Nút gửi lớn ở giữa, nút hủy bên trái. Tối đa 120 giây, hết giờ tự gửi.
- Không bật được micro hoặc không ghi được tiếng: hiện ô gõ chữ để nhập yêu cầu.
- Nếu bật "Attach my voice to requests" trong Account, bản ghi được gửi kèm yêu cầu làm voice note.

### 5.2 Màn "Post a request"
- Form hiện ngay nhưng bị khóa, kèm thẻ tiến trình: "Converting your voice to text…" rồi "AI is analysing your request…" và phần trăm.
- AI xong thì form mở khóa với nội dung đã điền; tiêu đề đổi thành "Review and post your request".
- **Các trường:**
  - Mô tả (50–1000 ký tự, bộ đếm "n/1000") với nút đính kèm ảnh/tệp ngay trong ô (mỗi tệp tối đa 20MB).
  - **Your preferred budget:** một số hoặc khoảng, kèm ô chọn tiền tệ lấy từ danh sách tiền tệ của hệ thống.
  - **Where would you like to receive the service?:** Remote, At office, At clinic, At home (chọn nhiều).
  - **Working language:** mặc định là ngôn ngữ của app, chọn thêm hoặc bỏ được.
  - **Post anonymously:** ẩn thông tin cá nhân cho đến khi nhận được báo giá.
- Nút **Send request** dính ở đáy màn.
- **Lỗi:** không chuyển được giọng nói, bản ghi trống hoặc AI không soạn được thì báo lỗi và giữ phần đã có để người dùng tự hoàn thiện.
- **Chưa đăng nhập:** bấm gửi sẽ mở màn đăng ký. Đăng ký xong, yêu cầu được đăng tự động.
- Mở từ "Request offer" của một nhà cung cấp: form gửi riêng cho người đó (không có Working language và Post anonymously).

### 5.3 "Providers for your request"
- Xác nhận "Your request is posted" (đã hiển thị, hoặc đang được duyệt), nội dung yêu cầu, Budget · Where · Languages.
- **Providers matched to your request:** tối đa 6 chuyên gia do trợ lý tìm kiếm gợi ý theo đúng yêu cầu (kèm cờ, dấu xác minh, dịch vụ liên quan).
- Nút **Chat** gửi thẻ yêu cầu kèm lời chào vào cuộc trò chuyện rồi mở chat, để chuyên gia biết người dùng cần gì.
- Link **View my requests**.

### 5.5 Matching providers (tìm và chọn nhà cung cấp)
- Danh sách nhà cung cấp phù hợp với yêu cầu. Mỗi thẻ có ảnh, tên, dấu xác minh, số năm kinh nghiệm, đánh giá, ngôn ngữ, giá mỗi buổi, lịch trống và voice giới thiệu (nếu có).
- **Tìm theo nghề,** ví dụ "physiotherapist".
- **Bộ lọc nhanh dạng chip:** Online, At home, At clinic, This weekend, Top rated, Under {giá}, Speaks {ngôn ngữ}. Có nút **Clear filters**.
- **Lọc bằng giọng nói:** nói câu như "only women providers", "speaks Vietnamese", "under $70". AI chuyển câu nói thành bộ lọc.
- **Request offer:** mở form gửi yêu cầu riêng cho người đó.
- **Post request:** mở sheet "Get help" để đăng cho tất cả nhà cung cấp phù hợp.
- **Không có kết quả:** gợi ý bỏ bớt bộ lọc hoặc đăng yêu cầu.

---

## 6. Theo dõi yêu cầu và offer

### 6.1 My requests (tab Requests)
- Hai tab: **Active** và **Closed**.
- Mỗi yêu cầu hiển thị:
  - Thời gian đăng (hôm nay, hôm qua, ngày cụ thể), nội dung và voice note.
  - Hình thức nhận dịch vụ, thời gian mong muốn (Today, Tomorrow, This weekend) và ngân sách.
  - Số offer, số nhà cung cấp đã phản hồi, khoảng giá và nhà cung cấp được đánh giá cao nhất.
  - Badge "new offers" khi có offer mới.
- **Trạng thái:** In review, Waiting for offers, Booked (kèm tên người đã đặt), Completed, Closed, Expired, Canceled.
- Nút **Compare** để xem và so sánh offer, nút **Speak a request** để đăng yêu cầu mới.
- Có màn trống riêng cho từng trường hợp: chưa đăng nhập, chưa có yêu cầu, không có yêu cầu đang mở, không có yêu cầu đã đóng.

### 6.2 Offers của một yêu cầu
- Danh sách mọi offer nhà cung cấp đã gửi. Mỗi offer có giá mỗi buổi, hình thức (online, tại nhà, tại phòng khám), thời gian và dấu "Verified provider".
- **Sắp xếp:** Best match, Lowest price, Soonest.
- **Hành động:** **Accept & Pay** (mở thanh toán) hoặc **Reply** (nhắn tin với nhà cung cấp).
- Khi mở từ nút "Details" trong chat, offer tương ứng được làm nổi bật và cuộn tới.
- **Chưa có offer:** app báo yêu cầu đã được chia sẻ, offer thường đến trong 2 giờ. Có nút **Check for offers** để kiểm tra lại.

### 6.3 Thông báo trong app
- Badge số offer mới trên tab Requests và pill "N new offers" ở Home. Số này được cập nhật khi đăng nhập và mỗi lần thanh dưới hiện ra.
- Badge số tin chưa đọc trên tab Messages, cập nhật khi đăng nhập, khi mở Messages và khi đọc tin.

---

## 7. Tin nhắn (Messages và Chat)

### 7.1 Danh sách hội thoại
- Mỗi hội thoại hiện tin nhắn cuối. Tin của người dùng có tiền tố "You:". Tin không phải chữ hiện dạng nhãn: Voice message, Photo, File, Offer: …
- Tin đã dịch tự động có nhãn "Auto-translated from …".
- **Tìm nhà cung cấp** theo tên, và mục **Other providers** để bắt đầu trò chuyện mới.
- Có nút micro để nói yêu cầu ngay từ đây.

### 7.2 Chat 1:1 với nhà cung cấp
- **Nhắn bằng chữ hoặc giọng nói:** bấm micro để ghi âm và bấm gửi khi xong. App báo nếu đoạn ghi quá ngắn hoặc chưa cấp quyền micro.
- **Dịch tự động:**
  - Nút **Translate on/off** trên đầu màn. Lần đầu bật, app hỏi đồng ý cho dịch vụ AI xử lý tin nhắn.
  - Mỗi tin có thể chuyển giữa bản dịch và bản gốc ("show original" / "show translation").
  - Chân màn chat cho biết nhà cung cấp nói ngôn ngữ gì và sẽ nghe tin nhắn bằng ngôn ngữ nào.
- **Đọc to câu trả lời:** nếu bật "Read replies aloud" trong Account, tin nhắn chữ và voice mới của nhà cung cấp được phát tự động.
- **Offer trong chat:**
  - Thẻ offer có trạng thái New offer, Accepted, Accepted & Paid, Declined, kèm mã đơn hàng.
  - Hình thức hiển thị: online, tại nhà, tại phòng khám.
  - Có thể mở **Details** để xem offer hoặc **Accept & Pay** để thanh toán ngay trong chat.
- **Trạng thái tin nhắn:** Sending…, Read. Khi gửi lỗi có nút Try again.
- Tin nhắn được phân nhóm theo ngày: Today, Yesterday, hoặc ngày cụ thể.
- **Báo cáo và chặn** (menu ⋮):
  - **Report user:** chọn lý do (Spam, Lừa đảo, Bạo lực/đe dọa, Ngôn từ thù ghét, Nội dung khiêu dâm, Tự hại, Liên quan trẻ vị thành niên, Khác) và có thể ghi thêm chi tiết.
  - **Block user:** sau khi chặn, hai bên không nhắn được cho nhau và người bị chặn không được báo. Ô nhập được thay bằng thông báo kèm nút **Unblock**.

---

## 8. Thanh toán (Accept & Pay)

Màn thanh toán mở từ Offers hoặc từ chat dưới dạng bảng trượt lên:

- Hỏi xác nhận "Accept {tên}'s offer?" và hiện thông tin buổi dịch vụ, giá, voucher (nếu có), số Lion Points dùng để giảm giá và tổng tiền.
- **Lion Points:** công tắc để dùng điểm trừ vào tiền, hiện số điểm và số tiền được giảm.
- **Phương thức thanh toán:** chọn thẻ đã lưu (có ngày hết hạn) hoặc **Add card** để thêm thẻ mới. Thanh toán qua Stripe.
- **Smart Escrow:** tiền được giữ an toàn và chỉ chuyển cho nhà cung cấp sau khi buổi dịch vụ hoàn tất.
- Nếu điểm và voucher đã đủ trả, đơn được đánh dấu là không cần thanh toán thêm.
- **Kết quả:**
  - **Booked with {tên}:** đã chấp nhận và thanh toán. Có nút nhắn tin với nhà cung cấp.
  - **Payment processing:** thanh toán đang được xác nhận, booking sẽ hiện trong My requests khi xong.
  - **Thanh toán thất bại:** gợi ý thử lại hoặc dùng thẻ khác.
- Cần đăng nhập trước khi thanh toán.

---

## 9. Social Market (chợ dịch vụ theo chủ đề)

Social Market có 3 chợ theo chủ đề, mở từ menu ☰ ở Home:

| Chợ | Tên hiển thị |
|---|---|
| Longevity | Longevity Marketplace |
| Health Pro Advisory | Health Pro Marketplace |
| Personal Helper | Personal Helper Marketplace |

### 9.1 Trang của một chợ
- **Hero toàn màn hình:** slogan "Your Health. Your Budget. Your Companion." và ô nhập yêu cầu (gõ hoặc nói), gửi sang trợ lý AI. Riêng Longevity có tiêu đề "Lower your age".
- Cuộn xuống là các khu vực sau. Mỗi khu có tiêu đề, mô tả và nút xem thêm:
  1. **Selling:** dịch vụ đang bán. Mỗi thẻ có ảnh, tên, hình thức, nhà cung cấp kèm cờ quốc gia, giá (giá gốc gạch ngang nếu đang giảm), ngôn ngữ và phạm vi phục vụ. Có nút **Send Inquiry**. Nút **View selling list** mở danh sách đầy đủ.
  2. **Profiles:** hồ sơ chuyên gia, coach, studio, phòng khám. Mỗi thẻ có cờ và quốc gia, số năm kinh nghiệm, nghề, điểm đánh giá, phần giới thiệu, ngôn ngữ (tên đầy đủ, ví dụ "English") và số lượt đặt. Nút **View profile list** mở danh sách đầy đủ.
  3. **Provider's Offers:** những gì nhà cung cấp có thể làm ngay, viết bằng lời của họ. Mỗi thẻ có giá theo từng hình thức, đơn vị giá (buổi, ngày, tuần, tháng, gói), khu vực phục vụ, kết quả mong đợi, kinh nghiệm và nút **I want this offer**.
  4. **Social Market Requests:** yêu cầu công khai của người khác, gồm ngân sách, hạn chót, lịch mong muốn, ngôn ngữ nhà cung cấp, tệp đính kèm, voice, số cuộc trò chuyện và số offer đã gửi, trạng thái Solved. Nút **I have similar request** để đăng yêu cầu tương tự với nội dung chép sẵn.
  5. **Health Solution Library:** thư viện chủ đề giải pháp gồm phù hợp với ai, cách hoạt động, kết quả mong đợi và lưu ý quan trọng. Nút **I want a solution of this type** gửi nhu cầu tới các nhà cung cấp liên quan. Có ghi chú rằng đây là chủ đề tham khảo để tìm người, không phải lời khuyên y tế.
  6. **Share your request:** khối cuối trang để đăng yêu cầu trực tiếp.
- **Tương tác trên thẻ:**
  - Like (tim) và Save (bookmark).
  - Dòng thống kê "N interested · N saved · N contacted".
  - Thẻ có thể mở rộng hoặc thu gọn tại chỗ để xem chi tiết.
  - Ảnh được xem toàn màn hình khi chạm vào.

### 9.2 Danh sách đầy đủ
"{Chủ đề} services" và "{Chủ đề} providers". Mới nhất hiện trước, tự tải thêm khi cuộn, và có trạng thái trống hoặc lỗi kèm nút thử lại.

### 9.3 Gửi yêu cầu cho một dịch vụ hoặc offer (Send Inquiry)
- Bảng gửi yêu cầu tới một nhà cung cấp, ghi rõ người nhận ("To:").
- Gồm mô tả nhu cầu và phần **More detail** tùy chọn:
  - Ngân sách mong muốn (một số hoặc khoảng).
  - Thời hạn (ngày và giờ).
  - Lịch ưa thích: chọn các ngày trong tuần với cùng một khung giờ.
  - Hình thức hỗ trợ: Remote, At home, At clinic, At office.
  - Tệp đính kèm.
- Yêu cầu được gửi vào chat với nhà cung cấp. App chặn việc gửi yêu cầu cho chính tin đăng của mình.

---

## 10. Medical Travel (du lịch y tế)

### 10.1 Trang Medical Travel
- **Hero:** "Where would you like to go for medical travel?" kèm câu ví dụ (bác sĩ tim mạch ở Singapore, khám tổng quát ở Thái Lan, phẫu thuật thẩm mỹ ở Hàn Quốc). Có nút **Talk to a coordinator free** và **Browse destinations**.
- **Local coordinators:** chuyên gia địa phương am hiểu bệnh viện, chi phí và visa. Mỗi người có thời gian phản hồi ước tính và cho biết họ đại diện cho cơ sở nào hay là tư vấn độc lập. Có nút **Message coordinator** và **Free intro call**.
- **Điểm đến:** các quốc gia phổ biến kèm cờ và thế mạnh. Ví dụ: Hàn Quốc (mắt, da liễu, thẩm mỹ), Singapore (ung bướu, longevity, tim mạch), Thái Lan (tầm soát, hỗ trợ sinh sản, thẩm mỹ), Việt Nam (nha khoa, tầm soát, phục hồi).
- **Cam kết tin cậy:**
  - Cơ sở đã được kiểm tra chứng nhận (JCI, ISO 9001, giấy phép Bộ Y tế).
  - Có coordinator và phiên dịch y tế.
  - Chỉ trả tiền khi phác đồ đã được xác nhận.
  - Hỗ trợ thư mời visa y tế.
- **Recommended services:** các gói dịch vụ ghi rõ thời lượng, lưu trú, đưa đón và những gì bao gồm (giá tính bằng USD). Có thể sắp xếp theo Recommended, Top-rated, giá tăng hoặc giảm, và lọc theo khoảng giá.
- **How a medical trip works:** 5 bước: trao đổi với coordinator, nhận danh sách đề xuất kèm báo giá cố định và thư visa, bay sang, điều trị (có phiên dịch đi cùng), về nhà phục hồi (theo dõi tiếp online).
- **Gói bao gồm và không bao gồm:**
  - Bao gồm: lưu trú, xét nghiệm, chẩn đoán hình ảnh và phí khám chuyên khoa, đưa đón sân bay, phiên dịch, thư mời visa.
  - Không bao gồm: vé máy bay, phí xin visa, thuốc mang về, điều trị biến chứng ngoài dự kiến.
- **Bảo vệ thanh toán:** không phải trả trước khi phác đồ được xác nhận, tiền được StrongBody giữ đến khi người dùng đến nơi, được hủy miễn phí trong thời hạn của từng gói.
- **FAQ:** các câu hỏi thường gặp, ví dụ "nếu không nói được tiếng địa phương thì sao?".

### 10.2 Trang một điểm đến
- Hero của quốc gia gồm cờ, ảnh, mô tả, cơ sở đã kiểm tra và coordinator địa phương.
- Hai tab: **Services** và **Providers**, mỗi tab có ô tìm kiếm và bộ lọc riêng:
  - Danh mục.
  - Khoảng giá (USD), có mốc giá nhanh và kiểm tra hợp lệ.
  - Chứng nhận cơ sở.
  - Có cuộc gọi giới thiệu miễn phí.
  - Chỉ hiện nhà cung cấp đã xác minh danh tính.
  - Ngôn ngữ nhà cung cấp nói.
  - Sắp xếp: Recommended, Top-rated, giá tăng hoặc giảm.
- Chip hiện các bộ lọc đang dùng, có thể bỏ từng bộ lọc. Có nút Clear all, Reset và Show more.
- Mục **Explore other destinations** gợi ý các quốc gia khác.

### 10.3 Chi tiết gói dịch vụ
- Tên gói và cơ sở, kèm cờ quốc gia, bộ ảnh (nút "+N more"), các badge chứng nhận, và nhãn "Visa letter on request" nếu cơ sở cấp thư mời visa khi được yêu cầu.
- **Thông tin nhanh:** thời lượng, ngôn ngữ, chi phí ước tính, những gì bao gồm và không bao gồm.
- **Tổng quan và lộ trình:** "What to expect".
- **Before you book:** các giấy tờ nên chuẩn bị, gồm trang hộ chiếu, tiền sử bệnh 6 tháng gần nhất và danh sách thuốc đang dùng.
- **About the provider:** thông tin nhà cung cấp, số khách đã phục vụ, thời gian hoạt động trên StrongBody, tổ chức và trạng thái xác minh.
- **FAQ.**
- Ghi chú: giá cuối cùng tùy theo đánh giá của bác sĩ, người dùng duyệt báo giá cố định trước, và không phải trả tiền đến khi kế hoạch được xác nhận.
- **Thanh dưới:** **Chat with the facility** và **Request appointment**.

### 10.4 Đặt lịch hẹn (Request an appointment)
Form gồm 2 bước:
1. **Preferred timing:** As soon as available, chọn ngày cụ thể trên lịch, Within the next 3 months, hoặc I'm not sure yet.
2. **Contact details:**
   - Họ tên, email và số điện thoại (có chọn mã quốc gia).
   - Kênh liên hệ ưa thích: email, gọi điện hoặc WhatsApp.
   - Ngôn ngữ và lời nhắn.
   - Đồng ý chia sẻ thông tin với cơ sở.

Sau khi gửi, màn xác nhận cho biết cơ sở sẽ liên hệ qua kênh đã chọn để chốt lịch.

### 10.5 Cuộc gọi giới thiệu miễn phí (Free intro call)
- Gửi cho coordinator mô tả ngắn về trường hợp của mình và email (bắt buộc), kèm thông tin liên hệ khác (điện thoại, WhatsApp, Zalo, Telegram…).
- Có hiển thị giờ làm việc của coordinator.
- Coordinator sẽ phản hồi qua email để hẹn lịch cuộc gọi.

---

## 11. Tài khoản (Account)

### 11.1 Hồ sơ
- Ảnh đại diện, tên và thành phố.
- **Edit profile:** sửa họ, tên, thành phố.

### 11.2 Lion Points
- Hiển thị số điểm hiện có và giá trị quy đổi ra tiền khi thanh toán.
- **Lion Points history:** lịch sử cộng và trừ điểm, gồm thưởng giới thiệu, thưởng mua hàng, điểm dùng khi thanh toán và điểm hết hạn.

### 11.3 Voice & language
- **Speaking language:** ngôn ngữ mặc định khi nói yêu cầu.
- **Attach my voice to requests:** gửi kèm giọng nói gốc để nhà cung cấp nghe đúng lời người dùng.
- **Auto-translate messages:** đọc và nghe nhà cung cấp bằng ngôn ngữ của mình. Lần đầu bật, app hỏi đồng ý dùng dịch vụ dịch AI.
- **Read replies aloud:** tự phát các câu trả lời mới, không cần chạm tay.

### 11.4 Orders & saved
- **My orders:** chuyển đến My requests.
- **Saved providers:** mở danh sách nhà cung cấp.
- **My reviews:** sắp ra mắt.
- **Payment methods:** sắp ra mắt. Hiện thẻ được quản lý ngay trong màn thanh toán.

### 11.5 Support
- **Notifications:** sắp ra mắt.
- **Help & support:** sắp ra mắt.
- **Blocked users:** danh sách người đã chặn, có nút bỏ chặn.

### 11.6 Đăng xuất và xóa tài khoản
- **Log out:** có hỏi xác nhận. Sau khi đăng xuất, máy không nhận thông báo offer và tin nhắn nữa. App cũng xóa tìm kiếm gần đây và hội thoại với trợ lý AI trên máy.
- **Delete account:**
  - Cảnh báo việc xóa là vĩnh viễn, mất toàn bộ yêu cầu, tin nhắn và Lion Points.
  - Người dùng nhập mật khẩu và có thể ghi lý do rời đi.
  - App gửi mã xác minh qua email (có nút gửi lại mã). Tài khoản chỉ bị xóa sau khi máy chủ xác nhận mã.

### 11.7 Khi chưa đăng nhập
Tab Account hiện lời mời "Sign in to StrongBody" kèm lợi ích: theo dõi yêu cầu, chat với nhà cung cấp, tích Lion Points.

---

## 12. Đăng nhập và đăng ký

Đăng nhập và đăng ký mở dưới dạng bảng trượt lên ngay tại màn đang dùng, không chuyển trang. Bảng này tự xuất hiện khi người dùng làm thao tác cần tài khoản, như đăng yêu cầu, nhắn tin hoặc thanh toán.

- **Đăng ký bằng email:**
  - Mật khẩu 8–64 ký tự, có ít nhất 1 chữ và 1 số, nhập lại để xác nhận.
  - Xác minh bằng mã 4 số gửi qua email, có nút gửi lại kèm đếm ngược.
  - Nếu email đã có tài khoản, app gợi ý đăng nhập.
- **Đăng nhập bằng email và mật khẩu.**
- **Continue with Google** và **Continue with Apple.**
- **Quên mật khẩu:** nhập email, nhận mã 4 số, rồi đặt mật khẩu mới.
- Trong luồng đăng yêu cầu, bảng mở sẵn ở chế độ đăng ký với lời nhắn "Sign up and your request will be posted automatically".

---

## 13. Quyền riêng tư và an toàn

- **Micro:** chỉ dùng khi màn nói hoặc ghi âm đang mở.
- **Vị trí:** chỉ dùng khi người dùng đồng ý, và chỉ cho lần tìm kiếm đó.
- **Dịch tin nhắn bằng AI:** cần người dùng đồng ý trước khi bật.
- **Báo cáo và chặn người dùng** trong chat, đáp ứng yêu cầu của App Store về nội dung do người dùng tạo.
- **Xóa tài khoản ngay trong app,** đáp ứng yêu cầu của App Store.
- **Nhà cung cấp được xác minh danh tính.** Giấy phép hành nghề được xác minh với những công việc cần giấy phép.

---

## 14. Một số quy ước hiển thị

- **Ngôn ngữ của nhà cung cấp hoặc dịch vụ** luôn ghi tên đầy đủ, ví dụ "English", "Vietnamese", không dùng mã viết tắt như "EN".
- **Quốc gia của nhà cung cấp hoặc dịch vụ** luôn kèm cờ khi có dữ liệu cờ hoặc mã quốc gia.
- **Nút hành động chính** dùng màu xanh đại dương #0B6B8A. Nút xóa và các thao tác nguy hiểm dùng màu đỏ.
- **Popup và bảng trượt** có nền trắng, chữ đen.
- **Tiền tệ:** hiển thị theo đúng đơn vị của từng nhà cung cấp, ví dụ $70, £70, €12.50.
- **Thời gian:** hiển thị dạng tương đối, ví dụ "5 minutes ago", "yesterday", "last week".

---

## 15. Tính năng chưa có trên app (đang phát triển)

- Trang chi tiết cho dịch vụ thường (không phải Medical Travel). Hiện chạm vào thẻ dịch vụ thường chỉ hiện thông báo sắp ra mắt.
- My reviews, Payment methods, Notifications, Help & support trong Account.
- Danh sách "nhà cung cấp đã lưu" riêng. Hiện mục này mở danh sách nhà cung cấp chung.
