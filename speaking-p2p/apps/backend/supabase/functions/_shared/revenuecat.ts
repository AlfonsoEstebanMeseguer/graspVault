// RevenueCat webhook -> entitlements status. Pure mapping, unit-tested.
export type RcEvent = {
  id: string;
  type: string;
  app_user_id: string;
  expiration_at_ms?: number | null;
  event_timestamp_ms: number;
};

export type Entitlement = { status: "active" | "grace" | "billing_issue" | "cancelled" | "expired"; periodEnd: Date | null };

/// null = event we do not act on (TEST, TRANSFER without user, etc.).
export function mapRcEvent(e: RcEvent): Entitlement | null {
  const end = e.expiration_at_ms ? new Date(e.expiration_at_ms) : null;
  switch (e.type) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "UNCANCELLATION":
    case "PRODUCT_CHANGE":
    case "SUBSCRIPTION_EXTENDED":
      return { status: "active", periodEnd: end };
    case "CANCELLATION": // auto-renew off: still paid until the end of the period
      return { status: "cancelled", periodEnd: end };
    case "BILLING_ISSUE":
      return { status: "billing_issue", periodEnd: end };
    case "EXPIRATION":
      return { status: "expired", periodEnd: end ?? new Date(e.event_timestamp_ms) };
    default:
      return null;
  }
}
