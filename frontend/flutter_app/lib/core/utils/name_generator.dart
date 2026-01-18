import 'dart:math';

/// Generates fun random display names like "Fuzzy Totodile" or "Cranky Whale"
class NameGenerator {
  static final _random = Random();

  static const _adjectives = [
    // Mood/Personality
    'Happy', 'Grumpy', 'Sleepy', 'Cranky', 'Cheerful', 'Sneaky', 'Lazy',
    'Bouncy', 'Giggly', 'Silly', 'Curious', 'Brave', 'Shy', 'Wild',
    'Calm', 'Fierce', 'Gentle', 'Jolly', 'Merry', 'Witty', 'Zany',

    // Texture/Appearance
    'Fuzzy', 'Fluffy', 'Sparkly', 'Shiny', 'Spotted', 'Striped', 'Scruffy',
    'Chubby', 'Tiny', 'Giant', 'Cosmic', 'Golden', 'Silver', 'Rainbow',

    // Speed/Movement
    'Swift', 'Speedy', 'Zippy', 'Dashing', 'Prancing', 'Dancing', 'Wobbly',

    // Temperature
    'Toasty', 'Frosty', 'Sunny', 'Breezy', 'Stormy', 'Misty',

    // Fun/Quirky
    'Ninja', 'Pirate', 'Cosmic', 'Mystic', 'Magic', 'Electric', 'Turbo',
    'Mega', 'Super', 'Ultra', 'Hyper', 'Pixel', 'Retro', 'Neon',
  ];

  static const _animals = [
    // Mammals
    'Panda', 'Otter', 'Koala', 'Fox', 'Wolf', 'Bear', 'Rabbit', 'Hedgehog',
    'Squirrel', 'Raccoon', 'Badger', 'Moose', 'Alpaca', 'Llama', 'Sloth',
    'Wombat', 'Platypus', 'Kangaroo', 'Dolphin', 'Whale', 'Seal', 'Walrus',

    // Birds
    'Penguin', 'Owl', 'Eagle', 'Hawk', 'Parrot', 'Toucan', 'Flamingo',
    'Pelican', 'Puffin', 'Hummingbird', 'Peacock', 'Raven', 'Sparrow',

    // Reptiles/Amphibians
    'Turtle', 'Gecko', 'Chameleon', 'Dragon', 'Frog', 'Axolotl', 'Salamander',

    // Sea creatures
    'Octopus', 'Jellyfish', 'Seahorse', 'Starfish', 'Crab', 'Lobster', 'Narwhal',

    // Insects
    'Butterfly', 'Beetle', 'Firefly', 'Ladybug', 'Bumblebee',

    // Pokemon
    'Pikachu', 'Eevee', 'Snorlax', 'Jigglypuff', 'Bulbasaur', 'Charmander',
    'Squirtle', 'Totodile', 'Mudkip', 'Treecko', 'Torchic', 'Piplup',
    'Chimchar', 'Turtwig', 'Oshawott', 'Tepig', 'Snivy', 'Froakie',
    'Fennekin', 'Chespin', 'Rowlet', 'Litten', 'Popplio', 'Grookey',
    'Scorbunny', 'Sobble', 'Meowth', 'Psyduck', 'Togepi', 'Mew',
    'Ditto', 'Gengar', 'Haunter', 'Gastly', 'Magikarp', 'Gyarados',
    'Dragonite', 'Lapras', 'Vaporeon', 'Jolteon', 'Flareon', 'Umbreon',
    'Espeon', 'Leafeon', 'Glaceon', 'Sylveon', 'Lucario', 'Riolu',
    'Zorua', 'Zoroark', 'Mimikyu', 'Wooloo', 'Yamper', 'Corviknight',
    'Alcremie', 'Applin', 'Toxel', 'Morpeko', 'Cyndaquil', 'Chikorita',
    'Mareep', 'Wooper', 'Quagsire', 'Slowpoke', 'Bidoof', 'Shinx',

    // Mythical
    'Phoenix', 'Griffin', 'Unicorn', 'Kraken', 'Yeti', 'Sphinx',
  ];

  /// Generate a random fun name like "Fuzzy Totodile"
  static String generate() {
    final adjective = _adjectives[_random.nextInt(_adjectives.length)];
    final animal = _animals[_random.nextInt(_animals.length)];
    return '$adjective $animal';
  }

  /// Generate a name with a specific seed for consistency
  static String generateWithSeed(int seed) {
    final seededRandom = Random(seed);
    final adjective = _adjectives[seededRandom.nextInt(_adjectives.length)];
    final animal = _animals[seededRandom.nextInt(_animals.length)];
    return '$adjective $animal';
  }
}
