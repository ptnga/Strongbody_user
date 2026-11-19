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
| 1 | **Discover** | Trang chủ: các yêu cầu tiêu biểu của cộng đồng |
| 2 | **Requests** | Các yêu cầu đã đăng; badge hiện số offer mới |
| Giữa | **Get help** (nút micro nổi) | Mở sheet ghi âm để đăng yêu cầu |
| 3 | **Messages** | Danh sách hội thoại; badge đỏ hiện số tin chưa đọc |
| 4 | **Account** | Tài khoản, Lion Points, cài đặt |

- Thanh dưới hiện ở mọi tab, kể cả trang chủ (giống fly-bar của web).
- Mỗi tab giữ nguyên trạng thái khi chuyển qua lại, kể cả vị trí cuộn và dữ liệu đã tải.
- Bấm Back ở một tab khác Home sẽ quay về Home.
- Badge số tin chưa đọc màu đỏ, quá 99 thì hiện "99+". Khi đã đăng nhập và app đang mở, số này tự cập nhật mỗi 10 giây, nên có tin mới là badge hiện ngay dù chưa mở Messages.

### 2.2 Menu ☰ ở Home
- **Request someone's help** (nút lớn trên cùng): mở sheet ghi âm "Get help".
- **Offers:** mở trang riêng "Services & plans from experts" (xem mục 3.3).
- **Browse by need:** mở rộng ra 4 trang Social Market: Longevity, Mental Health, Personal Helper, Medical Travel.
- **My requests:** kèm badge số offer mới (chỉ khi đã đăng nhập).
- **Messages:** kèm badge đỏ số tin chưa đọc, quá 99 thì hiện "99+" (chỉ khi đã đăng nhập).
- **User sign up:** thay cho My requests và Messages khi chưa đăng nhập, mở bảng đăng ký.
- **Browse providers:** duyệt danh sách nhà cung cấp.
- **Recent:** các yêu cầu gần đây, chạm vào để xem offer của yêu cầu đó.
- **Hồ sơ người dùng** ở cuối menu: tên và số Lion Points. Khi chưa đăng nhập thì hiện "Sign in".

### 2.3 Màn khởi động (Splash)
Nền trắng, logo StrongBody ở giữa, hiện trong thời gian ngắn rồi tự chuyển vào Home.

---

## 3. Trang chủ (Discover)

Giống trang chủ web trên điện thoại: một trang cuộn dọc gồm ảnh đội ngũ chuyên gia, số liệu tuần này, rồi danh sách **"Typical requests"**. Không còn tab Requests · Offers: danh sách offer đã chuyển sang trang riêng mở từ menu ☰ (mục 3.3). Trang chủ không có ô tìm kiếm, bộ lọc hay chủ đề. Kéo xuống để làm mới; cuộn gần cuối thì tự tải thêm (10 yêu cầu mỗi lần).

### 3.1 Phần đầu trang
- **Ảnh đội ngũ chuyên gia** tràn hết bề ngang, có nhãn "StrongBody.ai" ở góc ảnh.
- **Tiêu đề** "Real experts, complete solutions." (cụm "Real experts" tô xanh), bên dưới là dòng nghề: "Nutritionists · Health coaches · Doctors · Longevity coaches · and more".
- **Thẻ số liệu tuần này:** số yêu cầu đăng trong tuần ("{n} requests this week", kèm biểu tượng tăng trưởng) và, nếu có, số yêu cầu đã được kết nối với chuyên gia ("{n} matched with an expert"). Không lấy được số liệu hoặc tuần này chưa có yêu cầu nào thì ẩn hàng số.
- **Ba cam kết** có dấu tích xanh: "Real people, real budgets", "Verified experts", "Pay only when you accept an offer".
- Tiêu đề **"Typical requests"** ngay trên danh sách. Muốn đăng yêu cầu thì dùng nút **Get help** ở thanh dưới (trang chủ không còn nút đăng ở đầu danh sách).

