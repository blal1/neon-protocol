# NEON PROTOCOL - Game Philosophy & Design DNA

## Core Identity

> *Un open world cyberpunk où le danger est constant, la violence rapide et sale, et où chaque amélioration technologique est une dette morale ou sociale.*

---

## What This Game IS NOT

| ❌ Not This | Why |
|-------------|-----|
| **Power Fantasy** | The world doesn't bend to you |
| **Save the World** | You probably can't. At best, save yourself. |
| **Arcade Shooter** | Violence has weight, consequences, and cost |
| **Hero's Journey** | There are no heroes here, only survivors |

---

## What This Game IS

| ✅ This | Implementation |
|---------|----------------|
| **Permanent Vulnerability** | High damage, limited healing, cyberpsychosis risk |
| **Heavy Choices** | Every decision closes doors, opens others |
| **Absurd Tragedy** | Dark humor masking real suffering |
| **Moral Ambiguity** | No good options, only less bad ones |
| **Compromise & Loss** | You will lose things. Accept it. |

---

## The Player Is...

```
Not a hero, but:
├── A Survivor     - Staying alive is the goal
├── A Mercenary    - Everyone has a price, including you
├── A Pawn         - Factions use you, discard you
└── Sometimes...   - A Monster (if you choose to be)
```

---

## Tonal Pillars

### 1. Tragic 😢
- Stories don't have happy endings
- Good people die. Bad people prosper.
- Your best efforts may not matter
- Loss is part of the experience

### 2. Absurd 🎭
- Anarchists with a king
- AI suffering from CAPTCHA pain
- Paying to watch ads
- Elections by combat to the death

### 3. Political 📢
- Corporations own everything
- Information is the real currency
- Identity itself is commodified
- Rebellion becomes a product

### 4. Human ❤️
- Behind every NPC is a story
- Connection is rare and precious
- Love exists, but costs something
- Empathy makes you vulnerable

---

## Design Principles

### Combat
```gdscript
# NOT THIS:
damage = 10  # Chip away at health
health_regen = true

# THIS:
damage = player_max_health * 0.3  # 3-4 hits = death
health_regen = false  # Healing is scarce and expensive
```

- **Lethal**: 3-4 hits kill anyone
- **Expensive**: Ammo, healing, repairs all cost
- **Risky**: Every fight could be your last
- **Optional**: Often better to avoid combat

### Economy
- **Everything costs credits**
- **Implants require subscriptions**
- **Debt is a game mechanic**
- **Poverty is ever-present**

### Reputation
- **You can't please everyone**
- **Helping one group hurts another**
- **Past actions haunt you**
- **Trust is earned slowly, lost instantly**

### Narrative
- **No quest markers for morality**
- **Consequences are delayed**
- **NPCs remember everything**
- **The world moves without you**

---

## What Can Be Sold

In NEON DELTA, **everything** has a price:

| Asset | How It's Sold |
|-------|---------------|
| **Memory** | Implant that stores/sells your experiences |
| **Identity** | Fake IDs, stolen personas, new faces |
| **Organs** | Black market chop shops |
| **Time** | Watch ads for credits |
| **Loyalty** | Betray anyone for the right price |
| **Pain** | Sold as "authentic experiences" |
| **Rebellion** | Commodified by corporations |

---

## Player Agency Philosophy

Players should feel:

1. **Empowered but not invincible**
   - Skills matter, but luck matters too
   - Good planning beats good reflexes

2. **Free but not without consequence**
   - Any path is valid
   - No path is without cost

3. **Informed but not guided**
   - Information is available if you look
   - The game won't tell you what's "right"

4. **Connected but not dependent**
   - NPCs have their own lives
   - The world exists beyond you

---

## Scenario Design Template

Every scenario should include:

```
SETUP:
- Clear stakes (what's at risk?)
- Time pressure (why act now?)
- Emotional hook (why care?)

CHOICES:
- Minimum 3 options
- No "obviously correct" choice
- Each has unique consequences
- At least one morally gray option

CONSEQUENCES:
- Immediate feedback
- Delayed repercussions (2-5 missions later)
- World state changes
- NPC memory updates

THEME:
- Connects to core cyberpunk themes
- Challenges player assumptions
- Leaves lasting impression
```

---

## Example: Applied Philosophy

**Scenario**: A child asks you to save their parent from debt collectors.

| Choice | Immediate Result | Delayed Consequence |
|--------|------------------|---------------------|
| Save parent (combat) | Parent lives, collectors dead | Collectors' guild hunts you |
| Pay off debt (5000 credits) | Parent lives, you're broke | Child remembers, helps later |
| Negotiate (charisma check) | Partial success | Debt reduced, still ongoing |
| Sell parent's location | 2000 credits | Child becomes street orphan, may seek revenge |
| Do nothing | ? | Parent disappears, child becomes NPC gang member |

**Note**: There is no "good" option. There are only options.

---

## Final Reminder

When designing content, ask:

1. Does this feel **dangerous**?
2. Does this have **real cost**?
3. Is the choice **genuinely difficult**?
4. Will the player **remember this**?
5. Does it reinforce: **Cyberpunk = Compromise, Loss, Ambiguity**?

---

*"The future isn't bright. It's neon, and it flickers."*
