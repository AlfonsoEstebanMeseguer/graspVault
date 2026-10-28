// RevenueCat webhook -> entitlements status. Pure mapping, unit-tested.
export type RcEvent = {
  id: string;
  type: string;
  app_user_id: string;
  expiration_at_ms?: number | null;
  event_timestamp_ms: number;
  entitlement_ids?: string[] | null;
};

/// plan null = the event does not say (keep the stored one). D-037: the "pro"
/// entitlement includes everything "standard" has.
export type Entitlement = {
  status: "active" | "grace" | "billing_issue" | "cancelled" | "expired";
  periodEnd: Date | null;
  plan: "standard" | "pro" | null;
};

export function planOf(e: RcEvent): "standard" | "pro" | null {
  const ids = e.entitlement_ids;
  if (!ids?.length) return null;
  return ids.includes("pro") ? "pro" : "standard";
}

/// null = event we do not act on (TEST, TRANSFER without user, etc.).
export function mapRcEvent(e: RcEvent): Entitlement | null {
  const end = e.expiration_at_ms ? new Date(e.expiration_at_ms) : null;
  const plan = planOf(e);
  switch (e.type) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "UNCANCELLATION":
    case "PRODUCT_CHANGE":
    case "SUBSCRIPTION_EXTENDED":
      return { status: "active", periodEnd: end, plan };
    case "CANCELLATION": // auto-renew off: still paid until the end of the period
      return { status: "cancelled", periodEnd: end, plan };
    case "BILLING_ISSUE":
      return { status: "billing_issue", periodEnd: end, plan };
    case "EXPIRATION":
      return { status: "expired", periodEnd: end ?? new Date(e.event_timestamp_ms), plan };
    default:
      return null;
  }
}
