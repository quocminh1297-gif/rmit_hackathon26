# LegacyVault — Digital Inheritance Vault
> **RMIT x Tide "Unlocked" Hackathon (Challenge 2: What would you build if trust stopped being the bottleneck?)**

---

## 1. Tuyên bố Tầm nhìn & Ràng buộc Tin cậy (Trust Bottleneck Insight)
Trong các giải pháp di chúc truyền thống hoặc két sắt điện tử đám mây:
* **Nút thắt tin cậy (Trust Bottleneck)**: Người dùng bắt buộc phải gửi trọn niềm tin vào một bên thứ ba (Luật sư, Công chứng viên, hoặc Admin hệ thống lưu trữ Cloud). Admin hoặc hacker chiếm quyền máy chủ có thể đơn phương xem trộm toàn bộ tâm thư, mật khẩu tài khoản và khóa riêng tư (Private Key/Seed Phrase) của người đã mất.
* **Giải pháp với Tide Cloak & Emergent Authority**:
  * **Không ai sở hữu Master Key**: Bản thân Admin nền tảng hoàn toàn bất lực trước các bản mã E2EE.
  * **Quyền hạn chỉ xuất hiện khi đủ điều kiện (Emergent Authority)**: Dữ liệu di chúc chỉ có thể được giải mã khi đạt đủ **ngưỡng đồng thuận Quorum (3-of-5 hoặc 4-of-5 Người ủy thác)** được chứng thực bằng chữ ký mật mã phi tập trung (Tide IGA & Enclave).

---

## 2. Các Nhân vật Thực tế trong Demo (Synthetic Personas)
Tất cả 7 nhân vật đều là tài khoản thật trên cụm **TideCloak Hosted (Skycloak)** với mật khẩu chung: `LegacyVault2026!`

| Username | Tên Nhân Vật | Vai Trò | Quyền Hạn TideCloak |
|---|---|---|---|
| `lan` | Bà Lan | Chủ sở hữu di chúc (Owner) | `appUser`, `_tide_vault.selfencrypt` |
| `admin` | Platform Admin | Quản trị viên máy chủ | `appUser` (*Bất lực, không có Master Key*) |
| `mai` | Mai (Con gái) | Trustee 1/5 & Người nhận | `trustee`, `recipient-mai` |
| `minh` | Minh (Con trai) | Trustee 2/5 & Người nhận | `trustee`, `recipient-minh` |
| `hanh` | Hạnh (Bạn thân) | Trustee 3/5 & Người nhận | `trustee`, `recipient-hanh` |
| `tuan` | Tuấn (Luật sư) | Trustee 4/5 (Đại diện pháp lý) | `trustee`, `recipient-tuan` |
| `thu` | Thu (Người thi hành) | Trustee 5/5 (Thi hành di chúc) | `trustee`, `recipient-thu` |

---

## 3. Các Mục Di Chúc & Ngưỡng Đồng Thuận (Quorum)
1. **Tâm thư gửi con gái Mai**: Ngưỡng **3/5 Trustees** & Người nhận `recipient-mai`.
2. **Hợp đồng & Giấy chứng nhận nhà đất**: Ngưỡng **3/5 Trustees** & Người nhận `recipient-mai`, `recipient-minh`.
3. **Seed Phrase 24 từ ví Crypto thừa kế**: Ngưỡng cao nhất **4/5 Trustees** & Người nhận `recipient-mai`, `recipient-minh`.

---

## 4. Ghi nhãn Phân định Ranh giới Kỹ thuật (Labeling)
* **TideCloak Enforced**:
  * Xác thực OIDC qua khóa EdDSA & DPoP Token Binding.
  * Phê duyệt trạng thái thay đổi phân quyền thông qua **Tide IGA (Identity Governance & Administration)**.
  * Cách ly quyền hạn: Admin không sở hữu khóa giải mã.
* **`[APP-LEVEL]` Labelled Logic**:
  * Tính năng an toàn **Bà Lan hủy kích hoạt di chúc khi còn sống** được triển khai ở tầng ứng dụng và được dán nhãn minh bạch `[APP-LEVEL SAFEGUARD]`.
  * Hợp đồng thông minh Forseti được lưu tại [`contracts/LegacyVaultContract.cs`](file:///d:/Coding/Hackathon/contracts/LegacyVaultContract.cs) với nhãn **"DESIGNED, NOT DEPLOYED"** (theo quy định của Tide, việc triển khai hợp đồng Forseti tùy biến lên mạng chính cần sự xét duyệt của đội ngũ Tide core).

---

## 5. Hướng dẫn Chạy Thử Ứng Dụng (Quick Start)
1. Cài đặt thư viện:
   ```bash
   npm install
   ```
2. Khởi chạy dev server:
   ```bash
   npm run dev
   ```
3. Mở trình duyệt tại: `http://localhost:3000`
4. Sử dụng thanh **Hackathon Persona Switcher** ở đầu trang để chuyển đổi qua lại giữa các nhân vật để trải nghiệm toàn bộ kịch bản!
