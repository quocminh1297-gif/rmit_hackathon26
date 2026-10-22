"use client";

import { useTideCloak } from "@tidecloak/nextjs";
import { useState } from "react";

export interface Persona {
  id: string;
  name: string;
  roleDescription: string;
  badge: string;
  badgeColor: string;
  loginHint: string;
}

export const PERSONAS: Persona[] = [
  {
    id: "lan",
    name: "Bà Lan",
    roleDescription: "Owner / Vault Creator",
    badge: "Chủ sở hữu",
    badgeColor: "#8b5cf6",
    loginHint: "lan",
  },
  {
    id: "admin",
    name: "System Admin",
    roleDescription: "Platform Infrastructure Admin",
    badge: "Admin bất lực (Bị cô lập)",
    badgeColor: "#ef4444",
    loginHint: "admin",
  },
  {
    id: "mai",
    name: "Mai (Con gái)",
    roleDescription: "Trustee 1/5 & Recipient (Kỷ niệm + Tài sản)",
    badge: "Trustee & Con gái",
    badgeColor: "#ec4899",
    loginHint: "mai",
  },
  {
    id: "minh",
    name: "Minh (Con trai)",
    roleDescription: "Trustee 2/5 & Recipient (Kỷ niệm + Tài sản)",
    badge: "Trustee & Con trai",
    badgeColor: "#3b82f6",
    loginHint: "minh",
  },
  {
    id: "hanh",
    name: "Hạnh (Bạn thân)",
    roleDescription: "Trustee 3/5 & Recipient (Tâm thư)",
    badge: "Trustee & Bạn thân",
    badgeColor: "#10b981",
    loginHint: "hanh",
  },
  {
    id: "tuan",
    name: "Tuấn (Luật sư)",
    roleDescription: "Trustee 4/5 (Đại diện pháp lý)",
    badge: "Trustee & Luật sư",
    badgeColor: "#f59e0b",
    loginHint: "tuan",
  },
  {
    id: "thu",
    name: "Thu (Người thi hành)",
    roleDescription: "Trustee 5/5 (Người thi hành di chúc)",
    badge: "Trustee & Thi hành",
    badgeColor: "#06b6d4",
    loginHint: "thu",
  },
];

export function PersonaSwitcher() {
  const { authenticated, getValueFromIdToken, logout, login } = useTideCloak();
  const [switching, setSwitching] = useState(false);

  const currentUsername = authenticated ? getValueFromIdToken("preferred_username") : null;
  const currentPersona = PERSONAS.find((p) => p.id === currentUsername);

  const handleSwitch = async (persona: Persona) => {
    setSwitching(true);
    try {
      if (authenticated) {
        // Log out first to clear previous session
        await logout();
      }
      // Redirect to TideCloak login with loginHint preset
      await login({ loginHint: persona.loginHint });
    } catch (err) {
      console.error("Persona switch error:", err);
      setSwitching(false);
    }
  };

  return (
    <div style={containerStyle}>
      <div style={headerStyle}>
        <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
          <span style={dotStyle(authenticated)} />
          <strong style={{ fontSize: "0.85rem", textTransform: "uppercase", letterSpacing: "0.05em", color: "#9ca3af" }}>
            Hackathon Persona Switcher
          </strong>
        </div>
        {authenticated && currentPersona && (
          <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
            <span style={{ fontSize: "0.85rem", color: "#d1d5db" }}>Đang đăng nhập:</span>
            <span style={badgeStyle(currentPersona.badgeColor)}>{currentPersona.name} ({currentPersona.badge})</span>
          </div>
        )}
      </div>

      <div style={personaGridStyle}>
        {PERSONAS.map((p) => {
          const isCurrent = currentUsername === p.id;
          return (
            <button
              key={p.id}
              onClick={() => handleSwitch(p)}
              disabled={switching || isCurrent}
              style={personaBtnStyle(isCurrent, p.badgeColor)}
              title={`${p.name} - ${p.roleDescription}`}
            >
              <div style={{ fontWeight: 600, fontSize: "0.85rem" }}>{p.name}</div>
              <div style={{ fontSize: "0.7rem", opacity: 0.8 }}>{p.badge}</div>
              {isCurrent && <div style={{ fontSize: "0.65rem", color: "#34d399", marginTop: "2px" }}>● Đang chọn</div>}
            </button>
          );
        })}
      </div>
      {switching && <div style={{ fontSize: "0.75rem", color: "#60a5fa", marginTop: "0.25rem", textAlign: "center" }}>Đang chuyển đổi phiên OIDC thật...</div>}
    </div>
  );
}

const containerStyle: React.CSSProperties = {
  background: "rgba(23, 23, 23, 0.85)",
  backdropFilter: "blur(12px)",
  border: "1px solid rgba(255, 255, 255, 0.12)",
  borderRadius: 12,
  padding: "0.75rem 1rem",
  marginBottom: "1.5rem",
  boxShadow: "0 8px 32px rgba(0, 0, 0, 0.4)",
};

const headerStyle: React.CSSProperties = {
  display: "flex",
  justifyContent: "space-between",
  alignItems: "center",
  marginBottom: "0.6rem",
  flexWrap: "wrap",
  gap: "0.5rem",
};

const personaGridStyle: React.CSSProperties = {
  display: "grid",
  gridTemplateColumns: "repeat(auto-fit, minmax(130px, 1fr))",
  gap: "0.5rem",
};

const personaBtnStyle = (isCurrent: boolean, color: string): React.CSSProperties => ({
  background: isCurrent ? "rgba(255, 255, 255, 0.08)" : "rgba(38, 38, 38, 0.6)",
  border: isCurrent ? `2px solid ${color}` : "1px solid rgba(255, 255, 255, 0.08)",
  borderRadius: 8,
  padding: "0.5rem",
  color: "#f3f4f6",
  textAlign: "left",
  cursor: isCurrent ? "default" : "pointer",
  transition: "all 0.15s ease",
});

const badgeStyle = (color: string): React.CSSProperties => ({
  background: `${color}22`,
  border: `1px solid ${color}66`,
  color: color,
  borderRadius: 9999,
  padding: "0.15rem 0.6rem",
  fontSize: "0.75rem",
  fontWeight: 600,
});

const dotStyle = (active: boolean): React.CSSProperties => ({
  width: 8,
  height: 8,
  borderRadius: "50%",
  background: active ? "#10b981" : "#ef4444",
  display: "inline-block",
  boxShadow: active ? "0 0 8px #10b981" : "none",
});
