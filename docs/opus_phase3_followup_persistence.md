Poslední krok Phase 3 — výměna `InMemorySaveStore` za reálnou perzistentní storage, aby `remove_ads_purchased`, `daily_streak`, `completed_level_ids`, a zbytek `PlayerProfile`/level snapshotů skutečně přežily restart appky. Bez tohohle není acceptance kritérium "Remove-ads purchase flow works and persists `remove_ads_purchased = true`" reálně splněné — jen v rámci jednoho běhu appky.

Než začneš, znovu si přečti z disku:
- `lib/core/save/save_service.dart`, `lib/core/save/local_save_repository.dart`, a definici `SaveStore` rozhraní (jakkoliv se jmenuje soubor)
- `lib/core/save/...` — jestli existuje `InMemorySaveStore` jako samostatný soubor

---

Úkol:

1. **Implementuj `SharedPreferencesSaveStore`** (nebo ekvivalentní pojmenování konzistentní s existujícím `InMemorySaveStore`), který implementuje stejné `SaveStore` rozhraní z Phase 1, ale ukládá/čte data přes balíček `shared_preferences`.
   - Klíče: použij stejné klíčování, jaké `LocalSaveRepository`/`SaveService` už používá pro `InMemorySaveStore` (např. `level_id` nebo `app/profile`) — neměň klíčovací schéma, jen storage backend.
   - Hodnoty: snapshoty jsou už JSON-serializovatelné (Phase 1/2 to ověřily testy) — ulož je jako JSON string přes `shared_preferences` `setString`/`getString`.
   - Žádná migrace dat z `InMemorySaveStore` není potřeba (in-memory data se stejně ztrácela při restartu, není co migrovat).

2. **Přidej `shared_preferences` jako jedinou novou dependency.** To je legitimní výjimka z "žádné nové dependencies" pravidla z předchozích fází — zdůvodni v Implementation decisions, že je to nejmenší, nejstandardnější balíček pro tenhle účel (oficiální Flutter team package, žádné platformní nativní kódování navíc potřeba).

3. **Přepni `AppServices`/inicializaci appky** na `SharedPreferencesSaveStore` jako výchozí produkční store. `InMemorySaveStore` zachovej v kódu — bude se i nadále hodit pro testy (rychlejší, bez platform channel závislosti), takže testy NEMĚŇ na nový store, pokud to není nutné.

4. **Ověř konkrétně tyhle scénáře** (buď jako nový test, nebo jako manuální test, který mi popíšeš, ať to udělám u sebe):
   - Dokonči puzzle → zavři appku (force-close) → znovu otevři → level je označený jako completed.
   - Koupit remove-ads (přes settings) → zavři appku → znovu otevři → `remove_ads_purchased == true`, žádné interstitially se nezobrazují.
   - Dokonči daily puzzle → zavři appku → znovu otevři příští den → streak je správně navýšený, ne resetovaný.

5. **`flutter pub get`** bude potřeba po přidání dependency — uveď to explicitně ve výstupu, ať to spustím.

---

Co NEDĚLAT:
- Neměň `SaveStore` rozhraní samotné (signatura `save`/`load`/atd. zůstává) — jen přidáváš novou implementaci.
- Neimplementuj žádnou cloud/account sync vrstvu — čistě lokální `shared_preferences`.
- Nepřidávej žádný migrace/versioning systém pro snapshot schema (žádná data k migraci, jak je uvedeno v bodě 1).
- Neřeš souběžně nic jiného z Phase 3/4 (žádné SDK reklamy, žádný nový obsah).

Po dokončení: aktualizuj `PHASE3_NOTES.md` — uprav dřívější caveat o in-memory store na potvrzení, že je vyřešený, a do Implementation decisions přidej zdůvodnění volby `shared_preferences` nad alternativami (file-based JSON store), pokud jsi o tom uvažoval.

Sandbox u tebe pravděpodobně pořád nemá Dart SDK — pokud ano, řekni to explicitně jako v předchozích fázích a uveď, co jsi ověřil ručně/portem do jiného jazyka vs. co potřebuje ověřit člověk se skutečným Flutter prostředím.