### 3.2 Danh sách "Typical requests"
- Chỉ hiện các yêu cầu công khai thuộc nguồn tiêu biểu mà StrongBody chọn cho trang chủ (cùng nguồn với trang chủ web), gồm cả yêu cầu đang mở lẫn đã đóng.
- **Thẻ yêu cầu gọn:**
  - **Người đăng:** tên công khai rút gọn kiểu "Teri M." (họ chỉ giữ chữ cái đầu), kèm ảnh đại diện, cờ và nước. Người đăng ẩn danh hiện "Anonymous" với dòng phụ "name hidden for privacy". Thẻ không hiện thời gian đăng.
  - **Save** (bookmark) ở góc trên bên phải. Khách được mời đăng nhập trước khi lưu. Yêu cầu của chính mình không có nút lưu. Thẻ gọn không có nút Like.
  - **Nội dung** 3 dòng, kèm "See more" khi dài. Chạm "See more" hoặc chạm vào nội dung để mở rộng ngay tại chỗ; "Show less" để thu lại.
  - **Chip:** ngân sách, loại dịch vụ (hoặc chủ đề) của yêu cầu, hình thức nhận dịch vụ, và "Closed" (có biểu tượng khóa) khi yêu cầu đã đóng.
  - **Hành động:** **Me too** mở form "Post a request" điền sẵn nội dung và hình thức của yêu cầu đó, để đăng yêu cầu tương tự (nút được đánh dấu nếu mình đã bấm Me too). Yêu cầu của chính mình thay bằng **Manage my request** (về My requests). Yêu cầu đã được giải quyết mà chưa đóng thì hiện thêm "✓ Solved" cạnh Me too.
  - **Khi mở rộng** còn hiện: tối đa 2 ngôn ngữ người đăng muốn được hỗ trợ (cùng hàng chip), ảnh (chạm để xem lớn) và tệp đính kèm, cùng dải hoạt động gồm avatar chuyên gia đã đề xuất và "{n} experts offered", "{n} need this too", "{n} likes". Chưa có hoạt động nào thì không hiện dải này.
- **"Recently matched":** khối chen ngay sau thẻ thứ 3 (ít hơn 3 thẻ thì ở cuối danh sách). Hiện tối đa 3 yêu cầu gần đây đã có chuyên gia phản hồi, mỗi dòng gồm tên dịch vụ, cờ và nước, nhãn "Matched ✓". Không có dữ liệu thì không hiện.
- **Trạng thái:** đang tải hiện vòng xoay; lỗi hiện khối thử lại; tải thêm lỗi có nút thử lại riêng. Chưa có yêu cầu nào: "No requests yet" kèm gợi ý và nút **+ Post a request** (mở sheet "Get help").

### 3.3 Trang Offers ("Services & plans from experts")
Mở từ mục **Offers** trong menu ☰. Trang có tiêu đề "Services & plans from experts", ô tìm kiếm, nút **Filters**, cuộn để tải thêm (10 mục mỗi lần) và kéo xuống để làm mới.
- **Mỗi dòng offer:** ảnh, tên dịch vụ, nhà cung cấp (cờ, "Verified"), mô tả, và loại dịch vụ đầu tiên của dịch vụ đó dạng badge (nếu có). Giá: một mức giá, hoặc khoảng giá với dịch vụ tư vấn (không còn ghi chữ "Consultation" trước giá), hoặc "✈ Medical Travel". Kèm hình thức cung cấp.
- **Book** mở trang dịch vụ; với dịch vụ tư vấn, nút này là **Send inquiry**. **Free consult** (dịch vụ có tư vấn miễn phí) mở form gửi yêu cầu với lời nhắn soạn sẵn. Chạm cả thẻ cũng mở dịch vụ.
- **Bộ lọc:** Sort by, Posted, Delivery, Price, Provider (đã xác minh / có lựa chọn miễn phí), Language, Country.
- **Tìm kiếm:** chạy sau khi ngừng gõ 400ms (hoặc bấm Enter). Có từ khóa hoặc bộ lọc thì hiện số kết quả và chip từng bộ lọc (bỏ được từng cái), kèm "Clear filters". Không có kết quả: gợi ý **Clear filters** và **+ Post a request**.

---

## 4. Trợ lý AI (StrongBody assistant)

Hiện trên app chưa có lối vào trực tiếp tới màn trợ lý: các trang Social Market không còn ô nhập ở đầu trang. Phần dưới mô tả chức năng của màn trợ lý khi được mở.

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
Mở từ nút giữa thanh dưới, nút "Request someone's help" trong menu ☰, nút "+ Post a request" khi trang chủ chưa có yêu cầu nào, My requests, Messages và danh sách nhà cung cấp.

