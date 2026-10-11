# Aura Farm Tycoon

Een Roblox tycoon waarin je **aura farmt**. Je bouwt Aura Generators die gloeiende orbs maken, die over een lopende band naar je Aura Collector gaan. Met je Aura koop je nieuwe generators en boosters, en bij het Aura Altaar in het midden kun je zeldzame aura's rollen (van "Basic Glow" tot "Void Aura, 1 in 10000").

## De nieuwste versie downloaden (zonder git)

1. Ga naar de pagina van deze repository op GitHub.
2. Kies bovenin de goede **branch** (na het mergen van een pull request is dat gewoon `main`).
3. Klik op de groene knop **Code** en dan op **Download ZIP**.
4. Pak de ZIP uit (rechtermuisknop → **Alles uitpakken**). Gooi je oude map weg of zet hem ergens anders, zodat je niet per ongeluk de oude versie opent.
5. Doe daarna de stappen hieronder met de nieuwe map.

## In Roblox Studio zetten met Rojo

1. Open de uitgepakte map in **VS Code**.
2. Druk op `Ctrl + Shift + P`, typ **Rojo: Open menu** en kies **default.project.json**. Klik op **Start server**.
3. Open **Roblox Studio** en maak een nieuwe **Baseplate** place.
4. Ga naar het tabblad **Plugins**, klik op **Rojo** en dan op **Connect**. Zie je geen Rojo knop? Kies dan in het Rojo menu van VS Code eerst **Install Roblox Studio plugin**.
5. Klik op **Play** (F5). De hele wereld wordt vanzelf gebouwd als het spel start.

Elke keer als je code aanpast in VS Code, staat het meteen in Studio.

### Opslaan testen in Studio

Opslaan werkt pas als je de game één keer hebt gepubliceerd (**File → Publish to Roblox**). Zet dan aan: **Game Settings → Security → Enable Studio Access to API Services**. Zonder dit zie je in het spel de melding "Saving is off", en dat is dan normaal.

## Wat zit erin

| Onderdeel | Wat het doet |
|---|---|
| Wereld | Zonnige dag, gras dat wappert, vijvers met water, heuvels, een bos, paden met lantaarns en een plein met het Aura Altaar |
| 6 plots | Elke speler krijgt een eigen plot met poort, naambord, Aura HQ gebouwtje, bomen, bloembakken en een fontein |
| Animaties | Machines met draaiende edelstenen, bewegende lopende banden, knipperende knoppen, nieuwe dingen vallen met een plopje in beeld, "+12" bij de collector en "+5K Aura" bij het ophalen |
| 18 dingen om te kopen | 9 generators, 4 boosters, een 2e lopende band, een hek, lantaarns, toren en een troon in je Aura HQ waar je op kunt zitten |
| Rebirth | Alles opnieuw, maar je verdient elke rebirth +50% meer |
| **Aura farmen** | Druk op 🕺 AURA FARM en sta stil in een pose (Boat Kid, Sky Point, en 2 VIP poses). Je armen en hoofd bewegen echt en er draait een aura-ring onder je voeten. Je Aura Meter loopt vol en dan krijg je **PEAK AURA**: 45 sec 2x Aura. Boven je hoofd verschijnt "+1000 AURA" |
| Aura rollen | 12 aura's van 1 in 1 tot 1 in 10000, gratis roll elke 45 sec, Auto Roll na de eerste rebirth |
| Pity | Na 75 rolls zonder zeldzame aura krijg je er gegarandeerd een |
| Aura Index | Hoe meer aura's je vindt, hoe meer blijvende Luck (tot +70%) |
| Odds | Knop in het roll scherm met de echte kansen in procenten (verplicht van Roblox) |
| Server events | Elke 8 minuten 2 minuten lang: Aura Storm (2x Luck), Golden Hour (2x Aura), Void Night (3x Luck) of Speed Rush (2x snelle generators). De lucht verandert mee |
| Daily quests | Elke dag 3 nieuwe quests, met een extra beloning als je ze alle 3 haalt |
| Playtime gifts | 6 cadeaus na 3, 8, 15, 25, 40 en 60 minuten spelen |
| Boosts | 2x Aura en 2x Luck boosts met een timer bovenaan je scherm |
| Vrienden | Elke vriend in je server geeft +10% Aura (max +30%), met een Invite knop |
| Opslaan | Je voortgang wordt elke minuut en bij weggaan opgeslagen |
| Offline inkomen | Je krijgt 25% van je inkomen terwijl je weg bent (max 4 uur) |
| Dagelijkse beloning | Elke dag claimen, met een streak tot dag 7 |
| Codes | `AURAFARM`, `67`, `SIGMA` |
| Leaderboard | Top 10 Aura farmers van alle servers, op het plein |
| Shop | 4 gamepasses en 4 producten (Robux) |
| Mobiel | Grote knoppen en de UI schaalt mee met het scherm |

## Geld verdienen met Robux

| In de shop | Soort | Wat je krijgt |
|---|---|---|
| VIP | Gamepass | +20% Aura, Aura Meter 50% sneller, 2 extra poses, [VIP] tag |
| 2x Aura | Gamepass | Altijd dubbele Aura |
| Auto Collect | Gamepass | Aura wordt vanzelf opgehaald |
| Fast Generators | Gamepass | Generators 25% sneller |
| Starter Pack | Product, 1 keer | 30 min 2x Aura + de exclusieve Starter Spark aura |
| 2x Aura Boost | Product | 15 min 2x Aura (telt op) |
| Aura Pack / Mega Aura Pack | Product | 10 of 60 minuten van je inkomen |

1. Publiceer de game.
2. Ga naar [create.roblox.com](https://create.roblox.com), open je game en maak de gamepasses aan bij **Monetization → Passes** en de producten bij **Monetization → Developer Products**.
3. Kopieer de nummers (Id's) naar `src/shared/Config.luau` bij `Config.GamePasses` en `Config.DevProducts`. Zolang het Id `0` is, staat er "Soon" in de shop.
4. Vul bij de game de **Content Maturity vragenlijst** in en zeg dat er "paid random items" in zitten (je kunt met gekochte Aura rollen).

**Regels voor kansen (loot boxes):** Roblox ziet rollen als "paid random items", omdat je Aura met Robux kunt kopen. Daarom laat de game altijd de kansen in procenten zien, en worden de Aura Packs verborgen voor spelers in landen met loot box regels (zoals Nederland en België). Luck kun je nooit met Robux kopen, alleen verdienen. Zo blijft de game binnen de regels en wordt hij niet verwijderd.

## Dingen aanpassen

Alle getallen staan in `src/shared/Config.luau` (prijzen, hoe snel, rebirth kosten, codes) en de aura's staan in `src/shared/Auras.luau`. De eerste rebirth duurt ongeveer 40 minuten.

## Mappen

```
src/shared   Config, aura's en getallen-opmaak (server en speler)
src/server   Main script en Services (data, tycoon, aura's, shop, beloningen, map, leaderboard)
src/client   Het scherm van de speler (UI), de poses en alle animaties
```
