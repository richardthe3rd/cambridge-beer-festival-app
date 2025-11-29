# Cambridge Beer Festival Data API

This directory contains JSON schemas and documentation for the Cambridge Beer Festival data API.

## Contents

| File | Description |
|------|-------------|
| [beer-list-schema.json](beer-list-schema.json) | JSON Schema for beverage data (beer, cider, mead, etc.) |
| [festival-registry-schema.json](festival-registry-schema.json) | JSON Schema for festival configuration (`web/data/festivals.json`) |
| [data-api-reference.md](data-api-reference.md) | Complete API reference documentation |

## CI Validation

The `festivals.json` configuration file is automatically validated against the schema during CI builds. This ensures festival configuration changes are valid before deployment.

```bash
# Run validation locally
cd scripts
npm install
node validate-festivals.js
```

## API Overview

The Cambridge Beer Festival app fetches beverage data from a public API:

- **Base URL:** `https://data.cambridgebeerfestival.com`
- **Format:** JSON
- **Authentication:** None required (public API)

### URL Pattern

```
https://data.cambridgebeerfestival.com/{festival_id}/{beverage_type}.json
```

### Examples

```bash
# Beer data for CBF 2025
curl https://data.cambridgebeerfestival.com/cbf2025/beer.json

# Cider data for CBF 2025
curl https://data.cambridgebeerfestival.com/cbf2025/cider.json

# Winter festival beer data
curl https://data.cambridgebeerfestival.com/cbfw2025/beer.json
```

## Schemas

### Beer List Schema (`beer-list-schema.json`)

Validates the structure of beverage data responses. The schema defines:

- **Root object** with `timestamp` and `producers` array
- **Producer** objects (breweries, cideries, etc.) with `name`, `location`, `products`
- **Product** objects (individual beverages) with `name`, `abv`, `category`, `dispense`, etc.

#### Key Fields

| Field | Type | Description |
|-------|------|-------------|
| `producers[].name` | string | Brewery/producer name |
| `producers[].location` | string | Geographic location |
| `producers[].products[].name` | string | Beverage name |
| `producers[].products[].abv` | string/number | Alcohol by volume |
| `producers[].products[].category` | string | "beer", "cider", "mead", etc. |
| `producers[].products[].dispense` | string | "cask", "keg", "bottle", etc. |
| `producers[].products[].allergens` | object | Allergen flags |

### Festival Registry Schema (`festival-registry-schema.json`)

Validates festival configuration data. The schema defines:

- **Registry** with `version`, `last_updated`, and `festivals` array
- **Festival** objects with `id`, `name`, `dates`, `location`, `metadata`, and `data`
- **Data** configuration with `base_url` and `available_types`

This schema can be used in CI to validate changes to festival configuration.

## Using Schemas for Validation

### With Node.js (ajv)

```javascript
const Ajv = require('ajv');
const addFormats = require('ajv-formats');
const schema = require('./beer-list-schema.json');

const ajv = new Ajv();
addFormats(ajv);
const validate = ajv.compile(schema);

const data = await fetch('https://data.cambridgebeerfestival.com/cbf2025/beer.json')
  .then(r => r.json());

if (validate(data)) {
  console.log('Valid!');
} else {
  console.log('Errors:', validate.errors);
}
```

### With Python (jsonschema)

```python
import json
import jsonschema
import requests

with open('beer-list-schema.json') as f:
    schema = json.load(f)

data = requests.get('https://data.cambridgebeerfestival.com/cbf2025/beer.json').json()

jsonschema.validate(data, schema)  # Raises on error
print('Valid!')
```

### In CI/CD

```yaml
# Example GitHub Actions workflow
- name: Validate festival config
  run: |
    npm install ajv ajv-formats
    node scripts/validate-schema.js
```

## Beverage Categories

| Category | Description | Typical Dispense |
|----------|-------------|------------------|
| `beer` | Domestic ales and lagers | cask, keg |
| `foreign beer` | International beers | bottle, keg |
| `cider` | Apple ciders | cider tub |
| `perry` | Pear ciders | cider tub |
| `mead` | Honey wines | bottle, mead polypin |
| `wine` | Grape wines | bottle |
| `low-no` | Low/no alcohol beverages | various |

## Allergen Information

The `allergens` object in product data uses truthy values:

```json
{
  "allergens": {
    "gluten": 1,
    "sulphites": 1
  }
}
```

Common allergens tracked:
- `gluten` - Contains gluten
- `sulphites` - Contains sulphites

## Related Resources

- [BeerFestApp](https://github.com/richardthe3rd/BeerFestApp) - Original Android app with full API docs
- [Cambridge Beer Festival](https://www.cambridgebeerfestival.com/) - Official festival website

## Schema Versioning

Schemas follow the JSON Schema draft-07 specification. Breaking changes will result in new schema files with updated `$id` values.
