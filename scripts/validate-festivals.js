#!/usr/bin/env node
/**
 * Validates festivals.json against the JSON schema.
 * 
 * Usage: node scripts/validate-festivals.js
 * 
 * Requires: npm install ajv ajv-formats
 */

const Ajv = require('ajv');
const addFormats = require('ajv-formats');
const fs = require('fs');
const path = require('path');

// Paths relative to repo root
const schemaPath = path.join(__dirname, '..', 'docs', 'api', 'festival-registry-schema.json');
const festivalsPath = path.join(__dirname, '..', 'data', 'festivals.json');

// Load files
let schema, festivals;
try {
  schema = JSON.parse(fs.readFileSync(schemaPath, 'utf8'));
  console.log('✓ Loaded schema from', schemaPath);
} catch (e) {
  console.error('✗ Failed to load schema:', e.message);
  process.exit(1);
}

try {
  festivals = JSON.parse(fs.readFileSync(festivalsPath, 'utf8'));
  console.log('✓ Loaded festivals.json from', festivalsPath);
} catch (e) {
  console.error('✗ Failed to load festivals.json:', e.message);
  process.exit(1);
}

// Validate
const ajv = new Ajv({ allErrors: true, strict: false });
addFormats(ajv);

const validate = ajv.compile(schema);
const valid = validate(festivals);

if (valid) {
  console.log('✓ festivals.json is valid!');
  console.log(`  - ${festivals.festivals.length} festival(s) defined`);
  console.log(`  - Default festival: ${festivals.default_festival_id}`);
  console.log(`  - Version: ${festivals.version}`);
  process.exit(0);
} else {
  console.error('✗ festivals.json validation failed:');
  validate.errors.forEach((err, i) => {
    console.error(`  ${i + 1}. ${err.instancePath || '/'}: ${err.message}`);
    if (err.params) {
      console.error(`     Params: ${JSON.stringify(err.params)}`);
    }
  });
  process.exit(1);
}
