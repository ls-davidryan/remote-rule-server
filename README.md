# remote-rule-server

A minimal Go HTTP server that implements a remote rule endpoint. It inspects an incoming sale and automatically adds a line item if a target product is not already present.

## Configuration

Two constants in `main.go` control the behavior:

| Constant | Value | Description                                                                |
|---|---|----------------------------------------------------------------------------|
| `targetProductID` | `203c5313-...` | Product to check for / add if missing                                      |
| `targetTaxID` | `067d4bf7-...` | Tax ID applied to the added line item (valid IDs found at `api/2.0/taxes`) |

The added line item's `unit_price` and `quantity` are also hardcoded in the `AddLineItemAction` literal inside `main.go`.

## Endpoint

`POST /rule` — listens on `:8080`

**Request body:**
```json
{
  "sale": {
    "line_items": [
      { "product_id": "..." }
    ]
  }
}
```

**Response:** `application/json`

If `targetProductID` is **not** in the sale's line items, the response includes an `add_line_item` action:
```json
{
  "actions": [
    {
      "type": "add_line_item",
      "product_id": "203c5313-...",
      "quantity": "1",
      "unit_price": "3.75",
      "tax_id": "067d4bf7-..."
    }
  ]
}
```

If the product is already present, `actions` is an empty array.

## Modifying the response

Actions are defined by the `Action` interface in `types.go`. To add a new action type:

1. Define a new struct implementing `Action` (provide `actionType()` and a custom `MarshalJSON` that injects the `"type"` field, following the pattern in `AddLineItemAction`).
2. Append instances of that struct to `response.Actions` in the handler in `main.go`.

## Running

Before running, copy `.env.example` to `.env` and set your subdomain:

```bash
cp .env.example .env
```

```ini
SUBDOMAIN=your-subdomain-here
```

`make start` will then expose the rule endpoint at `https://your-subdomain-here.loca.lt/rule`.

> **Note:** Subdomains aren't reserved — if yours is already in use, choose a different value in `.env`.
