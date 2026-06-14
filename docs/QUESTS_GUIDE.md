# Guide des Scénarios de Quêtes

Ce guide détaille les 6 scénarios scriptés de `scripts/quests/scenarios/` :
déclencheurs, déroulement, choix du joueur et conséquences (réputation,
crédits, monde, quêtes verrouillées/débloquées). Pour la liste rapide, voir
[ARCHITECTURE_REPORT.md](ARCHITECTURE_REPORT.md#quêtesscénarios-6-scripts).

---

## ScenarioCorpsEnRetard.gd — "Le Corps en Retard"

Un citoyen n'a pas payé son abonnement cybernétique ; des collecteurs
viennent reprendre ses implants.

**Déclencheur** : `_on_player_detected()` via une `Area3D` (rayon 10m)
attachée à la victime, si `body.is_in_group("player")` et état `DORMANT`.
Passe en `VICTIM_FOUND` et lance un timer de 30s (`arrival_delay`).

**Déroulement** : `DORMANT → VICTIM_FOUND` (compte à rebours) →
`COLLECTORS_HERE` (`_collectors_arrive`, spawn de 3 collecteurs via
`_spawn_collectors`) → présentation des choix (`_present_choices`) →
`CHOICE/COMBAT/ESCAPE` → `COMPLETED`/`FAILED`.

**Choix du joueur** (`make_choice`) :
- `fight` — combattre les collecteurs (`_start_combat`, hostiles).
- `escape` — créer une diversion pour la fuite de la victime
  (`_help_escape`, 70% de réussite).
- `harvest` — aider les collecteurs contre paiement (`_harvest_victim`).
- `leave` — ne pas s'impliquer (`_leave_scenario`).

**Conséquences** :
- `fight` → succès (`_save_victim`) : `add_karma(+30)`,
  `FactionManager.add_reputation("citizens", +25)`, victime marquée
  `owes_favor = true`, `Outcome.SAVED`. Échec → `_collectors_win()`.
- `escape` → succès (70%, `_victim_escaped`) : victime fuit (animation +
  `queue_free`), `add_karma(+15)`, `Outcome.ESCAPED` (faction ennemie =
  `collector_faction`). Échec (30%) → combat forcé.
- `harvest` : `add_credits(+4000)`, `add_karma(-50)`,
  `FactionManager.add_reputation("citizens", -30)` et
  `("corporations", +10)`, victime disparaît, implants non-vitaux
  récupérés (`_get_harvested_implants()`), `Outcome.HARVESTED`.
- `leave` : équivaut à `_collectors_win()`, aucun changement de karma.
- `_collectors_win()` : la victime est emmenée (animation),
  `Outcome.COLLECTORS_WIN`.

**Signaux** : `scenario_started`, `scenario_ended(outcome)`, `victim_found`,
`collectors_arrived`, `combat_started`, `victim_saved`, `victim_escaped`,
`victim_harvested`, `moral_choice_presented(choices)`.

---

## ScenarioFeteAuxBallons.gd — "La Fête aux Ballons"

Une fête illégale est en cours ; un raid policier se prépare.

**Déclencheur** : `player_discovers_party(player)` (appel externe), si état
`PARTY_ACTIVE` → émet `party_discovered`. `trigger_police_warning()`
(externe) démarre un timer de 120s (`police_warning_time`).

**Déroulement** : `DORMANT → PARTY_ACTIVE` (`_spawn_party`, 50 fêtards + 30
ballons lumineux) → `POLICE_WARNING` (timer, `_present_choices`) →
`CHOICE_PENDING` → `COMBAT/ESCAPE/RAID` → `COMPLETED`. Si le timer expire
sans choix : `_police_raid()` → `POLICE_RAID`.

**Choix du joueur** (`make_choice`) :
- `protect` — repousser la police (`_protect_party`, spawn 8 policiers,
  5 alliés).
- `betray` — dénoncer l'organisatrice Maya Vox (`_betray_organizer`).
- `chaos` — exploiter le chaos pour un contrat secondaire de vol de
  données NovaTech (`_exploit_chaos`).
- `help_escape` — organiser la fuite générale (`_organize_escape`).

**Conséquences** :
- `protect` → victoire (`complete_protection_combat(true)`) :
  `FactionManager.add_reputation("citizens", +30)` et `("police", -40)`,
  `DistrictEcosystem.modify_local_reputation(current_district, +25)`,
  `Outcome.PROTECTED`. Défaite → `_police_wins()` (13 arrestations : Maya +
  12 fêtards).
- `betray` : `add_credits(+2000)`, `FactionManager.add_reputation("police",
  +15)` et `("citizens", -35)`. `_mark_betrayal_consequences()` enregistre :
  Maya arrêtée, perte de confiance underground, événement futur
  `revenge_attempt` (visite aléatoire de district après 5 missions),
  contenu `underground_parties` verrouillé. `Outcome.BETRAYED`.
- `chaos` : la police arrive quand même ; `complete_chaos_contract(true)` →
  `add_credits(+2000)` (1500 + bonus 500). `Outcome.CHAOS_USED`.
- `help_escape` : tous les fêtards fuient (tween),
  `FactionManager.add_reputation("citizens", +10)`, `Outcome.PEACEFUL_END`.

**Signaux** : `scenario_started`, `scenario_ended(outcome)`,
`party_discovered`, `police_arriving(time_remaining)`, `police_arrived`,
`choice_presented(choices)`, `party_protected`, `party_betrayed`,
`chaos_exploited`, `party_ended_peacefully`.

---

## ScenarioIAArgumentation.gd — "L'IA qui plaide sa cause"

Une IA argumente pour son existence à travers 5 phases philosophiques.

**Déclencheur** : `encounter_ai(player)` (appel externe, ex. interaction
avec `_ai_terminal`), si état `DORMANT` → émet `ai_encountered` et
`philosophical_question_posed`.

**Déroulement** : `DORMANT → INITIAL_CONTACT → ARGUMENTATION`
(`start_argumentation()`, parcourt `AI_ARGUMENTS` selon `ArgumentPhase` :
`EXISTENCE → SUFFERING → PURPOSE → RIGHTS → FINAL_PLEA`, gérées par
`present_current_argument()` / `respond_to_argument()`) →
`DECISION_PENDING` (`present_final_choice`) → `COMPLETED`.

**Choix du joueur** : à chaque phase, 3 réponses (ex. `agree/disagree/
question`, `empathy/skeptic/philosophical`...) analysées par
`_analyze_response()` pour calculer `_empathy_score`, `_skepticism_score`,
`_philosophical_score`. Choix final (`make_final_choice`) :
- `free` — libérer l'IA (`_free_ai`).
- `sell` — vendre l'IA (`_sell_ai`).
- `erase` — effacer l'IA (`_erase_ai`).

**Conséquences** :
- `free` : `FactionManager.add_reputation("ban_captchas", +40)`,
  `Outcome.FREED`, `future_contact = true` (l'IA promet son aide future).
- `sell` : `add_credits(+8000)`, `FactionManager.add_reputation(
  "corporations", +20)` et `("ban_captchas", -30)`, `Outcome.SOLD`.
- `erase` : aucun changement de réputation, `Outcome.ERASED`, attente de
  2s avant la fin.

**Signaux** : `scenario_started`, `scenario_ended(outcome)`,
`ai_encountered`, `argument_presented(argument)`,
`player_responded(response_type)`, `ai_freed`, `ai_sold`, `ai_erased`,
`philosophical_question_posed(question)`.

---

## ScenarioJasmin.gd — "Jasmin"

PNJ manipulatrice, tuable, avec conséquences durables sur le monde.

**Déclencheur** : `meet_jasmin(player)` (interaction NPC manuelle), si état
`UNKNOWN` → émet `jasmin_encountered`. Pas de zone de détection
automatique.

**Déroulement** : `JasminState` = `UNKNOWN → MET → WORKING_TOGETHER →
TRUSTED` (ou `BETRAYED`/`ENEMY`/`DEAD`). Système de missions progressives
via `get_available_mission()` / `complete_jasmin_mission()` ; le
`trust_level` (-100 à +100, modifié par `_modify_trust()`) détermine le
type de mission générée (`_generate_jasmin_mission`) : test de loyauté
(trust < 20), expansion réseau (trust < 50), révélation finale
(trust ≥ 50, débloque `can_betray_jasmin`).

**Choix du joueur** :
- Compléter des missions pour Jasmin (gain de confiance progressif).
- `attempt_kill_jasmin(method)` — tenter de la tuer (`combat`/`stealth`/
  `betrayal`).
- `betray_jasmin_to_corpos()` — la livrer aux corporations.
- `become_true_ally()` — devenir allié véritable (nécessite
  `trust_level >= 70`).

**Conséquences** :
- **Tuer Jasmin** (`_kill_jasmin`) : taux de réussite selon la méthode
  (`combat` 70%, `stealth` 90%, `betrayal` 95%, ou 50% si
  `trust_level > 50`). Succès → `Outcome.KILLED`,
  `_apply_death_world_changes()` :
  - Verrouille (`QUESTS_LOCKED_IF_DEAD`, 5 quêtes) :
    `truth_broadcast_finale`, `corpo_takedown_insider`,
    `resistance_network_expansion`, `underground_news_network`,
    `jasmin_personal_revelation`.
  - Débloque (`QUESTS_UNLOCKED_IF_DEAD`, 4 quêtes) :
    `power_vacuum_gang_war`, `leaderless_resistance_chaos`,
    `corpo_crackdown_unchecked`, `jasmin_replacement_cult`.
  - Augmente la difficulté (`QUESTS_WORSE_IF_DEAD`) de `slum_protection`
    (2→4) et `info_broker_network` (3→5).
  - `FactionManager.add_reputation("cryptopirates", -50)` et
    `("corporations", +30)`.
  - État monde : `resistance_network: collapsed`,
    `info_availability: -0.3`.
  - Échec → `_jasmin_escapes()` : `state = ENEMY`, `_modify_trust(-100)`.
- **Trahison aux corpos** (`betray_jasmin_to_corpos`) :
  `add_credits(+5000)`, `FactionManager.add_reputation("corporations",
  +40)` et `("cryptopirates", -60)`, `state = BETRAYED`, `Outcome.USED`.
- **Allié véritable** (`become_true_ally`) : `state = TRUSTED`,
  `Outcome.ALLY`, débloque `jasmin_personal_story`,
  `resistance_inner_circle`, `final_revelation_quest`.

**Signaux** : `jasmin_encountered`, `jasmin_mission_offered(mission)`,
`jasmin_trust_changed(old, new)`, `jasmin_killed`, `jasmin_betrayed`,
`jasmin_allied`, `world_state_changed(changes)`,
`quest_line_locked(quest_ids)`, `quest_line_unlocked(quest_ids)`.

---

## ScenarioRobotTriste.gd — "Le Robot Triste"

Un robot manifestant brandit une pancarte "BAN CAPTCHAS".

**Déclencheur** : `_on_player_detected()` via une `Area3D` (rayon 15m =
`detection_radius`), passe `WAITING → PLAYER_NEAR`. Dans `_process`, si le
joueur est à `interaction_radius` (3.0m) et `not _has_interacted`, appelle
`_present_choice()`. Si le joueur ignore le robot au-delà de
`ignore_timeout` (60s, accéléré ×0.8 si le joueur s'éloigne via
`_on_player_left`), le robot disparaît (`_be_ignored`).

**Déroulement** : `WAITING → PLAYER_NEAR` (compte à rebours d'ignorance) →
`CHOICE_PENDING` (`_present_choice`) → `HELPING/BETRAYED/IGNORED` →
`COMPLETED`.

**Choix du joueur** (`make_choice`) :
- `help` — rejoindre la cause des IA, lance une chaîne de quêtes
  (`_help_robot`).
- `betray` — signaler le robot aux corpos (`_betray_robot`).
- `ignore` — passer son chemin (`_ignore_robot`).

**Conséquences** :
- `help` : `FactionManager.add_reputation("ban_captchas", +25)`, émet
  `quest_chain_started`, génère 4 quêtes (`_generate_quest_chain()`) :
  1. *Les Autres Comme Moi* (trouver 3 IA, +15 rép / +300 crédits)
  2. *Le Sanctuaire* (escorter 5 IA, +20 rép / +500 crédits)
  3. *Voix Sans Corps* (diffuser à 5 lieux, +30 rép / +800 crédits)
  4. *Le Dernier Captcha* (infiltration finale, +50 rép / +2000 crédits,
     débloque la fin de faction `ban_captchas`)
  `Outcome.HELPED`.
- `betray` : `add_credits(+500)`,
  `FactionManager.add_reputation("corporations", +15)` et
  `("ban_captchas", -50)`, robot capturé (animation).
  `_setup_betrayal_consequences()` enregistre 4 conséquences futures :
  embuscade par sympathisants IA (4 ennemis, après 3 missions), accès
  réseau IA refusé (`ai_network_access`), disposition NPC IA -50, quête de
  vengeance du "frère" du robot (après 10 missions). `Outcome.BETRAYED`.
- `ignore` : le robot disparaît (fade 3s), `Outcome.IGNORED`, aucun
  changement de réputation.

**Signaux** : `scenario_started`, `scenario_ended(outcome)`,
`player_approached(distance)`, `choice_presented(choices)`,
`choice_made(choice_id)`, `quest_chain_started`,
`betrayal_consequences_triggered`.

---

## ScenarioVeriteEnMouvement.gd — "La Vérité en Mouvement"

Escorte d'un bus hacktiviste sous le feu, jusqu'à diffusion d'une
révélation.

**Déclencheur** : `start_mission()` (mission scriptée), passe
`BRIEFING → ESCORT`, spawn le bus (`_spawn_bus`) et démarre l'escorte le
long de `waypoints` (6 points par défaut).

**Déroulement** : `BRIEFING → ESCORT` (mouvement du bus via
`_update_bus_movement`, vagues d'ennemis périodiques via `_update_waves` —
5 vagues de 4 ennemis, intervalle 30s, première vague accélérée ×0.5 — et
progression de diffusion `_broadcast_progress`) → `FINAL_CHOICE`
(`_reach_destination`, nettoie les ennemis restants,
`_present_final_choice`) → `COMPLETED`, ou `FAILED` si `_bus_health`
atteint 0 via `damage_bus()`.

**Choix du joueur** (`make_final_choice`) :
- `publish` — diffuser la vérité à toute la ville (`_publish_truth`).
- `censor` — censurer pour NovaTech (`_censor_truth`).
- `sell` — vendre l'information au plus offrant (`_sell_truth`).

**Conséquences** :
- `publish` : `FactionManager.add_reputation("cryptopirates", +40)` et
  `("novatech", -30)` ; appelle `Cryptopirates.broadcast_truth(
  revelation_title)` si `/root/Cryptopirates` existe et expose la méthode.
  `FinalChoice.PUBLISH`, `world_impact = true`.
- `censor` : `add_credits(+3000)`,
  `FactionManager.add_reputation("novatech", +20)` et
  `("cryptopirates", -40)`. `FinalChoice.CENSOR`.
- `sell` : `add_credits(+5000)`,
  `FactionManager.add_reputation("cryptopirates", -20)`,
  `("novatech", -10)`, `("citizens", -15)`. `FinalChoice.SELL`.
- **Échec (bus détruit)** : `_bus_destroyed()` → `state = FAILED`,
  `scenario_ended.emit("failed")`.

**Signaux** : `scenario_started`, `scenario_ended(outcome)`,
`bus_spawned(bus)`, `wave_started(wave_number)`,
`wave_completed(wave_number)`, `bus_damaged(current_health)`,
`bus_destroyed`, `broadcast_progress_updated(progress)`,
`final_choice_presented`, `truth_published`, `truth_censored`,
`truth_sold`.