- Mở ra là bật micro ngay, với dòng "Listening… speak in your own language", sóng âm theo giọng nói thật và bộ đếm thời gian. Không hiện chữ trong lúc nói.
- **Câu mẫu:** dưới sóng âm có dòng "For example, you could say:" và 3 câu ví dụ hiện lần lượt, mỗi câu khoảng 3,5 giây rồi mờ dần sang câu kế (giảm 5 kg với health coach, nói chuyện online với chuyên gia giấc ngủ, sắp xếp khám răng ở Thái Lan). Câu mẫu chỉ chạy khi đang ghi âm.
- **Ba nút:** hủy (bên trái), **tạm dừng / tiếp tục** (nút tròn lớn ở giữa) và **gửi** (bên phải). Khi tạm dừng, đồng hồ đứng, sóng âm phẳng và dòng chữ đổi thành "Paused — tap continue when you're ready"; vẫn gửi được trong lúc tạm dừng.
- Tối đa 2 phút (120 giây), hết giờ tự gửi.
- Không bật được micro hoặc không ghi được tiếng: hiện ô gõ chữ để nhập yêu cầu.
- Nếu bật "Attach my voice to requests" trong Account, bản ghi được gửi kèm yêu cầu làm voice note.

### 5.2 Màn "Post a request"
- Form hiện ngay nhưng bị khóa, kèm thẻ tiến trình: "Converting your voice to text…" rồi "AI is analysing your request…" và phần trăm.
- AI xong thì form mở khóa với nội dung đã điền; tiêu đề đổi thành "Review and post your request".
- **Các trường:**
  - Mô tả (50–1000 ký tự, bộ đếm "n/1000") với nút đính kèm ảnh/tệp ngay trong ô (mỗi tệp tối đa 20MB).
  - **Your preferred budget:** một số hoặc khoảng, kèm ô chọn tiền tệ lấy từ danh sách tiền tệ của hệ thống.
  - **Working language:** mặc định là ngôn ngữ của app, chọn thêm hoặc bỏ được.
- **Tạm ẩn (giống web):** câu hỏi "Where would you like to receive the service?" và ô "Post anonymously" không còn hiện trên form. Hình thức nhận dịch vụ mà AI đã điền (hoặc chép từ Me too) vẫn được gửi kèm; yêu cầu mới không còn đăng ẩn danh được.
- Nút gửi dính ở đáy màn ghi **Send to 20 matched experts**: khi đăng công khai, hệ thống tự gửi thẳng yêu cầu tới tối đa 20 chuyên gia có dịch vụ phù hợp.
- **Lỗi:** không chuyển được giọng nói, bản ghi trống hoặc AI không soạn được thì báo lỗi và giữ phần đã có để người dùng tự hoàn thiện.
- **Chưa đăng nhập:** bấm gửi sẽ mở màn đăng ký. Đăng ký xong, yêu cầu được đăng tự động.
- Mở từ "Request offer" của một nhà cung cấp: form gửi riêng cho người đó (không có Working language), nút gửi ghi **Send request**.

### 5.3 "Providers for your request"
- Xác nhận "Your request is posted" (đã hiển thị, hoặc đang được duyệt), nội dung yêu cầu, và Budget · Where · Languages (mục nào không có thì ẩn).
- Link **View my requests**.
- Giống web, trang này tạm không còn khối gợi ý chuyên gia phù hợp ngay sau khi đăng. Danh sách chuyên gia đã nhận yêu cầu được xem trong My requests (mục 6.1, "Sent to N matched experts").

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
- Hai tab: **Public requests** (yêu cầu đăng công khai) và **Private requests** (yêu cầu gửi riêng cho một nhà cung cấp).
- Mỗi yêu cầu hiển thị:
  - Thời gian đăng (hôm nay, hôm qua, ngày cụ thể), nội dung và voice note.
  - Hình thức nhận dịch vụ, thời gian mong muốn (Today, Tomorrow, This weekend) và ngân sách.
  - Số offer, số nhà cung cấp đã phản hồi, khoảng giá và nhà cung cấp được đánh giá cao nhất.
  - Badge "new offers" khi có offer mới.
