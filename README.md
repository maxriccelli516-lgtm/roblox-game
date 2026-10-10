# Aura Farm Tycoon

Een Roblox tycoon waarin je **aura farmt**. Je bouwt Aura Generators die gloeiende orbs maken, die over een lopende band naar je Aura Collector gaan. Met je Aura koop je nieuwe generators en boosters, en bij het Aura Altaar in het midden kun je zeldzame aura's rollen (van "Basic Glow" tot "Void Aura, 1 in 10000").

## In Roblox Studio zetten met Rojo

1. Open deze map in **VS Code**.
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
| 6 plots | Elke speler krijgt automatisch een eigen plot met naambord |
| 18 dingen om te kopen | 9 generators, 4 boosters, een 2e lopende band, muren, lampen, toren en een troon waar je op kunt zitten |
| Rebirth | Alles opnieuw, maar je verdient elke rebirth +50% meer |
| Aura rollen | 12 aura's met kansen van 1 in 1 tot 1 in 10000, gratis roll elke 45 sec |
| Aura effect | Je aura gloeit om je character heen met de naam boven je hoofd |
| Opslaan | Je voortgang wordt elke minuut en bij weggaan opgeslagen |
| Offline inkomen | Je krijgt 25% van je inkomen terwijl je weg bent (max 4 uur) |
| Dagelijkse beloning | Elke dag claimen, met een streak tot dag 7 |
| Codes | `AURAFARM`, `67`, `SIGMA` |
| Leaderboard | Top 10 Aura farmers van alle servers, op het plein |
| Shop | 3 gamepasses en 2 Aura packs (Robux) |
| Mobiel | Grote knoppen en de UI schaalt mee met het scherm |

## Geld verdienen met Robux

1. Publiceer de game.
2. Ga naar [create.roblox.com](https://create.roblox.com), open je game en ga naar **Monetization → Passes**. Maak de gamepasses `2x Aura`, `Auto Collect` en `Fast Generators`.
3. Ga naar **Monetization → Developer Products** en maak `Aura Pack` en `Mega Aura Pack`.
4. Kopieer de nummers (Id's) naar `src/shared/Config.luau` bij `Config.GamePasses` en `Config.DevProducts`. Zolang het Id `0` is, staat er "Soon" in de shop.

De aura's kun je alleen met in-game Aura rollen, niet met Robux. Zo blijft het spel binnen de regels voor loot boxes, die in Nederland en België streng zijn.

## Dingen aanpassen

Alle getallen staan in `src/shared/Config.luau` (prijzen, hoe snel, rebirth kosten, codes) en de aura's staan in `src/shared/Auras.luau`. De eerste rebirth duurt ongeveer 40 minuten.

## Mappen

```
src/shared   Config, aura's en getallen-opmaak (server en speler)
src/server   Main script en Services (data, tycoon, aura's, shop, beloningen, map, leaderboard)
src/client   Het scherm van de speler (UI)
```
