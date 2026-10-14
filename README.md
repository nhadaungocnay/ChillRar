# ChillRar 🧊

Ứng dụng giải nén file `.rar` tối ưu dành riêng cho **macOS Apple Silicon (Chip M1/M2/M3/M4)**.

Được phát triển với engine **UnRAR 7.3.1 chính thức từ RARLAB** viết bằng C++ (kích hoạt giải mã phần cứng ARM NEON/AES), kết hợp giao diện **SwiftUI** hiện đại, mượt mà và an toàn.

---

## ✨ Tính năng nổi bật

- ⚡️ **Native arm64 siêu nhanh**: Tận dụng tối đa CPU Apple Silicon và tập lệnh tăng tốc mã hoá NEON.
- 🗂️ **Hỗ trợ định dạng toàn diện**: RAR 5.0+, RAR 4.0 (legacy) và RAR 7 (từ điển lớn > 4GB).
- 🧩 **Multi-volume (.partN.rar, .r00)**: Tự động phát hiện và bắt đầu giải nén từ phần 1 dù bạn kéo thả hay mở bất kỳ part nào (`.part3.rar`, `.r02`...).
- 🔒 **Bảo vệ bằng mật khẩu**: Hỗ trợ đầy đủ file có mật khẩu thông thường và file mã hoá cả tiêu đề danh sách file (Encrypted Headers).
- 👁️ **Xem trước & chọn lọc file**: Xem cây thư mục, tìm kiếm lọc file và chỉ giải nén những mục bạn cần mà không phải trích xuất cả archive.
- ⏳ **Tiến trình trực quan & Huỷ an toàn**: Hiển thị thanh tiến trình chi tiết (% byte, % số file, tên file đang xử lý), có nút Huỷ tức thì.
- 🛡️ **Bảo vệ dữ liệu (Không bao giờ ghi đè file có sẵn)**:
  - Tự động giải nén qua thư mục tạm, hoàn tất mới chuyển ra đích.
  - Tự động đặt tên `file 2.ext` nếu trùng lặp.
  - Tự động gán thuộc tính `com.apple.quarantine` để bảo đảm an toàn Gatekeeper.
- 🖱️ **Tích hợp sâu macOS & Finder**:
  - Hỗ trợ Kéo - Thả (Drag & Drop) vào ứng dụng.
  - Đăng ký mở mặc định (Open With) cho các file `.rar`, `.r00`...
  - Menu Quick Action / Services: Chuột phải vào file `.rar` trong Finder -> Chọn **"Giải nén bằng ChillRar"**.

---

## 🚀 Cài đặt & Sử dụng

### 1. Build & Cài đặt vào `/Applications`

Bạn chỉ cần mở Terminal tại thư mục dự án và chạy:

```bash
# Build ứng dụng ChillRar.app và CLI tool
make

# Cài đặt ChillRar.app trực tiếp vào /Applications
make install
```

> **Ghi chú**: Không cần cài đặt Xcode nặng nề! Dự án đã được thiết kế để biên dịch hoàn hảo chỉ với **Command Line Tools** có sẵn trên macOS.

### 2. Sử dụng Giao diện (GUI App)

- Mở ứng dụng `ChillRar` từ `/Applications` hoặc Spotlight (`Cmd + Space` -> `ChillRar`).
- **Kéo và thả** bất kỳ file `.rar` nào vào cửa sổ ứng dụng.
- Hoặc bấm chuột phải vào file `.rar` trong Finder -> chọn **Open With -> ChillRar** (hoặc **Quick Actions -> Giải nén bằng ChillRar**).

### 3. Sử dụng Dòng lệnh (CLI tool)

File thực thi CLI nằm tại `build/chillrar`:

```bash
# Xem danh sách file trong archive
./build/chillrar l /path/to/archive.rar

# Giải nén archive vào cùng thư mục
./build/chillrar x /path/to/archive.rar

# Giải nén có mật khẩu vào thư mục chỉ định
./build/chillrar x /path/to/archive.rar -p "MatKhau123" -o ~/Downloads/Output

# Buộc tạo thư mục riêng theo tên archive
./build/chillrar x /path/to/archive.rar --folder
```

### 4. Chạy kiểm thử tự động (Unit & Integration Tests)

Hệ thống có bộ 28 bài test tự động bao phủ Unicode, mật khẩu, file chia phần, phục hồi lỗi, chống ghi đè:

```bash
make test
```

---

## 🏛️ Cấu trúc dự án

```
ChillRar/
├── Makefile                          # Script build chính (swiftc + clang native)
├── Package.swift                     # Khai báo cấu trúc Swift package
├── Resources/
│   ├── Info.plist                    # Khai báo UTI, Document Type & Finder Services
│   └── AppIcon.icns                  # Bộ icon ứng dụng macOS chuẩn Retina
├── Vendor/
│   ├── unrar/                        # Mã nguồn UnRAR 7.3.1 chính thức (C++)
│   └── lib/libunrar.a                # Thư viện static arm64 được tối ưu
├── Sources/
│   ├── CUnrar/                       # C shim & module map kết nối C++ vào Swift
│   ├── RarKit/                       # Thư viện Swift lõi (an toàn thread, async/await)
│   │   ├── RarArchive.swift          # Bridge gọi API UnRAR qua serial queue
│   │   ├── Extractor.swift           # Quản lý thư mục tạm, vị trí lưu, quarantine
│   │   ├── VolumeResolver.swift      # Tìm kiếm volume đầu tiên (.partN, .rNN)
│   │   ├── RarEntry.swift            # Model file/folder/tiến trình
│   │   └── RarError.swift            # Ánh xạ mã lỗi thân thiện người dùng
│   ├── ChillRar/                     # Ứng dụng SwiftUI
│   │   ├── ChillRarApp.swift         # Entry point & Menu commands
│   │   ├── AppDelegate.swift         # Tiếp nhận file từ Finder & Services
│   │   ├── AppModel.swift            # Observable ViewModel
│   │   ├── DropZoneView.swift        # Màn hình kéo thả & chọn file
│   │   ├── ArchiveDetailView.swift   # Bảng duyệt file, tìm kiếm & giải nén
│   │   ├── PasswordModalView.swift   # Sheet nhập mật khẩu
│   │   └── ProgressModalView.swift   # Sheet hiển thị % tiến trình & hoàn thành
│   └── chillrar-cli/                 # Công cụ dòng lệnh
└── Tests/
    ├── SelfTest/                     # Unit test không phụ thuộc XCTest
    └── Scripts/integration_test.sh   # 28 bài test giải nén thực tế
```

---

## 📜 Bản quyền

- Mã nguồn ứng dụng ChillRar và RarKit: MIT License.
- Mã nguồn thư viện giải nén UnRAR: Bản quyền © Alexander Roshal (RARLAB). Miễn phí phân phối theo giấy phép chính thức của RARLAB.