- **Trạng thái:** In review, Open, Not approved, **Solved** (yêu cầu đã đóng), Expired; khi đã đặt thì Booked (kèm tên người đã đặt) hoặc Completed.
- **Nhận xét của AI** (khi yêu cầu chưa được duyệt):
  - Yêu cầu đang chờ duyệt hoặc bị từ chối vì AI chấm dưới mức duyệt: khung vàng nêu lý do kèm gợi ý của AI (một bản, theo ngôn ngữ của app). Bị từ chối thì tiêu đề là "Please review and update your request", còn lại là "Your request isn't clear yet — AI suggestion".
  - Người đăng vừa sửa yêu cầu và AI đang chấm lại: trạng thái hiện "In review" (không còn "Not approved"), kèm khung xám "Your updated request is under review": yêu cầu sẽ tự đăng khi đạt yêu cầu.
  - App chưa có nút sửa yêu cầu như web.
- **Chuyên gia đã nhận yêu cầu:** yêu cầu được hệ thống gửi thẳng tới chuyên gia phù hợp thì hiện "Sent to N matched experts" và nút **Show experts** / **Hide**.
  - Bấm Show experts để mở danh sách ngay trên thẻ, với tiêu đề "Experts who received your request" và lời giải thích rằng chuyên gia có thể trả lời trong chat.
  - Mỗi chuyên gia hiện thẻ hồ sơ như ở Social Market (hồ sơ không còn công khai thì chỉ hiện tên, ảnh, cờ và nước), badge **Replied** nếu họ đã nhắn lại, và nút **Chat**.
  - Tải 20 chuyên gia mỗi lần, có nút **Show more** để tải thêm. Lỗi thì có nút thử lại.
- Nút **Compare** để xem và so sánh offer, nút **Speak a request** để đăng yêu cầu mới.
- Có màn trống riêng cho từng trường hợp: chưa đăng nhập, lỗi tải, chưa có yêu cầu nào.
- **Tab Private requests trống:** thông báo "No private requests yet", nút **Find a provider** (mở danh sách nhà cung cấp) và 3 bước "How private requests work": tìm nhà cung cấp, gửi yêu cầu riêng bằng "Send request" trên hồ sơ, dịch vụ, sản phẩm hoặc offer của họ, rồi trò chuyện trong Messages.

### 6.2 Offers của một yêu cầu
- Danh sách mọi offer nhà cung cấp đã gửi. Mỗi offer có giá mỗi buổi, hình thức (online, tại nhà, tại phòng khám), thời gian và dấu "Verified provider".
- **Sắp xếp:** Best match, Lowest price, Soonest.
- **Hành động:** **Accept & Pay** (mở thanh toán) hoặc **Reply** (nhắn tin với nhà cung cấp).
- Khi mở từ nút "Details" trong chat, offer tương ứng được làm nổi bật và cuộn tới.
- **Chưa có offer:** app báo yêu cầu đã được chia sẻ, offer thường đến trong 2 giờ. Có nút **Check for offers** để kiểm tra lại.

### 6.3 Thông báo trong app
- Badge số offer mới trên tab Requests và mục My requests trong menu ☰. Số này được cập nhật khi đăng nhập và mỗi lần thanh dưới hiện ra.
- Badge đỏ số tin chưa đọc trên tab Messages và mục Messages trong menu ☰ (quá 99 hiện "99+"). Số này cập nhật khi đăng nhập, khi mở Messages, khi đọc tin và tự cập nhật mỗi 10 giây khi app đang mở.

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
- **Thẻ yêu cầu và dịch vụ trong chat:**
  - Thẻ yêu cầu chỉ có nút **Go to my requests** khi người xem là chủ của yêu cầu đó.
  - Thẻ dịch vụ không có ảnh (hoặc ảnh lỗi) hiện ảnh dự phòng chung của StrongBody.
