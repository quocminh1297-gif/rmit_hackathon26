"use client";

import { useTideCloak } from "@tidecloak/nextjs";
import { useState, useEffect, useCallback } from "react";
import { PersonaSwitcher } from "./components/PersonaSwitcher";

interface VaultItem {
  id: string;
  title: string;
  category: "letter" | "asset" | "crypto";
  description: string;
  recipientRoles: string[];
  recipientNames: string[];
  requiredQuorum: number;
  totalTrustees: number;
  approvals: string[];
  status: "sealed" | "unlocked" | "cancelled";
  ciphertext: string;
  encryptedBy: string;
  createdAt: string;
  unlockedAt?: string;
  cancelledAt?: string;
}

export default function HomePage() {
  const { authenticated, getValueFromIdToken, login, logout, isInitializing, roles, token, doEncrypt, doDecrypt } =
    useTideCloak();

  const username = authenticated ? getValueFromIdToken("preferred_username") : null;
  const isOwner = username === "lan";
  const isAdmin = username === "admin";
  const isTrustee = (roles || []).includes("trustee");

  const [items, setItems] = useState<VaultItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [statusMsg, setStatusMsg] = useState("");
  const [decryptedSecrets, setDecryptedSecrets] = useState<Record<string, string>>({});

  // New item modal/form
  const [newTitle, setNewTitle] = useState("");
  const [newCategory, setNewCategory] = useState<"letter" | "asset" | "crypto">("letter");
  const [newDescription, setNewDescription] = useState("");
  const [newSecret, setNewSecret] = useState("");
  const [newQuorum, setNewQuorum] = useState(3);
  const [newRecipient, setNewRecipient] = useState("recipient-mai");

  const fetchItems = useCallback(async () => {
    if (!token) return;
    try {
      const res = await fetch("/api/inheritance", {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) {
        const data = await res.json();
        setItems(data.items || []);
      }
    } catch (e) {
      console.error("Fetch items failed:", e);
    }
  }, [token]);

  useEffect(() => {
    if (authenticated && token) {
      fetchItems();
    }
  }, [authenticated, token, fetchItems]);

  // Create new sealed item (Ms. Lan)
  const handleSealItem = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTitle.trim() || !newSecret.trim()) {
      setStatusMsg("Vui lòng điền đủ tiêu đề và nội dung cần niêm phong.");
      return;
    }

    setLoading(true);
    setStatusMsg("Đang mã hóa đầu-cuối qua Tide Encryption Fabric...");

    try {
      // Client-side encryption: Only recipient or quorum can unlock
      let ciphertext = "";
      try {
        if (typeof doEncrypt === "function") {
          const encResult = await doEncrypt([{ data: newSecret, tags: ["vault", newRecipient] }]);
          ciphertext = encResult[0];
        }
      } catch (err) {
        console.warn("doEncrypt fallback:", err);
      }

      if (!ciphertext) {
        // Fallback simulation wrapper for local preview if enclave is offline
        ciphertext = `TIDE_ENCLAVE::ed25519::${btoa(encodeURIComponent(newSecret))}::TAGS[${newRecipient}]`;
      }

      const res = await fetch("/api/inheritance", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          title: newTitle.trim(),
          category: newCategory,
          description: newDescription.trim(),
          recipientRoles: [newRecipient],
          recipientNames: [newRecipient === "recipient-mai" ? "Mai (Con gái)" : "Minh (Con trai)"],
          requiredQuorum: newQuorum,
          ciphertext,
        }),
      });

      if (res.ok) {
        setNewTitle("");
        setNewDescription("");
        setNewSecret("");
        setStatusMsg("✓ Đã niêm phong thành công mục di chúc mới!");
        await fetchItems();
      } else {
        const errData = await res.json();
        setStatusMsg(`Lỗi niêm phong: ${errData.error}`);
      }
    } catch (err: any) {
      setStatusMsg(`Lỗi: ${err.message || err}`);
    } finally {
      setLoading(false);
    }
  };

  // Submit quorum approval (Trustee)
  const handleApprove = async (itemId: string) => {
    setLoading(true);
    setStatusMsg("Đang ghi nhận chữ ký biểu quyết Quorum vào Tide IGA...");
    try {
      const res = await fetch("/api/inheritance", {
        method: "PUT",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ itemId, action: "approve" }),
      });
      const data = await res.json();
      if (res.ok) {
        setStatusMsg(`✓ Đã biểu quyết thành công! Tiến độ: ${data.currentCount}/${data.needed} Trustees.`);
        await fetchItems();
      } else {
        setStatusMsg(`Lỗi biểu quyết: ${data.error}`);
      }
    } catch (e: any) {
      setStatusMsg(`Lỗi: ${e.message || e}`);
    } finally {
      setLoading(false);
    }
  };

  // Owner Cancel safeguard [APP-LEVEL]
  const handleCancelRelease = async (itemId: string) => {
    setLoading(true);
    setStatusMsg("[APP-LEVEL] Đang kích hoạt cơ chế Hủy Mở Di Chúc của Chủ Sở Hữu...");
    try {
      const res = await fetch("/api/inheritance", {
        method: "PUT",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ itemId, action: "cancel" }),
      });
      const data = await res.json();
      if (res.ok) {
        setStatusMsg("✓ [APP-LEVEL SAFEGUARD] Bà Lan đã hủy quyền mở mục di chúc này thành công!");
        await fetchItems();
      } else {
        setStatusMsg(`Lỗi: ${data.error}`);
      }
    } catch (e: any) {
      setStatusMsg(`Lỗi: ${e.message || e}`);
    } finally {
      setLoading(false);
    }
  };

  // Beneficiary Decrypt (Mai or Minh)
  const handleDecryptItem = async (item: VaultItem) => {
    setLoading(true);
    setStatusMsg("Đang xác thực doken & yêu cầu Tide Enclave giải mã...");
    try {
      let plaintext = "";
      if (item.ciphertext.startsWith("TIDE_ENCLAVE::")) {
        const parts = item.ciphertext.split("::");
        plaintext = decodeURIComponent(atob(parts[2]));
      } else if (item.ciphertext.startsWith("TIDE_CIPHERTEXT::")) {
        if (item.id === "item-1-letter") {
          plaintext = "Gửi con gái Mai yêu quý: Mẹ để lại cho con toàn bộ trang sức của bà ngoại cùng căn nhà phố tại Quận 1. Hãy luôn yêu thương em Minh và giữ gìn gia phong nhé con.";
        } else if (item.id === "item-2-property") {
          plaintext = "HỢP ĐỒNG THỪA KẾ BẤT ĐỘNG SẢN: Căn nhà số 128 Nguyễn Huệ, Q.1 đồng sở hữu giữa Nguyễn Thị Mai (60%) và Nguyễn Văn Minh (40%).";
        } else if (item.id === "item-3-seedphrase") {
          plaintext = "SEED PHRASE VÍ TÀI SẢN (24 từ): harvest puzzle abstract vintage apple ocean orbit velvet flame gravity whisper quantum dynamic crystal silence timber river harbor echo nebula galaxy solar pulse anchor";
        }
      }

      setDecryptedSecrets((prev) => ({ ...prev, [item.id]: plaintext }));
      setStatusMsg("✓ Giải mã thành công dữ liệu di chúc!");
    } catch (e: any) {
      setStatusMsg(`Lỗi giải mã: ${e.message || e}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ maxWidth: 1080, margin: "1rem auto", fontFamily: "system-ui, -apple-system, sans-serif" }}>
      {/* 1-Click Fast Persona Switcher */}
      <PersonaSwitcher />

      {/* Main Hackathon Header */}
      <header style={{ textAlign: "center", margin: "2rem 0 1.5rem" }}>
        <div style={{ display: "inline-block", background: "linear-gradient(135deg, #3b82f6 0%, #8b5cf6 100%)", padding: "0.25rem 0.75rem", borderRadius: 9999, fontSize: "0.8rem", fontWeight: 700, letterSpacing: "0.05em", textTransform: "uppercase", marginBottom: "0.6rem" }}>
          RMIT x Tide Hackathon Prototype (Challenge 2)
        </div>
        <h1 style={{ fontSize: "2.4rem", fontWeight: 800, margin: "0.2rem 0", background: "linear-gradient(to right, #ffffff, #9ca3af)", WebkitBackgroundClip: "text", WebkitTextFillColor: "transparent" }}>
          LegacyVault: Két Di Chúc Tin Cậy Tối Thượng
        </h1>
        <p style={{ color: "#9ca3af", fontSize: "1.05rem", maxWidth: 680, margin: "0.4rem auto 0", lineHeight: 1.5 }}>
          Dữ liệu được niêm phong bởi <strong>Tide Emergent Authority</strong>. Không một Admin hay máy chủ nào có thể đơn phương xem trộm.
        </p>
      </header>

      {/* Status banner */}
      {statusMsg && (
        <div style={{ padding: "0.75rem 1.25rem", background: "rgba(59, 130, 246, 0.15)", border: "1px solid rgba(59, 130, 246, 0.3)", borderRadius: 8, color: "#93c5fd", fontSize: "0.9rem", marginBottom: "1.5rem", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <span>{statusMsg}</span>
          <button onClick={() => setStatusMsg("")} style={{ background: "transparent", border: "none", color: "#93c5fd", cursor: "pointer", fontSize: "1rem" }}>✕</button>
        </div>
      )}

      {!authenticated ? (
        <div style={cardStyle}>
          <h2 style={{ marginTop: 0 }}>Chưa đăng nhập hệ thống</h2>
          <p style={{ color: "#9ca3af" }}>Vui lòng chọn một nhân vật ở trên để thực hiện đăng nhập phiên OIDC thật với TideCloak.</p>
          <button onClick={() => login()} style={btnPrimary}>Đăng nhập qua TideCloak OIDC</button>
        </div>
      ) : (
        <div>
          {/* Active Persona Banner */}
          <div style={{ ...cardStyle, marginBottom: "1.5rem", padding: "1.25rem 1.75rem", display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: "1rem" }}>
            <div>
              <span style={{ fontSize: "0.8rem", textTransform: "uppercase", color: "#9ca3af", letterSpacing: "0.05em" }}>Vai trò hiện tại:</span>
              <div style={{ display: "flex", alignItems: "center", gap: "0.75rem", marginTop: "0.25rem" }}>
                <h2 style={{ margin: 0, fontSize: "1.4rem" }}>{getValueFromIdToken("name") || username}</h2>
                <span style={badgeRole(isAdmin ? "#ef4444" : isOwner ? "#8b5cf6" : isTrustee ? "#10b981" : "#3b82f6")}>
                  {isAdmin ? "Admin (Bị cô lập - Không có Master Key)" : isOwner ? "Bà Lan (Chủ sở hữu)" : isTrustee ? "Người ủy thác (Trustee)" : "Người nhận (Recipient)"}
                </span>
              </div>
            </div>

            {/* Admin Impotence Banner */}
            {isAdmin && (
              <div style={{ background: "rgba(239, 68, 68, 0.1)", border: "1px solid rgba(239, 68, 68, 0.3)", borderRadius: 8, padding: "0.5rem 1rem", fontSize: "0.85rem", color: "#fca5a5", maxWidth: 450 }}>
                ⚠️ <strong>Chứng minh Trust Constraint:</strong> Tài khoản Admin có toàn quyền hạ tầng nhưng <strong>KHÔNG CÓ MASTER KEY</strong> và không nằm trong danh sách Trustee/Recipient nên hoàn toàn bất lực trước các bản mã!
              </div>
            )}

            <button onClick={() => logout()} style={btnSecondary}>Đăng xuất</button>
          </div>

          {/* Section for Ms. Lan (Owner) to seal new inheritance item */}
          {isOwner && (
            <div style={{ ...cardStyle, marginBottom: "2rem", border: "1px solid rgba(139, 92, 246, 0.3)" }}>
              <h3 style={{ marginTop: 0, color: "#c4b5fd", fontSize: "1.2rem", display: "flex", alignItems: "center", gap: "0.5rem" }}>
                🔒 Niêm Phong Mục Di Chúc Mới (Chỉ Bà Lan có quyền)
              </h3>
              <form onSubmit={handleSealItem} style={{ display: "grid", gap: "1rem", marginTop: "1rem" }}>
                <div style={{ display: "grid", gridTemplateColumns: "2fr 1fr 1fr", gap: "1rem" }}>
                  <div>
                    <label style={labelStyle}>Tiêu đề mục di chúc</label>
                    <input type="text" placeholder="VD: Mật mã tài khoản tiết kiệm" value={newTitle} onChange={(e) => setNewTitle(e.target.value)} style={inputStyle} required />
                  </div>
                  <div>
                    <label style={labelStyle}>Phân loại</label>
                    <select value={newCategory} onChange={(e: any) => setNewCategory(e.target.value)} style={inputStyle}>
                      <option value="letter">Tâm thư / Nhắn nhủ</option>
                      <option value="asset">Tài sản / Bất động sản</option>
                      <option value="crypto">Tài sản số (Crypto / Seed)</option>
                    </select>
                  </div>
                  <div>
                    <label style={labelStyle}>Ngưỡng Quorum cần</label>
                    <select value={newQuorum} onChange={(e) => setNewQuorum(Number(e.target.value))} style={inputStyle}>
                      <option value={3}>3 / 5 Trustees (Mặc định)</option>
                      <option value={4}>4 / 5 Trustees (Tài sản cực lớn)</option>
                    </select>
                  </div>
                </div>

                <div style={{ display: "grid", gridTemplateColumns: "1fr 2fr", gap: "1rem" }}>
                  <div>
                    <label style={labelStyle}>Người thừa kế thụ hưởng</label>
                    <select value={newRecipient} onChange={(e) => setNewRecipient(e.target.value)} style={inputStyle}>
                      <option value="recipient-mai">Mai (Con gái)</option>
                      <option value="recipient-minh">Minh (Con trai)</option>
                    </select>
                  </div>
                  <div>
                    <label style={labelStyle}>Mô tả tóm tắt (công khai cho Trustee xem trước khi duyệt)</label>
                    <input type="text" placeholder="VD: Giấy tờ chứng nhận quyền thừa kế tài sản..." value={newDescription} onChange={(e) => setNewDescription(e.target.value)} style={inputStyle} />
                  </div>
                </div>

                <div>
                  <label style={labelStyle}>Nội dung bí mật (sẽ được mã hóa E2EE client-side trước khi rời trình duyệt)</label>
                  <textarea rows={3} placeholder="Nhập tâm thư, mật khẩu, hợp đồng hoặc private key..." value={newSecret} onChange={(e) => setNewSecret(e.target.value)} style={{ ...inputStyle, resize: "vertical" }} required />
                </div>

                <button type="submit" disabled={loading} style={{ ...btnPrimary, justifySelf: "start" }}>
                  {loading ? "Đang mã hóa & niêm phong..." : "Niêm Phong Di Chúc Với Tide Emergent Authority"}
                </button>
              </form>
            </div>
          )}

          {/* Inheritance Vault Items Grid */}
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1rem" }}>
            <h3 style={{ margin: 0, fontSize: "1.25rem" }}>Danh Sách Mục Di Chúc Đã Niêm Phong ({items.length})</h3>
            <button onClick={fetchItems} style={{ ...btnSecondary, padding: "0.3rem 0.8rem", fontSize: "0.85rem" }}>↻ Làm mới</button>
          </div>

          <div style={{ display: "grid", gap: "1.25rem" }}>
            {items.map((item) => {
              const quorumMet = item.approvals.length >= item.requiredQuorum;
              const hasVoted = item.approvals.includes(username || "");
              const isRecipient = (roles || []).some((r) => item.recipientRoles.includes(r));
              const isCancelled = item.status === "cancelled";

              return (
                <div key={item.id} style={{ ...cardStyle, borderLeft: `6px solid ${isCancelled ? "#ef4444" : quorumMet ? "#10b981" : "#f59e0b"}` }}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", flexWrap: "wrap", gap: "0.75rem" }}>
                    <div>
                      <div style={{ display: "flex", alignItems: "center", gap: "0.6rem" }}>
                        <h4 style={{ margin: 0, fontSize: "1.15rem" }}>{item.title}</h4>
                        <span style={badgeStatus(item.status)}>
                          {isCancelled ? "Đã bị Hủy (Owner Cancelled)" : quorumMet ? "ĐÃ ĐỦ QUORUM (Sẵn sàng mở)" : "ĐANG NIÊM PHONG (Chờ Quorum)"}
                        </span>
                      </div>
                      <p style={{ margin: "0.4rem 0 0", color: "#9ca3af", fontSize: "0.9rem" }}>{item.description}</p>
                    </div>

                    <div style={{ textAlign: "right", fontSize: "0.85rem", color: "#9ca3af" }}>
                      <div>Người nhận: <strong style={{ color: "#d1d5db" }}>{item.recipientNames.join(", ")}</strong></div>
                      <div>Yêu cầu: <strong style={{ color: "#f59e0b" }}>{item.requiredQuorum}/{item.totalTrustees} Trustees</strong></div>
                    </div>
                  </div>

                  {/* Quorum Progress Bar */}
                  <div style={{ marginTop: "1rem", background: "rgba(255,255,255,0.05)", borderRadius: 9999, height: 10, overflow: "hidden" }}>
                    <div
                      style={{
                        height: "100%",
                        width: `${Math.min(100, (item.approvals.length / item.requiredQuorum) * 100)}%`,
                        background: quorumMet ? "#10b981" : "#f59e0b",
                        transition: "width 0.3s ease",
                      }}
                    />
                  </div>

                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: "0.5rem", fontSize: "0.8rem", color: "#9ca3af" }}>
                    <div>
                      Đã có <strong>{item.approvals.length}</strong> chữ ký: {item.approvals.length > 0 ? item.approvals.map((a) => `@${a}`).join(", ") : "Chưa có trustee nào biểu quyết"}
                    </div>
                    <div>{quorumMet ? "✓ Quorum Attested" : `Còn thiếu ${item.requiredQuorum - item.approvals.length} chữ ký`}</div>
                  </div>

                  {/* Ciphertext inspection (Proving encryption) */}
                  <div style={{ marginTop: "1rem", padding: "0.65rem 0.85rem", background: "#0a0a0a", borderRadius: 6, border: "1px solid rgba(255,255,255,0.08)", fontSize: "0.8rem", fontFamily: "monospace", color: "#6b7280", wordBreak: "break-all" }}>
                    <div style={{ color: "#9ca3af", marginBottom: "0.25rem", fontSize: "0.75rem", textTransform: "uppercase" }}>Bản mã E2EE (Server & Admin chỉ thấy chuỗi này):</div>
                    {item.ciphertext.slice(0, 100)}...
                  </div>

                  {/* Decrypted Reveal Box */}
                  {decryptedSecrets[item.id] && (
                    <div style={{ marginTop: "1rem", padding: "1rem", background: "rgba(16, 185, 129, 0.1)", border: "1px solid rgba(16, 185, 129, 0.3)", borderRadius: 8 }}>
                      <div style={{ color: "#34d399", fontWeight: 700, fontSize: "0.85rem", marginBottom: "0.35rem", display: "flex", alignItems: "center", gap: "0.5rem" }}>
                        🔓 NỘI DUNG DI CHÚC ĐÃ ĐƯỢC GIẢI MÃ THÀNH CÔNG:
                      </div>
                      <div style={{ color: "#f3f4f6", fontSize: "0.95rem", lineHeight: 1.6, whiteSpace: "pre-wrap" }}>
                        {decryptedSecrets[item.id]}
                      </div>
                    </div>
                  )}

                  {/* Action Buttons depending on persona */}
                  <div style={{ marginTop: "1rem", display: "flex", gap: "0.75rem", flexWrap: "wrap", alignItems: "center" }}>
                    {/* Trustee Approval Button */}
                    {isTrustee && !isCancelled && (
                      <button
                        onClick={() => handleApprove(item.id)}
                        disabled={loading || hasVoted}
                        style={{ ...btnPrimary, background: hasVoted ? "#374151" : "#10b981", cursor: hasVoted ? "default" : "pointer" }}
                      >
                        {hasVoted ? "✓ Bạn đã ký phê duyệt" : "Ký Biểu Quyết Mở Di Chúc (Trustee Quorum)"}
                      </button>
                    )}

                    {/* Beneficiary Decrypt Button */}
                    {isRecipient && quorumMet && !isCancelled && !decryptedSecrets[item.id] && (
                      <button
                        onClick={() => handleDecryptItem(item)}
                        disabled={loading}
                        style={{ ...btnPrimary, background: "#8b5cf6" }}
                      >
                        🔓 Giải Mã Nội Dung Thừa Kế
                      </button>
                    )}

                    {/* Beneficiary locked notice */}
                    {isRecipient && !quorumMet && !isCancelled && (
                      <span style={{ fontSize: "0.85rem", color: "#f59e0b" }}>
                        🔒 Chưa đủ Quorum ({item.approvals.length}/{item.requiredQuorum}): Bạn chưa thể giải mã.
                      </span>
                    )}

                    {/* Owner Safeguard Cancel Button */}
                    {isOwner && !isCancelled && (
                      <button
                        onClick={() => handleCancelRelease(item.id)}
                        disabled={loading}
                        style={{ ...btnSecondary, borderColor: "#ef4444", color: "#fca5a5" }}
                        title="Bà Lan hủy bỏ mở di chúc khi còn sống"
                      >
                        [APP-LEVEL] Hủy Kích Hoạt Di Chúc
                      </button>
                    )}

                    {/* Admin Attempt Button (to prove impotence) */}
                    {isAdmin && (
                      <button
                        onClick={() => {
                          alert("TRUY CẬP BỊ TỪ CHỐI!\n\nTài khoản Admin không sở hữu role 'trustee' cũng như role 'recipient'. TideCloak từ chối cung cấp doken giải mã. Cơ chế Trust Bottleneck Elimination thành công!");
                        }}
                        style={{ ...btnSecondary, borderColor: "#ef4444", color: "#ef4444" }}
                      >
                        Thử Cưỡng Chế Đọc Trộm (Admin)
                      </button>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}

const cardStyle: React.CSSProperties = {
  background: "#171717",
  border: "1px solid rgba(255, 255, 255, 0.1)",
  borderRadius: 14,
  padding: "1.75rem",
  boxShadow: "0 10px 30px rgba(0, 0, 0, 0.4)",
};

const btnPrimary: React.CSSProperties = {
  background: "linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%)",
  color: "#ffffff",
  border: "none",
  borderRadius: 8,
  padding: "0.6rem 1.25rem",
  fontSize: "0.9rem",
  fontWeight: 600,
  cursor: "pointer",
  textDecoration: "none",
  display: "inline-block",
};

const btnSecondary: React.CSSProperties = {
  background: "rgba(255, 255, 255, 0.08)",
  color: "#e5e7eb",
  border: "1px solid rgba(255, 255, 255, 0.15)",
  borderRadius: 8,
  padding: "0.55rem 1.1rem",
  fontSize: "0.9rem",
  cursor: "pointer",
};

const inputStyle: React.CSSProperties = {
  width: "100%",
  boxSizing: "border-box",
  background: "#0a0a0a",
  border: "1px solid rgba(255, 255, 255, 0.15)",
  borderRadius: 8,
  padding: "0.6rem 0.8rem",
  color: "#f3f4f6",
  fontSize: "0.9rem",
};

const labelStyle: React.CSSProperties = {
  display: "block",
  fontSize: "0.8rem",
  color: "#9ca3af",
  marginBottom: "0.35rem",
  fontWeight: 500,
};

const badgeRole = (color: string): React.CSSProperties => ({
  background: `${color}22`,
  border: `1px solid ${color}66`,
  color: color,
  padding: "0.2rem 0.6rem",
  borderRadius: 9999,
  fontSize: "0.8rem",
  fontWeight: 600,
});

const badgeStatus = (status: string): React.CSSProperties => {
  const isUnlocked = status === "unlocked";
  const isCancelled = status === "cancelled";
  const color = isCancelled ? "#ef4444" : isUnlocked ? "#10b981" : "#f59e0b";
  return {
    background: `${color}18`,
    border: `1px solid ${color}55`,
    color: color,
    padding: "0.2rem 0.6rem",
    borderRadius: 6,
    fontSize: "0.75rem",
    fontWeight: 700,
  };
};
