# Cambridge Beer Festival Data API Reference

**Last Updated:** 2025-11-29  
**API Base URL:** https://data.cambeerfestival.app  
**Purpose:** Documentation for multi-festival and multi-beverage-type support

---

## Overview

The Cambridge Beer Festival Data API provides structured beverage and producer data for multiple festivals in JSON format. This API enables the app to support multiple festivals and multiple beverage types.

---

## Available Festivals

### Current & Recent Festivals

| Festival Code | Full Name | Years Available | Notes |
|---------------|-----------|-----------------|-------|
| **cbf** | Cambridge Beer Festival | cbf2023, cbf2024, cbf2025 | Main annual festival |
| **cbfw** | Cambridge Beer Festival Winter | cbfw2018, cbfw2019, cbfw2025 | Winter variant |

---

## URL Structure

### Pattern
```
https://data.cambeerfestival.app/{festival_code}/{beverage_type}.json
```

### Examples
```
https://data.cambeerfestival.app/cbf2025/beer.json
https://data.cambeerfestival.app/cbf2025/cider.json
https://data.cambeerfestival.app/cbfw2025/beer.json
```

---

## Available Beverage Types

### CBF 2025 (Main Festival) - Full Range

| Beverage Type | Filename | Description |
|---------------|----------|-------------|
| **Beer** | `beer.json` | Domestic beer offerings |
| **International Beer** | `international-beer.json` | Foreign/imported beers |
| **Cider** | `cider.json` | Apple ciders |
| **Mead** | `mead.json` | Honey wines |
| **Perry** | `perry.json` | Pear ciders |
| **Wine** | `wine.json` | Wines |
| **Apple Juice** | `apple-juice.json` | Non-alcoholic apple juice |
| **Low/No Alcohol** | `low-no.json` | Low or no-alcohol beverages |

### CBFW 2025 (Winter Festival) - Limited Range

| Beverage Type | Filename | Description |
|---------------|----------|-------------|
| **Beer** | `beer.json` | Winter beer offerings |
| **Low/No Alcohol** | `low-no.json` | Low or no-alcohol beverages |

**Note:** Different festivals may offer different beverage types. Always check the festival configuration before attempting to fetch specific beverage types.

---

## JSON Data Structure

### Overview

All beverage types follow the same consistent JSON structure with a two-level hierarchy:
1. **Producers** (breweries, cideries, meaderies, wineries)
2. **Products** (individual beverages)

### Root Object