- **Trạng thái tin nhắn:** Sending…, Read. Khi gửi lỗi có nút Try again.
- **Thời gian kiểu Messenger:** không ghi giờ dưới từng tin nữa.
  - Đầu mỗi cụm tin có một mốc giờ căn giữa. Một cụm mới bắt đầu ở tin đầu tiên hoặc khi cách tin trước đó từ 1 giờ trở lên.
  - Mốc giờ ghi theo độ xa: hôm nay chỉ ghi giờ ("10:42"), trong 7 ngày ghi thứ và giờ ("Mon 10:42"), xa hơn ghi ngày tháng và giờ ("17 Nov, 10:42"), khác năm thì thêm năm.
  - Chạm vào một bong bóng để hiện hoặc ẩn thời gian đầy đủ của tin đó, ví dụ "Monday, 17 November 2026 10:42".
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

## 9. Social Market ("Browse by need")

Social Market mở từ mục **Browse by need** trong menu ☰ ở Home, gồm 4 nhu cầu:

| Nhu cầu | Tên trên đầu trang | Câu mở đầu |
|---|---|---|
| Longevity | Longevity Marketplace | "Invest in the years ahead" |
| Mental Health | Mental Wellbeing Marketplace | "Your mind deserves care too" |
| Personal Helper | Personal Helper Marketplace | "A helping hand makes all the difference" |
| Medical Travel | Medical Travel Marketplace | "The right care, wherever it takes you" |

Mental Health thay cho Health Pro Advisory trước đây. Mỗi nhu cầu không còn là một danh mục riêng: nó gom sẵn một nhóm loại hình doanh nghiệp (bệnh viện, phòng khám, trung tâm wellness…) và một nhóm nghề chuyên gia phù hợp, theo bảng phân loại cố định của StrongBody.

### 9.1 Trang của một nhu cầu
Bốn trang dùng chung một bố cục. Mục nào không có dữ liệu thì ẩn. Kéo xuống để làm mới.
- **Hero ngắn căn giữa:** câu mở đầu riêng của từng nhu cầu (bảng trên) và một dòng mô tả. Trang không còn ô nhập yêu cầu.
- **Riêng Medical Travel:** mục chọn điểm đến ngay dưới hero (xem mục 10.1).
- **Mỗi loại hình doanh nghiệp một mục dịch vụ:** tiêu đề là tên loại hình (bằng tiếng Việt khi app dùng tiếng Việt), hiện 2 dịch vụ, kèm nút **View all** mở danh sách đầy đủ đã chọn sẵn loại hình đó. Loại hình chưa có dịch vụ thì không hiện.
- **Chuyên gia ("Guided by people who care"):** doanh nghiệp thuộc các loại hình của nhu cầu hoặc chuyên gia có nghề phù hợp, xếp theo điểm xếp hạng của hệ thống, tối đa 9 người. Nút **View all experts** mở danh sách đầy đủ.
- Đang tải hiện khung chờ. Mục dịch vụ và mục chuyên gia lỗi thì hiện khối thử lại.

### 9.2 Thẻ dịch vụ
- Ảnh bìa với nút **Save** ở góc. Dịch vụ không có ảnh (hoặc ảnh lỗi) hiện ảnh dự phòng chung của StrongBody.
- Tên 2 dòng, mô tả 2 dòng.
- **Loại dịch vụ:** tối đa 2 badge màu xanh đại dương, phần còn lại gom thành "+N" (chạm để xem đủ).
- **Người cung cấp:** ảnh đại diện (viền và dấu tích khi đã xác minh), tên, cờ và nước, ngôn ngữ. Dịch vụ thuộc một tổ chức thì hiện tên, logo, nước và ngôn ngữ của tổ chức đó thay cho người đăng; tin nhắn và yêu cầu vẫn gửi tới người phụ trách dịch vụ.
- **Giá:** một mức giá, hoặc khoảng giá với dịch vụ tư vấn (không còn ghi chữ "Consultation"). Dịch vụ Medical Travel hiện nhãn Medical Travel thay cho giá.
- Số lượt lưu "N saved" chỉ hiện khi có người lưu (không còn ghi "0 saved").
- Chạm cả thẻ: dịch vụ Medical Travel mở trang chi tiết (mục 10.3); dịch vụ khác mở thẳng bảng gửi yêu cầu (mục 9.5).

