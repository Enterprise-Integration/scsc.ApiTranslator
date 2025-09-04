# API Translator Logic App

## Overview
This Logic App provides a universal API translation service that can:
- Accept JSON or XML payloads via HTTP POST
- Transform documents using XSLT stylesheets based on trading partner configuration
- Return responses in JSON or XML format based on Accept header

## Required Headers

| Header | Description | Example |
|--------|-------------|---------|
| `Content-Type` | Format of incoming payload | `application/json`, `application/xml`, `text/xml` |
| `Accept` | Desired format for response | `application/json`, `application/xml`, `text/xml` |
| `Trading-Partner-Id` | Unique identifier for trading partner | `PARTNER001`, `ACME_CORP` |
| `Document-Type` | Type of business document | `PURCHASE_ORDER`, `INVOICE`, `SHIPMENT_NOTICE` |

## Workflow Logic

1. **Header Validation**: Validates all required headers are present
2. **Content Type Processing**: 
   - JSON → Convert to XML for processing
   - XML → Use directly
3. **Partner Configuration Lookup**: Retrieves stylesheet mapping for partner/document combination
4. **XSLT Transformation**: Applies the appropriate stylesheet to transform the document
5. **Response Formatting**: 
   - XML → Convert to JSON if Accept header requests JSON
   - XML → Return as XML if Accept header requests XML

## Partner Configuration API

The workflow expects a configuration API endpoint that returns partner/document mappings:

**Endpoint**: `GET /api/partners/{partnerId}/documents/{documentType}`

**Response Format**:
```json
{
  "tradingPartnerId": "PARTNER001",
  "documentType": "PURCHASE_ORDER", 
  "stylesheetName": "partner001_po_transform.xslt",
  "stylesheetPath": "https://yourstorageaccount.blob.core.windows.net/stylesheets/partner001_po_transform.xslt",
  "isActive": true
}
```

## Error Handling

| Status Code | Error | Description |
|-------------|-------|-------------|
| 400 | Missing Headers | One or more required headers missing |
| 400 | Unsupported Content Type | Content-Type not supported |
| 400 | Unsupported Accept Type | Accept header not supported |
| 404 | Partner Config Not Found | No configuration for partner/document combination |
| 500 | Transformation Error | XSLT transformation failed |

## Example Usage

### Request
```http
POST /api/translator
Content-Type: application/json
Accept: application/xml
Trading-Partner-Id: ACME_CORP
Document-Type: PURCHASE_ORDER

{
  "purchaseOrder": {
    "orderId": "PO-12345",
    "orderDate": "2025-09-04",
    "items": [
      {
        "sku": "ABC123",
        "quantity": 10,
        "unitPrice": 25.00
      }
    ]
  }
}
```

### Response
```http
HTTP/1.1 200 OK
Content-Type: application/xml
Trading-Partner-Id: ACME_CORP
Document-Type: PURCHASE_ORDER

<?xml version="1.0" encoding="UTF-8"?>
<PurchaseOrder>
  <Header>
    <OrderNumber>PO-12345</OrderNumber>
    <OrderDate>2025-09-04</OrderDate>
  </Header>
  <LineItems>
    <Item>
      <ProductCode>ABC123</ProductCode>
      <Qty>10</Qty>
      <Price>25.00</Price>
    </Item>
  </LineItems>
</PurchaseOrder>
```

## Setup Requirements

1. **Configuration API**: Deploy an API to manage partner/document/stylesheet mappings
2. **Stylesheet Storage**: Store XSLT files in Azure Blob Storage or similar accessible location
3. **Integration Account**: (Optional) For more advanced B2B features and schema validation

## Next Steps

1. Deploy the Logic App to Azure
2. Set up the partner configuration API
3. Create and upload XSLT stylesheets for your trading partners
4. Test with sample payloads
