import { assertEquals, assertThrows } from "https://deno.land/std@0.208.0/testing/asserts.ts";
import { TransactionSchema, BatchIngestRequest } from "../ingest-transaction/types.ts";

Deno.test("validates transaction schema - valid data", () => {
  const validTransaction = {
    event_time: "2024-01-15T10:30:00Z",
    store_id: "STORE001",
    region: "NCR",
    product_sku: "SKU123",
    quantity: 10,
    value: 1000.50,
    pos_number: "POS001",
    transaction_id: "TXN123456"
  };

  const result = TransactionSchema.safeParse(validTransaction);
  assertEquals(result.success, true);
});

Deno.test("validates transaction schema - invalid quantity", () => {
  const invalidTransaction = {
    event_time: "2024-01-15T10:30:00Z",
    store_id: "STORE001",
    region: "NCR",
    product_sku: "SKU123",
    quantity: -5, // Negative quantity
    value: 1000.50,
    pos_number: "POS001",
    transaction_id: "TXN123456"
  };

  const result = TransactionSchema.safeParse(invalidTransaction);
  assertEquals(result.success, false);
});

Deno.test("validates batch request - enforces max batch size", () => {
  const oversizedBatch = {
    transactions: new Array(1001).fill({
      event_time: "2024-01-15T10:30:00Z",
      store_id: "STORE001",
      region: "NCR",
      product_sku: "SKU123",
      quantity: 10,
      value: 1000.50,
      pos_number: "POS001",
      transaction_id: "TXN123456"
    })
  };

  const result = BatchIngestRequest.safeParse(oversizedBatch);
  assertEquals(result.success, false);
});

Deno.test("event hash generation is deterministic", async () => {
  const { eventHash } = await import("../ingest-transaction/index.ts");
  
  const data = {
    store_id: "STORE001",
    product_sku: "SKU123",
    quantity: 10,
    value: 1000.50,
    event_time: "2024-01-15T10:30:00Z"
  };

  const hash1 = eventHash(data);
  const hash2 = eventHash(data);
  
  assertEquals(hash1, hash2, "Same data should produce same hash");
});

Deno.test("peso value computation handles missing SKU", async () => {
  const { computePesoValue } = await import("../ingest-transaction/index.ts");
  
  // Mock supabase client
  const mockSupabase = {
    from: () => ({
      select: () => ({
        eq: () => ({
          single: () => Promise.resolve({ data: null, error: null })
        })
      })
    })
  };

  const result = await computePesoValue(
    mockSupabase as any,
    "UNKNOWN_SKU",
    10,
    500.00
  );
  
  assertEquals(result, 500.00, "Should return provided value when SKU not found");
});