### 9.3 Thẻ chuyên gia
- Căn giữa: ảnh đại diện (đã xác minh có viền và huy hiệu số mục đã xác minh), tên, cờ và nước, ngôn ngữ, điểm đánh giá, phần giới thiệu 2 dòng. Chỉ có nút Save, không có Like.
- **Dòng phụ dưới tên** tùy loại nhà cung cấp, kèm số năm kinh nghiệm nếu có: doanh nghiệp hiện tên loại hình doanh nghiệp; chuyên gia cá nhân hiện nghề. Không có nghề thì hiện nhãn Medical Travel, "Representative of {tổ chức}" hoặc "Independent — advises across facilities" với coordinator.

### 9.4 Danh sách đầy đủ
- **"{Tên} services":** mới nhất hiện trước, tự tải thêm khi cuộn.
  - Chưa chọn loại hình: hàng chip **All** và các loại hình của nhu cầu đang có dịch vụ. Chạm một chip để mở danh sách của loại hình đó.
  - Đã chọn loại hình (ví dụ mở từ "View all"): tiêu đề theo tên loại hình, kèm thanh tab loại dịch vụ gồm **All** và các loại dịch vụ đang có dịch vụ. Tab nào không vừa một hàng thì gom vào nút **More**, mở danh sách đầy đủ có ô tìm "Search service types" khi danh sách dài.
- **"{Tên} providers":** danh sách chuyên gia đầy đủ của nhu cầu, cùng kiểu thẻ ở mục 9.3, tự tải thêm khi cuộn.
- Có trạng thái trống hoặc lỗi kèm nút thử lại.
- Chip loại hình đang chọn và dòng đang chọn trong danh sách More dùng màu xanh đại dương.

### 9.5 Gửi yêu cầu cho một dịch vụ hoặc offer (Send Inquiry)
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
Mở từ **Browse by need → Medical Travel** trong menu ☰. Trang dùng chung bố cục với các trang nhu cầu khác (mục 9.1):
- **Hero:** "The right care, wherever it takes you" và dòng mô tả "Treatment abroad, planned with people who walk every step with you."
- **"Browse by destination":** ngay dưới hero, mỗi quốc gia là một thẻ ảnh có cờ, tên, mô tả và nút "Explore →" mở trang điểm đến (mục 10.2). Hơn 3 nước thì cuộn ngang, ít hơn thì xếp lưới 2 cột. Không có dữ liệu thì ẩn.
- **Mục dịch vụ theo từng loại hình** cơ sở y tế (bệnh viện, phòng khám chuyên khoa, nha khoa, thẩm mỹ, đơn vị tổ chức du lịch y tế…), mỗi mục 2 dịch vụ và nút **View all**.
- **Chuyên gia:** cơ sở thuộc các loại hình trên hoặc nha sĩ, kèm nút **View all experts**.

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
- **Like · Save** ngay dưới bộ ảnh: hai nút có biểu tượng và chữ, đang bật thì viền và biểu tượng đổi màu (Like đỏ, Save vàng). Khách được mời đăng nhập; chủ dịch vụ thấy hai nút bị tắt.
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
- **Trạng thái đang chọn** ở phía người mua (chip lọc, nút chọn trong bộ lọc của trang điểm đến, lựa chọn trong form đặt lịch hẹn) cũng dùng màu xanh đại dương.
- **Ảnh dự phòng:** dịch vụ không có ảnh hoặc ảnh lỗi hiện ảnh dự phòng chung của StrongBody, cả ở Social Market lẫn thẻ dịch vụ trong chat.
- **Popup và bảng trượt** có nền trắng, chữ đen.
- **Tiền tệ:** hiển thị theo đúng đơn vị của từng nhà cung cấp, ví dụ $70, £70, €12.50.
- **Thời gian:** hiển thị dạng tương đối, ví dụ "5 minutes ago", "yesterday", "last week".

---

## 15. Tính năng chưa có trên app (đang phát triển)

- Trang chi tiết cho dịch vụ thường (không phải Medical Travel). Hiện ở Social Market, chạm vào thẻ dịch vụ thường sẽ mở thẳng bảng gửi yêu cầu; nút Book trên trang Offers chỉ hiện thông báo sắp ra mắt.
- Lối vào màn trợ lý AI (mục 4).
- Nút sửa yêu cầu (Edit request) sau khi AI chưa duyệt, như trên web.
- My reviews, Payment methods, Notifications, Help & support trong Account.
- Danh sách "nhà cung cấp đã lưu" riêng. Hiện mục này mở danh sách nhà cung cấp chung.
