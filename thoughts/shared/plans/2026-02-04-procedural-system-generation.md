# Procedural System Generation

## Overview

Build the procedural system generation engine. Given a seed, generate a deterministic 10x10x10 grid of star systems. Systems contain planets, planets contain minerals and plants.

## Constraints

- **Grid:** 10x10x10 (coordinates 0-9 on each axis)
- **System spacing:** Every 3 coordinates (0, 3, 6, 9 on each axis)
- **Deterministic:** Same seed must produce identical systems every time
- **No database reads:** Generation is a pure function

## What to Build

### Phase 1: System Generator

Create `lib/procedural_generation/system_generator.rb`

**Input:** `seed` (string), `x`, `y`, `z` (integers 0-9, must be divisible by 3)

**Output:** Hash with:
- `star_type` — one of: `red_dwarf, yellow_dwarf, orange_dwarf, white_dwarf, blue_giant, red_giant, yellow_giant, neutron_star, binary_system, black_hole_proximity`
- `planets` — array of planet hashes (see Phase 2)

**Seed extraction:** See PRD Section 5.1.2 for algorithm.

### Phase 2: Planet Generator

Each system has 0-12 planets. Planet count derived from seed.

**Planet attributes:**
- `name` — procedural (e.g., "Kepler-7b", "Zeta Prime")
- `type` — one of: `rocky, gas_giant, ice, volcanic, oceanic, desert, jungle, barren`
- `size` — `small, medium, large, massive`
- `minerals` — array of mineral deposits (see Phase 3)
- `plants` — array of plant types (see Phase 4)

### Phase 3: Minerals (60 total)

**50 Real Minerals (from periodic table elements):**
```ruby
REAL_MINERALS = %w[
  iron copper gold silver platinum titanium aluminum nickel zinc lead
  tin tungsten cobalt chromium manganese vanadium molybdenum uranium thorium plutonium
  lithium beryllium magnesium calcium sodium potassium silicon carbon sulfur phosphorus
  mercury arsenic antimony bismuth cadmium indium gallium germanium selenium tellurium
  rubidium strontium zirconium niobium palladium rhodium ruthenium osmium iridium rhenium
].freeze
```

**10 Made-Up End-Game Minerals (rare):**
```ruby
EXOTIC_MINERALS = %w[
  stellarium voidstone chronite darkmatter quantium
  etherealite singularite cosmic_crystal zero_point_ore omnium
].freeze

# Rarity: exotic minerals appear in ~2% of deposits
```

**Mineral deposit structure:**
```ruby
{
  mineral: "iron",
  quantity: 1000..100000,  # tons
  purity: 0.1..1.0,        # extraction efficiency
  depth: "surface" | "shallow" | "deep" | "core"
}
```

### Phase 4: Plants (for flavor/future use)

10 plant types per biome. Plants are cosmetic for now but will matter later.

```ruby
PLANT_TYPES = {
  jungle: %w[megafern vinestalker sporetree glowmoss canopygiant],
  oceanic: %w[kelpforest coralbloom seagrass planktonmat floatfruit],
  desert: %w[cactoid sandblossom dustshrub miragepalm thornweed],
  # ... etc
}
```

### Phase 5: Grid Generator

Create `lib/procedural_generation/grid_generator.rb`

**Input:** `seed` (string)

**Output:** 4x4x4 = 64 systems (at coordinates 0,3,6,9 on each axis)

```ruby
GridGenerator.call(seed: "test123")
# => {
#   [0,0,0] => { star_type: "yellow_dwarf", planets: [...] },
#   [0,0,3] => { star_type: "red_giant", planets: [...] },
#   ...
# }
```

## Success Criteria

### Done when:

- [ ] `SystemGenerator.call(seed: "test", x: 0, y: 0, z: 0)` returns a valid system hash
- [ ] `GridGenerator.call(seed: "test")` returns exactly 64 systems
- [ ] Same seed + coordinates = identical output (run 1000x to verify)
- [ ] All 64 grid positions are at coordinates divisible by 3
- [ ] Each system has 0-12 planets
- [ ] Each planet has minerals array (1-10 deposits)
- [ ] Each planet has plants array (0-5 types based on planet type)
- [ ] ~98% of mineral deposits are real minerals, ~2% are exotic
- [ ] Generation requires no database access

### Measured by:

| Metric | Target | Verify |
|--------|--------|--------|
| Grid generation | <100ms | `Benchmark.measure { GridGenerator.call(seed: "test") }` |
| Single system | <2ms | `Benchmark.measure { SystemGenerator.call(seed: "x", x: 0, y: 0, z: 0) }` |
| Determinism | 100% | `100.times { assert_equal GridGenerator.call(seed: "x"), GridGenerator.call(seed: "x") }` |
| Exotic mineral rate | ~2% | Count exotic vs real across 1000 planets |

### Fails if:

- Different output for same seed
- Grid contains systems at non-divisible-by-3 coordinates
- Any system has negative planets or >12 planets
- Exotic minerals appear in >5% of deposits
- Generation touches the database

## Verify with:

```bash
bin/rails runner "
  require 'benchmark'
  
  # Determinism check
  seed = 'test123'
  result1 = GridGenerator.call(seed: seed)
  result2 = GridGenerator.call(seed: seed)
  puts 'Determinism: ' + (result1 == result2 ? 'PASS' : 'FAIL')
  
  # Grid size check
  puts 'Grid size: ' + (result1.keys.length == 64 ? 'PASS' : 'FAIL')
  
  # Coordinate check
  valid_coords = result1.keys.all? { |x,y,z| x % 3 == 0 && y % 3 == 0 && z % 3 == 0 }
  puts 'Coordinates: ' + (valid_coords ? 'PASS' : 'FAIL')
  
  # Performance
  time = Benchmark.measure { GridGenerator.call(seed: 'perf') }
  puts 'Performance: ' + (time.real < 0.1 ? 'PASS' : 'FAIL') + \" (#{(time.real * 1000).round}ms)\"
"
```

## Files to Reference

- PRD Section 5.1: `/docs/PRD.md` (seed extraction algorithm, star types)
- Rails agents: `.claude/agents/` (use for Rails patterns)

## Notes

- This is a pure Ruby implementation in `lib/`
- No models or database tables yet
- Tests go in `test/lib/procedural_generation/`
