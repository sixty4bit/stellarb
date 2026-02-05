# Bot Test Matrix

This document defines all game behaviors to test with automated bots, expected outcomes, and test priorities.

---

## Priority Levels

| Priority | Description |
|----------|-------------|
| **P0** | Critical path - game unplayable if broken |
| **P1** | Core gameplay - significantly degrades experience |
| **P2** | Important features - noticeable but workaroundable |
| **P3** | Nice to have - polish and edge cases |

---

## 1. Onboarding Flow (P0)

### 1.1 User Registration
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| New user signup | Visit signup, enter email | User created, redirected to Cradle |
| User spawns in Cradle | Complete signup | User location is System(0,0,0) |
| Starting credits granted | Complete signup | User has starting_credits (500) |
| Starter ship assigned | Complete signup | User owns 1 Scout-class ship |

### 1.2 Tutorial Quest Completion
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| Phase 1: Basic supply chain | Complete Cradle tutorial | "The Grant" awarded (credits) |
| Phase 2: Exploration unlock | Complete exploration tutorial | Colonial Ticket unlocked |
| Phase 3: Hub selection | Choose from 5 hubs | Player transported to frontier |

---

## 2. Ship Operations (P0)

### 2.1 Ship Purchase
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| Buy ship with sufficient credits | Select ship, confirm purchase | Ship owned, credits deducted |
| Buy ship insufficient credits | Try to buy expensive ship | Error, transaction rejected |
| Ship appears in fleet | After purchase | Ship visible in /ships list |

### 2.2 Ship Navigation
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| Warp to nearby system | Command warp with fuel | Ship in transit, ETA shown |
| Warp arrival | Wait for transit time | Ship arrives, location updated |
| Warp denied - no fuel | Warp without fuel | Error, ship stays put |
| Warp denied - out of range | Warp beyond fuel range | Error with range message |

### 2.3 Ship Crew
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| Assign navigator | Hire navigator, assign to ship | Ship gains nav bonuses |
| Fire crew member | Select crew, fire | Hiring ended, ship efficiency drops |
| Crew wage payment | Daily tick | Wages deducted from user credits |

---

## 3. Trading (P1)

### 3.1 Market Operations
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| View market prices | Visit system market | Prices displayed (visited systems only) |
| Buy commodity | Select good, quantity, buy | Cargo loaded, credits deducted |
| Sell commodity | Select cargo, sell | Cargo removed, credits gained |
| Buy exceeds cargo capacity | Try to overfill | Error, partial purchase or reject |

### 3.2 Trading Routes
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| Create route | Define stops A→B→C→A | Route saved with profit estimate |
| Assign ship to route | Select ship, assign | Ship begins automated loop |
| Route profit calculation | Complete one loop | Actual profit matches estimate (±20%) |
| Pause route | Pause active route | Ship stops at next dock |
| Delete route | Delete route | Ship becomes idle |

### 3.3 Arbitrage Profit
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| Complete buy low/sell high | Buy at A (low), sell at B (high) | Net positive credits |
| Market price variance | Check prices over time | Prices fluctuate within variance range |

---

## 4. Building Operations (P1)

### 4.1 Construction
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| Build extractor | Have materials, build | Building in constructing state |
| Construction completes | Wait for build time | Building becomes operational |
| Build denied - missing materials | Try without materials | Error message |

### 4.2 Production
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| Building produces resources | Operational building ticks | Output added to storage |
| Production with staff bonus | Assign skilled engineer | Output increased by efficiency |
| Production without inputs | Missing energy/materials | Production halts |

### 4.3 Maintenance
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| Building breakdown | Low maintenance roll | Building damaged, efficiency drops |
| Repair building | Pay repair cost | Building returns to operational |
| Catastrophic failure | 1% pip chance triggers | Building offline, requires presence |

---

## 5. NPC/Worker Management (P1)

### 5.1 Recruiter
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| View recruiter pool | Open recruiter screen | Available NPCs shown |
| Hire NPC | Select recruit, hire | HiredRecruit created, Hiring active |
| Pool refresh | Wait 30-90 minutes | New recruits appear |
| Same pool for same level | Two users same level | See identical recruit list |

