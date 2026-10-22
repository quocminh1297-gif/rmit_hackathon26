import { readFileSync, writeFileSync, existsSync, mkdirSync } from "fs";
import { join } from "path";

export interface VaultItem {
  id: string;
  title: string;
  category: "letter" | "asset" | "crypto";
  description: string;
  recipientRoles: string[]; // e.g. ["recipient-mai"]
  recipientNames: string[]; // e.g. ["Mai (Con gái)"]
  requiredQuorum: number;   // e.g. 3 or 4
  totalTrustees: number;   // 5
  approvals: string[];     // list of trustee usernames who approved (e.g. ["mai", "minh"])
  status: "sealed" | "unlocked" | "cancelled";
  ciphertext: string;
  encryptedBy: string;     // "lan"
  createdAt: string;
  unlockedAt?: string;
  cancelledAt?: string;
}

const DATA_DIR = join(process.cwd(), "data");
const STORE_PATH = join(DATA_DIR, "inheritance_vault.json");

function ensureStore(): void {
  if (!existsSync(DATA_DIR)) {
    mkdirSync(DATA_DIR, { recursive: true });
  }
  if (!existsSync(STORE_PATH)) {
    // Initial seeded inheritance items for Ms. Lan
    const initialItems: VaultItem[] = [
      {
        id: "item-1-letter",
        title: "Tâm thư dặn dò gửi con gái Mai",
        category: "letter",
        description: "Lời nhắn nhủ riêng tư của mẹ dành cho Mai về cuộc sống và gia đình.",
        recipientRoles: ["recipient-mai"],
        recipientNames: ["Mai (Con gái)"],
        requiredQuorum: 3,
        totalTrustees: 5,
        approvals: [],
        status: "sealed",
        ciphertext: "TIDE_CIPHERTEXT::v1::aes256gcm::8f3a9e2d1c::Y2hpZHNfYWxsb2NhdGlvbg==::4a8b1c9d",
        encryptedBy: "lan",
        createdAt: new Date().toISOString(),
      },
      {
        id: "item-2-property",
        title: "Hợp đồng & Giấy chứng nhận quyền sở hữu căn nhà",
        category: "asset",
        description: "Tài liệu phân chia quyền sở hữu nhà đất giữa Mai và Minh.",
        recipientRoles: ["recipient-mai", "recipient-minh"],
        recipientNames: ["Mai (Con gái)", "Minh (Con trai)"],
        requiredQuorum: 3,
        totalTrustees: 5,
        approvals: [],
        status: "sealed",
        ciphertext: "TIDE_CIPHERTEXT::v1::aes256gcm::7b2c5f1e8a::cHJvcGVydHlfZGVlZHNfYW5kX3dpc2hlcw==::9f0a2d3c",
        encryptedBy: "lan",
        createdAt: new Date().toISOString(),
      },
      {
        id: "item-3-seedphrase",
        title: "Khóa bảo mật ví Crypto thừa kế (Seed Phrase 24 từ)",
        category: "crypto",
        description: "Toàn bộ tài sản số dự phòng. Yêu cầu mức đồng thuận cao nhất (4/5 Trustees).",
        recipientRoles: ["recipient-mai", "recipient-minh"],
        recipientNames: ["Mai (Con gái)", "Minh (Con trai)"],
        requiredQuorum: 4,
        totalTrustees: 5,
        approvals: [],
        status: "sealed",
        ciphertext: "TIDE_CIPHERTEXT::v1::aes256gcm::3e9d8f7a6b::c2VlZF9waHJhc2VfZ3VhcmRpYW5fY3J5cHRv::1b2c3d4e",
        encryptedBy: "lan",
        createdAt: new Date().toISOString(),
      },
    ];
    writeFileSync(STORE_PATH, JSON.stringify(initialItems, null, 2));
  }
}

export function getVaultItems(): VaultItem[] {
  ensureStore();
  try {
    return JSON.parse(readFileSync(STORE_PATH, "utf-8"));
  } catch {
    return [];
  }
}

export function saveVaultItems(items: VaultItem[]): void {
  ensureStore();
  writeFileSync(STORE_PATH, JSON.stringify(items, null, 2));
}

export function addVaultItem(item: VaultItem): void {
  const items = getVaultItems();
  items.push(item);
  saveVaultItems(items);
}

export function updateVaultItem(id: string, updates: Partial<VaultItem>): VaultItem | null {
  const items = getVaultItems();
  const idx = items.findIndex((i) => i.id === id);
  if (idx === -1) return null;
  items[idx] = { ...items[idx], ...updates };
  saveVaultItems(items);
  return items[idx];
}
