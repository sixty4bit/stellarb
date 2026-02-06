# Edit Stops Feature Implementation Plan

## Overview
Implement inline editing of trade route stops on the route show page. Each stop can have multiple **intents** (conditional buy/sell orders with price limits). Changes auto-save as the user edits.

## Key Concepts

**Intent** = A conditional trade order with price protection
- Buy intents have a `max_price` (won't buy if market price exceeds this)
- Sell intents have a `min_price` (won't sell if market price is below this)
- Price limits are **required** on all intents
- When price is outside limit: **skip the intent, continue route, notify player**

## Data Model

**New stop structure:**
```ruby
{
  "system_id" => 123,
  "system" => "Alpha Centauri",
  "intents" => [
    {
      "type" => "buy",
      "commodity" => "ore",
      "quantity" => 100,
      "max_price" => 150    # Required: won't buy if price > 150
    },
    {
      "type" => "sell",
      "commodity" => "water",
      "quantity" => 50,
      "min_price" => 80     # Required: won't sell if price < 80
    }
  ]
}
```

**Skipped intent notification (Inbox message):**
```
Route rt-abc skipped intent at Alpha Centauri
  BUY ore x 100 (limit: 150 cr)
  Market price: 187 cr (+25% over limit)
  Route continued to next stop.
```

## UI/UX Flow

**View Mode:**
```
Route Stops
[1] Alpha Centauri
    BUY ore x 100 @ max 150 cr
    SELL water x 50 @ min 80 cr
[2] Beta Hydri
    SELL ore x 150 @ min 120 cr
[Edit Stops]
```

**Edit Mode:**
```
Route Stops [EDITING]                                    [Done]
┌────────────────────────────────────────────────────────────────┐
│ [1] [▲] [▼] [×]  System: [Alpha Centauri ▼]                    │
│ ┌────────────────────────────────────────────────────────────┐ │
│ │ [×] [buy ▼] [ore ▼] Qty: [100] Max price: [150] cr         │ │
│ └────────────────────────────────────────────────────────────┘ │
│ ┌────────────────────────────────────────────────────────────┐ │
│ │ [×] [sell ▼] [water ▼] Qty: [50] Min price: [80] cr        │ │
│ └────────────────────────────────────────────────────────────┘ │
│ [+ Add Intent]                                                 │
└────────────────────────────────────────────────────────────────┘
[+ Add Stop]

Keyboard: j/k=select stop, u/d=move stop, x=delete, a=add stop, Esc=done
```

**Price limit field changes based on intent type:**
- `buy` / `load` → shows "Max price" field
- `sell` / `unload` → shows "Min price" field

## Files to Modify

### 1. Routes (`config/routes.rb`)
```ruby
resources :routes do
  member do
    get :edit_stops
    post :add_stop
    delete "remove_stop/:stop_index", action: :remove_stop, as: :remove_stop
    patch :reorder_stop
    patch "update_stop/:stop_index", action: :update_stop, as: :update_stop
    post "add_intent/:stop_index", action: :add_intent, as: :add_intent
    delete "remove_intent/:stop_index/:intent_index", action: :remove_intent, as: :remove_intent
    patch "update_intent/:stop_index/:intent_index", action: :update_intent, as: :update_intent
  end
end
```

### 2. Controller (`app/controllers/routes_controller.rb`)
Add actions:
- `edit_stops` - returns edit mode partial via Turbo Frame
- `add_stop` - appends stop with empty intents array
- `remove_stop` - deletes stop at index
- `reorder_stop` - swaps stop with neighbor (up/down)
- `update_stop` - updates stop system_id
- `add_intent` - appends intent to stop's intents array
- `remove_intent` - deletes intent from stop
- `update_intent` - updates intent fields (type, commodity, quantity, price limit)

### 3. Model (`app/models/route.rb`)
Add validation:
```ruby
validate :all_intents_have_price_limits

def all_intents_have_price_limits
  stops.each_with_index do |stop, stop_idx|
    (stop["intents"] || []).each_with_index do |intent, intent_idx|
      case intent["type"]
      when "buy", "load"
        if intent["max_price"].blank?
          errors.add(:base, "Stop #{stop_idx + 1}, intent #{intent_idx + 1}: max_price required for #{intent['type']}")
        end
      when "sell", "unload"
        if intent["min_price"].blank?
          errors.add(:base, "Stop #{stop_idx + 1}, intent #{intent_idx + 1}: min_price required for #{intent['type']}")
        end
      end
    end
  end
end
```

### 4. Views

**Modify:** `app/views/routes/show.html.erb`
- Wrap Route Stops section in `<turbo-frame id="route_stops">`
- Update display to show intents with price limits

**Create:** `app/views/routes/_stops.html.erb`
- View-only stops display with nested intents
- Shows price limits: "BUY ore x 100 @ max 150 cr"

**Create:** `app/views/routes/_stops_edit.html.erb`
- Edit mode container
- Loop over stops rendering `_stop_form` partial
- Add Stop button, Done button, keyboard hints

**Create:** `app/views/routes/_stop_form.html.erb`
- Stop card with system dropdown and move/delete buttons
- Loop over intents rendering `_intent_form` partial
- Add Intent button within each stop

**Create:** `app/views/routes/_intent_form.html.erb`
- Single intent row:
  - Type dropdown (buy/sell/load/unload)
  - Commodity dropdown (from system's base_prices)
  - Quantity input
  - Price limit input (label changes based on type)
  - Delete button
- Auto-submits on change

### 5. Stimulus Controller (`app/javascript/controllers/route_stops_edit_controller.js`)
- Stop-level navigation: j/k select, u/d move, x delete stop, a add stop
- Auto-save on form field change (500ms debounce)
- Visual selection highlight

### 6. Stimulus Controller (`app/javascript/controllers/intent_form_controller.js`)
- Switches price limit label when type changes
- "buy"/"load" → "Max price:"
- "sell"/"unload" → "Min price:"

## Skip + Notify Behavior

When route automation executes:

```ruby
# In route execution job
def execute_intent(stop, intent, system)
  current_price = system.current_price(intent["commodity"])

  case intent["type"]
  when "buy", "load"
    if current_price > intent["max_price"]
      notify_skipped_intent(intent, current_price, "over")
      return :skipped
    end
  when "sell", "unload"
    if current_price < intent["min_price"]
      notify_skipped_intent(intent, current_price, "under")
      return :skipped
    end
  end

  # Execute the trade...
end

def notify_skipped_intent(intent, current_price, direction)
  # Create inbox message for player
  Message.create!(
    user: route.user,
    category: :route_alert,
    subject: "Route #{route.short_id} skipped intent",
    body: "#{intent['type'].upcase} #{intent['commodity']} skipped. " \
          "Market: #{current_price} cr, Limit: #{price_limit(intent)} cr"
  )
end
```

## Data Flow

```
Edit stop system:
  Change dropdown → PATCH update_stop/:stop_index
                 → Updates stops[index].system_id
                 → Turbo Stream replaces stop frame

Add intent to stop:
  Click "+ Add Intent" → POST add_intent/:stop_index
                      → Appends to stops[index].intents
                      → Turbo Stream replaces stop frame

Edit intent:
  Change field → PATCH update_intent/:stop_index/:intent_index
              → Updates stops[stop].intents[intent]
              → Turbo Stream replaces intent frame

Remove intent:
  Click × on intent → DELETE remove_intent/:stop_index/:intent_index
                   → Removes from intents array
                   → Turbo Stream replaces stop frame
```

## Keyboard Shortcuts

| Key | Action | Context |
|-----|--------|---------|
| `e` | Enter edit mode | Route show page |
| `j` | Select next stop | Edit mode |
| `k` | Select previous stop | Edit mode |
| `u` | Move selected stop up | Edit mode |
| `d` | Move selected stop down | Edit mode |
| `x` | Delete selected stop | Edit mode (confirm) |
| `a` | Add new stop | Edit mode |
| `Esc` | Exit edit mode | Edit mode |

## Implementation Phases

### Phase 1: Data Migration
1. Create migration to transform existing stops to new format
2. Add `intents` array with price limits derived from current market prices
3. Update Route model validations

### Phase 2: Backend Routes & Controller
1. Add routes to `config/routes.rb`
2. Implement controller actions with Turbo Stream responses

### Phase 3: View Partials
1. Update show.html.erb with new display format
2. Create `_stops.html.erb`, `_stops_edit.html.erb`
3. Create `_stop_form.html.erb`, `_intent_form.html.erb`

### Phase 4: Stimulus Controllers
1. Create `route_stops_edit_controller.js` for keyboard navigation
2. Create `intent_form_controller.js` for dynamic price label

### Phase 5: Route Execution (separate feature)
1. Add price checking to route automation job
2. Implement skip + notify behavior
3. Create inbox message template for skipped intents

## Verification

1. **Manual testing:**
   - Create route, add stops with multiple intents
   - Verify price limit field label changes with type
   - Verify validation requires price limits
   - Edit intents (change type, commodity, quantity, limits)
   - Add/remove intents within a stop
   - Reorder stops

2. **Test commands:**
   ```bash
   bin/rails test test/controllers/routes_controller_test.rb
   bin/rails test test/models/route_test.rb
   bin/rails test test/system/routes_test.rb
   ```

## Notes

- Commodities are dynamic per system (from `system.properties["base_prices"]`)
- Users can only select from `visited_systems` for stops
- Each stop must have at least one intent
- All intents require price limits (max_price for buy/load, min_price for sell/unload)
- No separate Stop/Intent models - stored as nested JSONB on Route
