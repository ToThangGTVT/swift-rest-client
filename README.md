# CocoaRestClient (Swift Edition)

A lightweight, modern, native macOS REST client built entirely with **Swift 6**, **SwiftUI**, and **Swift Concurrency (`async/await`)**.

[![macOS 13+](https://img.shields.io/badge/macOS-13.0%2B-blue.svg)](https://www.apple.com/macos)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL%203.0-green.svg)](LICENSE.txt)

<img width="1278" height="1002" alt="Screenshot 2026-08-28 at 09 45 14" src="https://github.com/user-attachments/assets/dec8f70a-b109-4886-bd4c-4ce559a009f1" />

---

## 🚀 Tính năng nổi bật (Features)

* **HTTP & GraphQL Methods**: GET, POST, PUT, DELETE, HEAD, OPTIONS, PATCH, COPY, SEARCH và Custom Methods.
* **Chế độ Body chuyên biệt**:
  * **Raw Input**: Tự động format, Beautify và tô màu cú pháp JSON, XML, Plain Text, HTML, JavaScript.
  * **GraphQL**: Trình soạn thảo Query / Mutation và Variables JSON riêng biệt.
  * **Form URL-Encoded**: Soạn thảo các cặp Key-Value trực quan.
  * **Multipart Form-Data**: Hỗ trợ đính kèm files, tự nhận diện MIME type và nén Gzip.
  * **Binary File**: Tải lên tệp nhị phân trực tiếp.
* **Import từ câu lệnh cURL (`Cmd + Shift + I`)**:
  * Dán hoặc nhập trực tiếp câu lệnh cURL (từ Swagger, Postman, Chrome DevTools); tự động parse URL, Method, Headers, Auth, và Payload.
  * Tự động nhận diện khi dán lệnh cURL vào thanh địa chỉ URL.
* **Lịch sử Request (Request History)**:
  * Tự động ghi lại lịch sử gửi API (kèm mã HTTP, độ trễ và kích thước payload).
  * Chuyển đổi linh hoạt giữa cây **Saved Requests** và **History** trên Sidebar.
* **Quản lý Environment Profiles & Biến môi trường (`Cmd + Shift + E`)**:
  * Tạo các bộ môi trường: Dev, Staging, Production...
  * Hỗ trợ cú pháp thay thế `{{variableName}}` và `${variableName}` trong URL, Headers, Params, Body.
* **Sinh mã nguồn đa ngôn ngữ (Code Snippets `Cmd + Shift + G`)**:
  * Xuất mã nguồn gọi API cho: **Swift (`URLSession`)**, **Python (`requests`)**, **JavaScript (`fetch`)**, **Node.js (`axios`)**, **Go (`net/http`)**, **cURL**.
* **Response Inspector Nâng cao**:
  * **Tìm kiếm nội tuyến (`Cmd + F`)**: Tìm từ khóa trong Response Body kèm bộ đếm kết quả.
  * **Chế độ xem đa dạng**: `Pretty`, `Raw`, `HTML Preview` (render qua WebKit), `Image Viewer` (xem trực tiếp ảnh).
  * Hiển thị mã trạng thái HTTP, Response Latency (ms), và Response Size (Bytes/KB/MB).
  * Xem Response Headers và Sent Headers (Header thực tế gửi qua socket mạng).
* **Diff Tool (So sánh 2 Response `Cmd + D`)**: So sánh trực quan sự khác biệt line-by-line giữa nội dung phản hồi của 2 tab.
* **Lưu & Quản lý Requests (Sidebar & Fast Search `Cmd + O`)**:
  * Tổ chức theo cây thư mục phân cấp (Folders).
  * Xuất / Nhập (Export / Import) toàn bộ bộ sưu tập request dạng JSON.
  * Tương thích ngược tự động với dữ liệu lưu trữ cũ (`CocoaRestClient.savedRequests`).
* **Đa tab (Native Tabs)**: Mở và làm việc với nhiều request cùng lúc (`Cmd + T`, `Cmd + W`).
* **Tùy chỉnh & Bảo mật**: Cho phép chứng chỉ SSL tự ký (Self-Signed / Untrusted), cấu hình Timeout, kiểm soát Follow Redirects và Cookies.

---

## 🛠️ Hướng dẫn Mở & Build Ứng dụng (Xcode macOS App)

### 1. Mở trực tiếp bằng Xcode (Khuyên dùng)
Bạn chỉ cần mở tệp dự án Xcode:
```bash
open CocoaRestClient.xcodeproj
```
* Nhấn **`Cmd + R`** để chạy trực tiếp ứng dụng macOS.
* Nhấn **`Cmd + U`** để chạy toàn bộ 30 bài kiểm thử Unit Tests.

### 2. Build & Test qua Command Line (xcodebuild)
```bash
# Chạy toàn bộ Unit Tests
xcodebuild test -project CocoaRestClient.xcodeproj -scheme CocoaRestClient -destination 'platform=macOS'

# Build bản Release
xcodebuild -project CocoaRestClient.xcodeproj -scheme CocoaRestClient -configuration Release -destination 'platform=macOS' build
```

### 3. Đóng gói nhanh thành App độc lập
```bash
./scripts/build_app.sh
```
File ứng dụng hoàn chỉnh sẽ được đóng gói tại: `build/CocoaRestClient.app`.

---

## ⌨️ Phím tắt hữu ích (Shortcuts)

| Phím tắt | Chức năng |
| :--- | :--- |
| `Cmd + Return` | Gửi Request |
| `Cmd + R` | Nạp lại Request trước |
| `Cmd + T` | Mở Tab mới |
| `Cmd + W` | Đóng Tab hiện tại |
| `Cmd + S` | Lưu Request vào Sidebar |
| `Cmd + O` | Mở nhanh (Quick Open / Fast Search) |
| `Cmd + Shift + I` | Nhập / Import từ lệnh cURL |
| `Cmd + Shift + G` | Sinh mã nguồn gọi API (Code Snippets) |
| `Cmd + Shift + E` | Quản lý Environments & Biến môi trường |
| `Cmd + Shift + C` | Sao chép lệnh cURL |
| `Cmd + Shift + F` | Tự động format / Beautify JSON |
| `Cmd + D` | So sánh 2 Response (Diff tool) |
| `Cmd + ,` | Cài đặt ứng dụng (Preferences) |

---

## 📄 Bản quyền (License)
Xem file [LICENSE.txt](LICENSE.txt).
