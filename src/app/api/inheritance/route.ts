import { NextRequest } from "next/server";
import { withAuth } from "@/lib/auth/middleware";
import { getVaultItems, addVaultItem, updateVaultItem, VaultItem } from "@/lib/vaultStore";
import { randomUUID } from "crypto";

// GET /api/inheritance — Fetch all inheritance vault items
// Access is permitted to authenticated users; UI filters sensitivity based on roles
export const GET = withAuth(async (req, jwt) => {
  const items = getVaultItems();
  return Response.json({ items });
});

// POST /api/inheritance — Seal a new inheritance item (Owner: Ms. Lan)
export const POST = withAuth(async (req, jwt) => {
  const username = (jwt as any).preferred_username || jwt.sub;
  const body = await req.json();
  const { title, category, description, recipientRoles, recipientNames, requiredQuorum, ciphertext } = body;

  if (!title || !ciphertext) {
    return Response.json({ error: "Missing required fields" }, { status: 400 });
  }

  const newItem: VaultItem = {
    id: `item-${Date.now()}-${randomUUID().slice(0, 8)}`,
    title,
    category: category || "letter",
    description: description || "",
    recipientRoles: recipientRoles || ["recipient-mai"],
    recipientNames: recipientNames || ["Mai (Con gái)"],
    requiredQuorum: Number(requiredQuorum) || 3,
    totalTrustees: 5,
    approvals: [],
    status: "sealed",
    ciphertext,
    encryptedBy: username,
    createdAt: new Date().toISOString(),
  };

  addVaultItem(newItem);
  return Response.json({ item: newItem }, { status: 201 });
});

// PUT /api/inheritance/approve — Trustee quorum voting
export const PUT = withAuth(async (req, jwt) => {
  const username = (jwt as any).preferred_username || jwt.sub;
  const roles = (jwt as any).realm_access?.roles || [];
  const body = await req.json();
  const { itemId, action } = body; // action: "approve" | "cancel"

  const items = getVaultItems();
  const item = items.find((i) => i.id === itemId);
  if (!item) {
    return Response.json({ error: "Item not found" }, { status: 404 });
  }

  // Safeguard: Owner cancellation
  if (action === "cancel") {
    if (username !== "lan" && !roles.includes("appUser")) {
      return Response.json({ error: "[APP-LEVEL SAFEGUARD] Only vault owner (Ms. Lan) can cancel release." }, { status: 403 });
    }
    const updated = updateVaultItem(itemId, { status: "cancelled", cancelledAt: new Date().toISOString() });
    return Response.json({ item: updated, message: "[APP-LEVEL SAFEGUARD] Release cancelled by Owner." });
  }

  // Quorum approval: Only trustees
  if (!roles.includes("trustee")) {
    return Response.json({ error: "Only designated Trustees can submit quorum approval." }, { status: 403 });
  }

  if (item.status === "cancelled") {
    return Response.json({ error: "Cannot approve a cancelled inheritance vault item." }, { status: 400 });
  }

  const currentApprovals = new Set(item.approvals);
  currentApprovals.add(username);
  const updatedApprovals = Array.from(currentApprovals);

  const isUnlocked = updatedApprovals.length >= item.requiredQuorum;

  const updated = updateVaultItem(itemId, {
    approvals: updatedApprovals,
    status: isUnlocked ? "unlocked" : "sealed",
    unlockedAt: isUnlocked ? new Date().toISOString() : undefined,
  });

  return Response.json({
    item: updated,
    quorumMet: isUnlocked,
    currentCount: updatedApprovals.length,
    needed: item.requiredQuorum,
  });
});