### 5.2 Employment
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| Assign to ship | Drag worker to ship | Hiring.assignable = ship |
| Assign to building | Drag worker to building | Hiring.assignable = building |
| Fire worker | Fire button | Hiring status = fired |
| Worker wage due | Daily tick | Wage deducted, or strike |

### 5.3 NPC Chaos
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| High chaos NPC incident | Assign chaos NPC, wait | More frequent incidents |
| Service record updated | Incident occurs | Record appears on NPC resume |

---

## 6. System Exploration (P2)

### 6.1 Discovery
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| Scan unknown system | Use scanner | System "realized" in database |
| First discovery bonus | Be first to scan | XP/credits bonus, discoverer tag |
| Fog of war respected | Query unvisited system | No market/resource data returned |

### 6.2 Ownership
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| Build starbase hub | Construct admin hub | System claimed |
| Ownership decay | Governor unpaid | System reverts to neutral |

---

## 7. Travel Mechanics (P2)

### 7.1 Basic Travel
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| Travel time calculated | Warp to system | Time = distance × 60s/grid |
| Fuel consumed | Complete travel | Fuel deducted from ship |
| High-tier engine bonus | Upgrade engine | Travel time reduced |

### 7.2 Warp Gates
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| Use warp gate | Warp via gate | Travel time = 1 grid equivalent |
| Gate fee paid | Use gate | Fee deducted (owner receives cut) |
| Gate chain travel | Multiple gate hops | Each hop takes time |

### 7.3 System Entry Mode
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| Enter trade mode | Select Trade on entry | Access to markets, peaceful |
| Enter battle mode | Select Battle on entry | Defense grid engages |
| Mode locked in system | Try to switch while docked | Rejected, must leave first |

---

## 8. Combat (P2)

### 8.1 Basic Combat
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| Attack NPC target | Engage drone/pirate | Combat rolls, damage dealt |
| Ship destroyed | HP reaches 0 | Ship lost, salvage created |
| Victory loot | Defeat enemy | Cargo/materials dropped |

### 8.2 Defense
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| Defense grid activation | Enemy enters battle mode | Grid engages automatically |
| Marine bonus | Marines assigned | Combat rolls improved |

---

## 9. Economy & Decay (P2)

### 9.1 Asset Decay
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| Ship maintenance cost | Daily tick | Credits deducted |
| Unpaid maintenance | No credits for upkeep | Breakdown chance increases |
| NPC aging | Over time | NPCs retire/die |

### 9.2 Pip Infestation
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| Pip event triggers | 1% of failures | Asset goes offline |
| Remote fix denied | Try to fix remotely | Error, requires presence |
| Physical purge | Travel to asset, purge | Asset returns to service |

---

## 10. UI Navigation (P3)

### 10.1 Keyboard Navigation
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| j/k navigation | Press j/k on list | Selection moves up/down |
| Enter to drill in | Press Enter on item | Detail view opens |
| Esc to go back | Press Esc | Returns to previous screen |
| H for home | Press H anywhere | Returns to Inbox |

### 10.2 Breadcrumbs
| Test Case | Steps | Expected Outcome |
|-----------|-------|------------------|
| Breadcrumbs update | Drill into nested view | Path shown at top |
| Breadcrumb click | Click parent crumb | Navigates to that level |

---

## Test Execution Order

For automated bot testing, execute in this order:

1. **Smoke Test Suite** (P0 only) - ~5 minutes
   - Registration → Ship purchase → Basic navigation

2. **Core Gameplay Suite** (P0 + P1) - ~20 minutes
   - Full onboarding → Trading loop → Building operations

3. **Full Regression Suite** (All priorities) - ~60 minutes
   - All test cases above

---

## Bot Test Rake Tasks

```bash
# Run all bot tests
bin/rails bot:test

# Run specific suites
bin/rails bot:test:onboarding   # P0 onboarding tests
bin/rails bot:test:trading      # P1 trading loop tests
bin/rails bot:test:navigation   # P2 travel/exploration tests
bin/rails bot:test:smoke        # Quick P0 smoke test
```

---

## Success Metrics

| Metric | Target |
|--------|--------|
| P0 tests passing | 100% |
| P1 tests passing | 100% |
| P2 tests passing | 95%+ |
| Full suite runtime | <60 minutes |
| Flaky test rate | <2% |
