# CocoaRestClient (Swift Edition)

A lightweight, modern, native macOS REST client built entirely with **Swift 6**, **SwiftUI**, and **Swift Concurrency (`async/await`)**.

[![macOS 13+](https://img.shields.io/badge/macOS-13.0%2B-blue.svg)](https://www.apple.com/macos)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL%203.0-green.svg)](LICENSE.txt)

---

## 🚀 Tính năng nổi bật (Features)

* **HTTP Methods**: GET, POST, PUT, DELETE, HEAD, OPTIONS, PATCH, COPY, SEARCH và Custom Methods.
* **Request Body linh hoạt**:
  * **Raw Input**: Tự động format, Beautify và tô màu cú pháp JSON, XML, Plain Text, HTML, JavaScript.
  * **Form URL-Encoded**: Soạn thảo các cặp Key-Value trực quan.
  * **Multipart Form-Data**: Hỗ trợ đính kèm files, tự nhận diện MIME type và nén Gzip.
  * **Binary File**: Tải lên tệp nhị phân trực tiếp.
* **URL Parameters & Headers**: Bảng chỉnh sửa Key-Value có thể bật/tắt (toggle) từng dòng; tự động đồng bộ 2 chiều giữa bảng tham số và thanh địa chỉ URL.
* **Biến môi trường (Environment Variables)**: Hỗ trợ cú pháp `${VAR_NAME}` trong URL, Headers, Params và Request Body.
* **Authentication**: Hỗ trợ HTTP Basic Auth (với Preemptive Auth), Bearer Token, và Digest Auth.
* **Response Inspector**:
  * Hiển thị mã trạng thái HTTP kèm màu sắc trực quan (2xx, 3xx, 4xx, 5xx).
  * Đo thời gian phản hồi (Latency / Response time theo mili-giây).
  * Tự động format / Pretty Print JSON và XML.
  * Xem Response Headers và Sent Headers (Header đã gửi qua mạng).
  * Phóng to / Thu nhỏ cỡ chữ xem kết quả, xuất file hoặc mở nhanh bằng trình duyệt mặc định.
* **Diff Tool (So sánh 2 Response)**: So sánh trực quan sự khác biệt giữa nội dung phản hồi của 2 tab (hỗ trợ hiển thị dòng thêm/bớt).
* **Lưu & Quản lý Requests (Sidebar & Fast Search)**:
  * Tổ chức theo cây thư mục phân cấp (Folders).
  * Tìm kiếm nhanh tức thì (Quick Open / Fast Search qua `Cmd+O`).
  * Xuất / Nhập (Export / Import) toàn bộ bộ sưu tập request dạng JSON.
  * Tương thích ngược tự động với dữ liệu lưu trữ cũ (`CocoaRestClient.savedRequests`).
* **Sao chép lệnh cURL**: Sinh câu lệnh `curl` hoàn chỉnh chuẩn xác chỉ với 1 phím tắt (`Cmd+Shift+C`).
* **Đa tab (Native Tabs)**: Mở và làm việc với nhiều request cùng lúc (`Cmd+T`, `Cmd+W`).
* **Tùy chỉnh & Bảo mật**: Cho phép chứng chỉ SSL tự ký (Self-Signed / Untrusted), cấu hình Timeout, kiểm soát Follow Redirects và Cookies.

---

## 📁 Cấu trúc thư mục mới (New Project Structure)

```
swift-rest-client/
├── Package.swift               # Cấu hình Swift Package Manager chuẩn
├── README.md                   # Tài liệu hướng dẫn dự án
├── LICENSE.txt                 # Giấy phép mã nguồn mở (GPL-3.0)
│
├── Resources/                  # Tài nguyên ứng dụng
│   ├── AppIcon.icns            # Icon ứng dụng macOS
│   ├── Info.plist              # Metadata ứng dụng (Bundle ID, Permissions,...)
│   └── Assets.xcassets/        # Asset catalog chứa AppIcon
│
├── Sources/
│   ├── CocoaRestClient/        # Target ứng dụng chính (SwiftUI macOS App)
│   │   ├── CocoaRestClientApp.swift   # Entrypoint @main & Menu bar commands
│   │   ├── ViewModels/         # Các ViewModels quản lý trạng thái
│   │   │   ├── WorkspaceViewModel.swift
│   │   │   ├── RequestTabViewModel.swift
│   │   │   ├── SavedRequestsViewModel.swift
│   │   │   ├── PreferencesViewModel.swift
│   │   │   └── DiffViewModel.swift
│   │   └── Views/              # Các giao diện SwiftUI
│   │       ├── MainView.swift
│   │       ├── RequestEditor/  # Header, Body, Headers, Params, Auth, Files
│   │       ├── ResponseViewer/ # Response Body, Headers, Sent Headers
│   │       ├── Sidebar/        # Cây thư mục request đã lưu
│   │       ├── Modals/         # Quick Open, Diff, Import/Export, Save Sheet
│   │       ├── Preferences/    # Cài đặt ứng dụng
│   │       └── Components/     # Text Editor, KeyValue Table, Status Badge
│   │
│   └── CocoaRestClientCore/    # Core logic & Networking library
│       ├── Models/             # RestRequest, RequestFolder, KeyValuePair, HTTPMethod,...
│       └── Services/           # NetworkEngine, RequestBodyBuilder, ResponseFormatter,
│                               # EnvironmentVariableResolver, CurlCommandGenerator,
│                               # DiffEngine, SavedRequestsStore
│
├── Tests/
│   └── CocoaRestClientTests/   # Bộ kiểm thử Unit Tests tự động (XCTest)
│       ├── RestRequestTests.swift
│       ├── RequestBodyBuilderTests.swift
│       ├── ResponseFormatterTests.swift
│       ├── EnvironmentVariableResolverTests.swift
│       ├── CurlCommandGeneratorTests.swift
│       ├── DiffEngineTests.swift
│       ├── NetworkEngineTests.swift
│       └── SavedRequestsStoreTests.swift
│
└── scripts/
    └── build_app.sh            # Script build đóng gói thành file .app độc lập
```

---

## 🛠️ Hướng dẫn Mở & Build Ứng dụng (Xcode macOS App)

### 1. Mở trực tiếp bằng Xcode (Khuyên dùng)
Bạn chỉ cần mở tệp dự án Xcode:
```bash
open CocoaRestClient.xcodeproj
```
* Nhấn **`Cmd + R`** để chạy trực tiếp ứng dụng macOS.
* Nhấn **`Cmd + U`** để chạy toàn bộ bộ kiểm thử Unit Tests.

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
| `Cmd + S` | Lưu Request |
| `Cmd + O` | Mở nhanh (Quick Open / Fast Search) |
| `Cmd + Shift + C` | Sao chép lệnh cURL |
| `Cmd + Shift + F` | Tự động format / Beautify JSON |
| `Cmd + D` | So sánh 2 Response (Diff tool) |
| `Cmd + ,` | Cài đặt ứng dụng (Preferences) |

---

## 📄 Bản quyền (License)
Xem file [LICENSE.txt](LICENSE.txt).
