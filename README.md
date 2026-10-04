# Hotpot Save Studio for iPhone

Ứng dụng SwiftUI độc lập, xử lý tệp `.plist` do người dùng tự chọn từ Files:

1. Giải mã `key_player_data` (JSON) và `Data_BackUp` (Base64 → GZIP → JSON).
2. Giữ các JSON đã giải mã trong `Application Support/Decoded_GameData` của chính app.
3. Chỉnh sửa nhanh các trường hay dùng hoặc trực tiếp toàn bộ JSON.
4. Đóng gói lại Binary PLIST và xuất `hotpot_repacked.bplist` về Files.
5. Sau khi xuất thành công, hỏi rõ giữ hay xóa `Decoded_GameData`.

## Mở và ký IPA

Thư mục này là mã nguồn Xcode, không phải IPA đã ký. IPA chỉ có thể được ký với chứng chỉ/provisioning profile của bạn trên macOS/Xcode (hoặc một CI macOS có các thông tin ký hợp lệ).

Trên Mac có Xcode bản mới hỗ trợ iOS 26:

```sh
brew install xcodegen
cd HotpotSaveEditor
xcodegen generate
open HotpotSaveEditor.xcodeproj
```

Trong Xcode, chọn target **HotpotSaveEditor**, thay `PRODUCT_BUNDLE_IDENTIFIER` bằng Bundle ID của bạn nếu cần, chọn Team ở **Signing & Capabilities**, sau đó dùng **Product → Archive** để xuất IPA cho phương thức phân phối mà tài khoản của bạn cho phép.

## Tạo IPA không cần Mac cá nhân

Workflow GitHub Actions sẵn có tại `.github/workflows/build-ipa.yml`. Xem hướng dẫn chi tiết trong cuộc trò chuyện để tạo certificate/profile và GitHub Secrets. Workflow dùng máy `macos-26`, tạo project bằng XcodeGen, ký Ad Hoc, sau đó lưu IPA làm Artifact để tải xuống.

## Kiểm thử bắt buộc trước khi dùng dữ liệu thật

- Nhập một bản sao của plist, không dùng bản duy nhất.
- Không chỉnh sửa gì, xuất lại, rồi xác thực rằng file output vẫn mở được.
- Chỉ sau đó mới thử từng thay đổi nhỏ. App không tự ghi đè file nguồn.

## Ghi chú triển khai

`GzipCodec.swift` tự tạo GZIP đúng định dạng bằng raw DEFLATE của framework Compression và thêm header/checksum/trailer GZIP. Điều này giữ tương thích với luồng Python `gzip.compress`/`gzip.decompress` hiện có.
