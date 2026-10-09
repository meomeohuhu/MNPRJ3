# Technical Report — ReceiptWise

**Course:** Cross-Platform Mobile App Development (VKU)
**Mini-Project:** Mini-Project 3 – OCR Expense Tracker & Receipt Parser
**Student:** Nguyễn Thành Thịnh
**Student ID:** 23IT262
**Submission Date:** 08/10/2026

## 1. General Information & Deliverable Links

ReceiptWise là ứng dụng Flutter Android offline-first cho phép chụp/chọn hóa đơn, crop ảnh, nhận diện chữ bằng Google ML Kit on-device, phân tích total/date/merchant bằng Regex + heuristic, review trước khi lưu SQLite và xem analytics bằng CustomPainter.

- Repository: [GitHub MNPRJ3](https://github.com/meomeohuhu/MNPRJ3), branch `main` chứa source ReceiptWise.
- APK debug arm64: đã build thành công tại `build/app/outputs/flutter-apk/app-debug.apk`, SHA-256 `36745DB7AAB9137832DCBD8DEAA9B08C54DDE1BB0BBA4210B00141F97D4E1F49`.
- APK release arm64: đã build thành công tại `build/app/outputs/flutter-apk/app-release.apk`, SHA-256 `570F019444E0032F02517DC0BFB2C3E919885C09567D1D4F93F4056DB2F3CB80`. Cả hai APK đã được `apksigner verify --verbose --print-certs` xác nhận với APK Signature Scheme v2 và 1 signer RSA 2048-bit. APK chưa upload GitHub Release vì chưa cấu hình GitHub CLI/token.
- Render static site: [receiptwise-demo.onrender.com](https://receiptwise-demo.onrender.com), deploy từ branch `main` bằng `render.yaml`. Kiểm tra HTTP thực tế trả status 200 và title ReceiptWise.
- Video: chưa quay; kịch bản thực tế tại `docs/video-script.md`.

## 2. Feature Implementation Checklist

| Hạng mục | Trạng thái |
|---|---|
| Material 3, tiếng Việt, light/dark theme | Đã triển khai |
| Camera, flash, focus, gallery, crop | Đã triển khai trong source; cần thiết bị để xác minh |
| OCR offline ML Kit | Đã triển khai trong source; cần thiết bị/model để xác minh |
| Regex/heuristic parser + review | Đã triển khai và có unit tests |
| SQLite CRUD, file persistence, thumbnail | Đã triển khai trong source; cần chạy app để xác minh |
| History, search, category filter, detail | Đã triển khai |
| Donut/weekly chart bằng CustomPainter | Đã triển khai với animation/tap |
| Static landing page và Render config | Đã chuẩn bị |

## 3. Technical Architecture & Project Structure

Presentation nằm trong `lib/features`, reusable widgets trong `lib/core/widgets`, entity trong `lib/models`. `ExpenseProvider` dùng ChangeNotifier điều phối `ExpenseRepository` và refresh sau CRUD. `DatabaseService` mở SQLite version 1; `FileStorageService` lưu ảnh trong application documents và tạo thumbnail. `OcrService` chỉ phụ trách ML Kit; `ReceiptParserService` là pure Dart để test độc lập; `AggregationService` gom theo tháng/tuần/category.

Luồng chính: Camera/Gallery → Crop → OcrService → ReceiptParserService → ReceiptReviewScreen → ExpenseProvider → SQLite + app documents → Dashboard/History/Analytics.

## 4. Empirical Evidence & Screenshots

Ảnh chụp thực tế chưa được tạo vì môi trường hiện tại không có Android device/emulator kết nối. Khi có thiết bị, cần chèn 3–4 ảnh không chỉnh sửa: Dashboard, Scanner frame, Review sau OCR và Analytics/History sau khi restart. Không sử dụng ảnh giả làm bằng chứng.

## 5. Technical Challenges & Resolutions

- **OCR không ổn định theo chất lượng ảnh:** thêm crop thật, giới hạn ảnh crop ở kích thước phù hợp, timeout 30 giây, báo lỗi ảnh không có chữ và buộc review trước khi lưu. Với nhiều bill trong một ảnh, người dùng nên crop từng bill.
- **Nhiều số tiền trên hóa đơn:** parser chấm điểm keyword thanh toán, giảm điểm VAT/discount/change/unit price và đánh dấu `totalAmount` chưa chắc chắn khi candidate gần nhau.
- **Dữ liệu phải tồn tại sau restart:** dùng SQLite và copy ảnh sang application documents, không giữ đường dẫn temporary cache.
- **Không dùng chart library:** donut và weekly bar được viết bằng Canvas/CustomPainter, có animation và hit testing.
- **Lỗi APK không có chữ ký:** cấu hình release trước đây không gán `signingConfig`, nên APK release cũ không có signature block và Android báo `APK contains no signature files`. Đã cấu hình debug signing mặc định và release signing qua biến môi trường, đồng thời thêm task validation để chặn release unsigned.
- **Crash khi chụp/chọn ảnh:** `image_cropper` yêu cầu `com.yalantis.ucrop.UCropActivity` trong Android manifest; activity này bị thiếu nên cả hai luồng đều văng lúc mở màn hình crop. Đã khai báo activity với `@style/Ucrop.CropTheme` và gia cố xử lý lifecycle camera, gallery cancellation và lỗi native plugin.
- **Bill có nhãn tổng khác nhau:** bổ sung heuristic cho `TỔNG:`, `TỔNG TIỀN`, `TỔNG TIỀN HÀNG`, `TỔNG CỘNG`, `TOTAL` và loại trừ `TỔNG SỐ LƯỢNG`; thêm test cho bill spa, bán lẻ và nhà hàng.
- **Locale formatting:** khởi tạo `vi_VN` bằng `initializeDateFormatting` trước `runApp` để tránh lỗi `Locale data has not been initialized` khi format ngày/tiền.
- **Giới hạn môi trường:** đã cài Flutter 3.47.6/Dart 3.13.5, Android toolchain và xác minh `flutter clean`, `flutter pub get`, `flutter analyze`, `flutter test`, build debug/release và chữ ký APK. Chưa kiểm thử trực tiếp camera/OCR/SQLite persistence trên thiết bị thật vì chưa có Android device/emulator kết nối.
