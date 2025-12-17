import 'package:cambridge_beer_festival/models/models.dart';

/// Reusable test data fixtures for screenshot and widget tests

// Test Festivals
const testFestival = Festival(
  id: 'cbf2025',
  name: 'Cambridge Beer Festival 2025',
  dataBaseUrl: 'https://data.cambeerfestival.app/cbf2025',
);

// Test Producers
const producer1 = Producer(
  id: 'brewery1',
  name: 'Cambridge Brewing Company',
  location: 'Cambridge, UK',
  yearFounded: 1990,
  products: [],
);

const producer2 = Producer(
  id: 'brewery2',
  name: 'London Craft Ales',
  location: 'London, UK',
  yearFounded: 2000,
  products: [],
);

const producer3 = Producer(
  id: 'brewery3',
  name: 'Norfolk Cider Co',
  location: 'Norwich, UK',
  yearFounded: 2015,
  products: [],
);

// Test Products - Beers
const product1 = Product(
  id: 'drink1',
  name: 'Hoppy Heaven IPA',
  abv: 6.2,
  category: 'beer',
  style: 'IPA',
  dispense: 'cask',
  notes: 'A bold and hoppy IPA with citrus notes and a crisp finish.',
);

const product2 = Product(
  id: 'drink2',
  name: 'Golden Crown IPA',
  abv: 5.8,
  category: 'beer',
  style: 'IPA',
  dispense: 'keg',
  notes: 'Golden ale with tropical fruit flavors.',
);

const product3 = Product(
  id: 'drink3',
  name: 'Dark Porter',
  abv: 4.5,
  category: 'beer',
  style: 'Porter',
  dispense: 'cask',
  notes: 'Rich and smooth porter with chocolate notes.',
);

const product4 = Product(
  id: 'drink4',
  name: 'Session Pale Ale',
  abv: 3.8,
  category: 'beer',
  style: 'Pale Ale',
  dispense: 'cask',
  notes: 'Light and refreshing pale ale.',
);

// Test Products - Ciders
const product5 = Product(
  id: 'drink5',
  name: 'Traditional Dry Cider',
  abv: 6.0,
  category: 'cider',
  style: 'Traditional',
  dispense: 'cask',
  notes: 'Classic dry cider made from Norfolk apples.',
);

const product6 = Product(
  id: 'drink6',
  name: 'Sweet Apple Cider',
  abv: 5.5,
  category: 'cider',
  style: 'Sweet',
  dispense: 'keg',
  notes: 'Sweet and fruity cider.',
);

// Test Drinks (combining products with producers)
final testDrink1 = Drink(
  product: product1,
  producer: producer1,
  festivalId: 'cbf2025',
);

final testDrink2 = Drink(
  product: product2,
  producer: producer2,
  festivalId: 'cbf2025',
);

final testDrink3 = Drink(
  product: product3,
  producer: producer1,
  festivalId: 'cbf2025',
);

final testDrink4 = Drink(
  product: product4,
  producer: producer2,
  festivalId: 'cbf2025',
);

final testDrink5 = Drink(
  product: product5,
  producer: producer3,
  festivalId: 'cbf2025',
);

final testDrink6 = Drink(
  product: product6,
  producer: producer3,
  festivalId: 'cbf2025',
);

// List of all test drinks
final allTestDrinks = [
  testDrink1,
  testDrink2,
  testDrink3,
  testDrink4,
  testDrink5,
  testDrink6,
];

// Filtered lists
final testBeers = [testDrink1, testDrink2, testDrink3, testDrink4];
final testCiders = [testDrink5, testDrink6];
final testIPAs = [testDrink1, testDrink2];