```json
{
  "timestamp": "2025-05-24T00:01:00Z",
  "producers": [ /* array of producer objects */ ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | string (ISO 8601) | Last update time for this dataset |
| `producers` | array | Array of producer objects (see below) |

---

## Producer Object

Each producer (brewery, cidery, etc.) contains:

```json
{
  "name": "All Day",
  "location": "Reepham, Norfolk",
  "id": "632047e5b2a712a7707f6b28ac722b1e706f1589",
  "year_founded": 2014,
  "notes": "Reepham, Norfolk est. 2014",
  "products": [ /* array of product objects */ ]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Producer name |
| `location` | string | Yes | Geographic location |
| `id` | string | Yes | Unique identifier (SHA-1 hash) |
| `year_founded` | integer | No | Year the producer was established |
| `notes` | string | No | Additional information about the producer |
| `products` | array | Yes | Array of product objects (beverages) |

---

## Product Object

Each product (individual beverage) contains:

```json
{
  "name": "Let's Cask - Strong Golden Ale",
  "id": "3e908babc017695281dc1f9887be46c6ffb9e0a3",
  "category": "beer",
  "style": "Golden Ale",
  "dispense": "cask",
  "abv": "5.4",
  "notes": "Heritage Range - Crisp Heritage malts and a massive whack of fresh Goldings...",
  "status_text": "Plenty left",
  "bar": "Arctic",
  "allergens": {"gluten": 1}
}
```

### Core Fields

| Field | Type | Required | Description | Example Values |
|-------|------|----------|-------------|----------------|
| `name` | string | Yes | Product name | "Let's Cask - Strong Golden Ale" |
| `id` | string | Yes | Unique identifier (SHA-1 hash) | "3e908babc017..." |
| `category` | string | Yes | Beverage category | "beer", "cider", "mead", "foreign beer" |
| `abv` | string/number | Yes | Alcohol by volume (%) | "5.4", "8.4", "14.5" |
| `dispense` | string | Yes | Serving method | See dispense methods below |
| `style` | string | No | Style/variety | "Golden Ale", "IPA", "Dry" |
| `notes` | string | No | Flavor description | "Crisp Heritage malts..." |
| `status_text` | string | No | Availability status | "Plenty left", "Arrived" |
| `bar` | string/boolean | No | Venue/location | "Arctic", "Main Bar", true/false |
| `allergens` | object | No | Allergen flags | `{"gluten": 1, "sulphites": 1}` |

### Dispense Methods

Common values for the `dispense` field:

| Value | Description | Common For |
|-------|-------------|------------|
| `cask` | Traditional cask ale | Beer |
| `keg` | Standard keg | Beer |
| `keykeg` | KeyKeg (pressurized) | Beer, low-no |
| `bottle` | Bottled | International beer, mead, wine |
| `cider tub` | Cider serving vessel | Cider, perry |
| `mead polypin` | Mead container | Mead |

### Allergens Object

The `allergens` object uses numeric/boolean flags (1/true = present):

```json
"allergens": {
  "gluten": 1,
  "sulphites": 1
}
```

Common allergens:
- `gluten`
- `sulphites`

**Note:** An empty object `{}` means no allergens listed.

---

## Category-Specific Variations

### Beer vs International Beer

| Feature | beer.json | international-beer.json |
|---------|-----------|-------------------------|
| **Category value** | "beer" | "foreign beer" |
| **Location tracking** | UK-focused | Global (15+ countries) |
| **Status field** | Less common | "Arrived" tracking |
| **Dispense** | Cask-heavy | Bottle/keg-heavy |

### Cider/Perry

- `style` field often null
- `dispense` typically "cider tub"
- Focus on sweetness/dryness in notes

### Mead

- `dispense` typically "bottle" or "mead polypin"
- Higher ABV range (10-17%)
- Common allergen: sulphites

### Wine

- Traditional wine categories
- Bottle dispense
- Wine-specific styling

### Low/No Alcohol

- ABV typically < 0.5%
- Various dispense methods
- Mixed beverage types (beer-style, cider-style)

---

## Example API Calls

### Fetch Beer Data for CBF 2025

```bash
curl https://data.cambeerfestival.app/cbf2025/beer.json
```

### Fetch Cider Data for CBF 2025

```bash
curl https://data.cambeerfestival.app/cbf2025/cider.json
```

### Fetch Winter Festival Beer Data

```bash
curl https://data.cambeerfestival.app/cbfw2025/beer.json
```

---

## Dart Model Mapping

This Flutter app maps the API data to Dart models as follows:

### Producer → `Producer` class

```dart
Producer.fromJson(json) → {
  id: json['id'],
  name: json['name'],
  location: json['location'],
  yearFounded: json['year_founded'],  // Handles int or String
  notes: json['notes'],
  products: json['products'].map(Product.fromJson),
}
```

### Product → `Product` class

```dart
Product.fromJson(json) → {
  id: json['id'],
  name: json['name'],
  category: json['category'],
  style: json['style'],
  dispense: json['dispense'],
  abv: parseDouble(json['abv']),  // Handles String or number
  notes: json['notes'],
  statusText: json['status_text'],
  bar: json['bar'],  // Handles String, int, or boolean
  allergens: parseAllergens(json['allergens']),  // Handles int, bool, or num
}
```

### Key Parsing Considerations

1. **ABV** can be `String`, `int`, or `double`
2. **Allergens** values can be `int`, `bool`, or `num`
3. **Year founded** can be `int` or `String`
4. **Bar** can be `String`, `int`, or `boolean`
5. Handle null values gracefully with `?.` and `??`

---

## Error Handling

### HTTP Errors

| Status Code | Meaning | Action |
|-------------|---------|--------|
| 200 | Success | Parse response |
| 404 | Not found | Festival or beverage type not available |
| 5xx | Server error | Retry with backoff |

### Data Validation

- Check JSON structure before parsing
- Validate required fields present
- Handle malformed data gracefully

---

## Data Freshness

**Update Schedule:** Data files are typically updated:
- Before festival start (finalized lineup)
- During festival (status_text changes for "sold out", etc.)
- May be updated multiple times during festival

**Caching Strategy:**
- Check timestamp field for data freshness
- Re-fetch if timestamp changed
- Consider TTL of 1-4 hours during festival
- Longer TTL (24h) outside festival dates

---

## API Limitations

1. **No API Key Required** - Public access
2. **No Rate Limiting Observed** - Be respectful with requests
3. **No Versioning** - API structure may change
4. **No Pagination** - Full datasets in single response
5. **No Filtering** - Must fetch full file and filter client-side
6. **No Real-time Updates** - Static JSON files, not live API

---

## Sample JSON Responses

### Beer (Domestic)

```json
{
  "timestamp": "2025-05-24T00:01:00Z",
  "producers": [
    {
      "name": "All Day",
      "location": "Reepham, Norfolk",
      "id": "632047e5b2a712a7707f6b28ac722b1e706f1589",
      "year_founded": 2014,
      "notes": "Reepham, Norfolk est. 2014",
      "products": [
        {
          "name": "Let's Cask - Strong Golden Ale",
          "style": "Golden Ale",
          "dispense": "cask",
          "abv": "5.4",
          "status_text": "Plenty left",
          "allergens": {"gluten": 1},
          "id": "3e908babc017695281dc1f9887be46c6ffb9e0a3",
          "notes": "Heritage Range - Crisp Heritage malts...",
          "category": "beer",
          "bar": "Arctic"
        }
      ]
    }
  ]
}
```

### Cider

```json
{
  "timestamp": "2025-05-24T00:01:00Z",
  "producers": [
    {
      "name": "Ross on Wye Cider & Perry Co.",
      "location": "Ross on Wye, Herefordshire",
      "id": "abc123...",
      "products": [
        {
          "name": "Strong Kentish Cider",
          "abv": "8.4",
          "category": "cider",
          "dispense": "cider tub",
          "style": null,
          "allergens": {},
          "id": "def456...",
          "notes": "Made from Kentish cider apples",
          "bar": "Cider Bar"
        }
      ]
    }
  ]
}
```

---

## Related Documentation

- [beer-list-schema.json](beer-list-schema.json) - JSON Schema for API responses
- [festival-registry-schema.json](festival-registry-schema.json) - JSON Schema for festival config
- [BeerFestApp](https://github.com/richardthe3rd/BeerFestApp) - Original Android app

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-11-29 | Initial documentation for Flutter app |
