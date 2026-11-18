# Devices

Climber Time runs on every Connect IQ watch with a screen of at least 260 px in each direction and
at least 64 colours: 69 products, 54 AMOLED and 15 MIP (since 0.2.0, #56; 0.1.0 needed 360 px). The
holds and the climber need that resolution, and the routes need colour, so smaller screens are left
out, and so are 1-bit and 4-bit screens. Watches below Connect IQ 5 are left out too (Venu, Venu
Mercedes-Benz Collection, D2 Air, and the older 260 and 280 px MIP watches: fēnix 6, Forerunner 945,
vívoactive 4 and others).

On MIP screens the wall has no panel, since the slate rounds to navy on 64 colours, and with the wrist
down the whole face stays on, redrawn once a minute: MIP cannot burn in, so it needs no always-on
scene ([`DESIGN.md`](../design/DESIGN.md) §5.1, §13.2).

| Screen | Products |
|---|---|
| Round 260, MIP | fēnix 7 / quatix 7, fēnix 7 Pro and 7 Pro Solar (no Wi-Fi), fēnix 8 Solar 47 mm, fēnix 9 Pro Solar 47 mm, Forerunner 255 and 255 Music, Forerunner 955 / Solar |
| Round 280, MIP | fēnix 7X / tactix 7 / quatix 7X Solar / Enduro 2, fēnix 7X Pro and 7X Pro Solar (no Wi-Fi), fēnix 8 Solar 51 mm / tactix 8 Solar 51 mm, fēnix 9 Pro Solar 51 mm, Enduro 3, Enduro 4 |
| Round 360 | Venu 2S, Forerunner 265s |
| Round 390 | epix Pro (Gen 2) 42 mm, MARQ (Gen 2) and Aviator, Venu 3S, Venu 4 41 mm, vívoactive 5 and 6, Approach S50, Approach S70 42 mm, Descent G2, Descent Mk3 / Mk3i 43 mm, Forerunner 70, Forerunner 165 and 165 Music, Forerunner 170 and 170 Music, Forerunner 570 42 mm, Instinct 3 AMOLED 45 mm, Instinct Crossover AMOLED |
| Round 416 | epix (Gen 2) / quatix 7 Sapphire, epix Pro (Gen 2) 47 mm / quatix 7 Pro, fēnix 8 43 mm, fēnix 9 43 mm and 9 Pro 43 mm, fēnix E, Venu 2 and 2 Plus, Approach S72 43 mm, D2 Air X10, D2 Mach 1, Forerunner 265, Instinct 3 AMOLED 50 mm |
| Round 454 | epix Pro (Gen 2) 51 mm / D2 Mach 1 Pro / tactix 7 AMOLED, fēnix 8 47/51 mm / tactix 8 / quatix 8, fēnix 8 Pro 47/51 mm / MicroLED / quatix 8 Pro, fēnix 9 47/51 mm and 9 Pro 47 mm, MARQ (Gen 3), Venu 3, Venu 4 45 mm / D2 Air X15, Approach S70 47 mm, Approach S72 47 mm, D2 Mach 2 and 2 Pro, Descent Mk3i 51 mm, Forerunner 570 47 mm, Forerunner 965, Forerunner 970 |
| Round 466 | fēnix 9 Pro 51 mm |
| Rectangular 320 × 360 | Venu Sq 2 and Sq 2 Music |
| Rectangular 448 × 486 | Venu X1 |

Every screen in the table has its own pair of bitmap fonts ([fonts](fonts.md)), and every product
its own launcher icon ([graphics](graphics.md#launcher-icon)). The products themselves are listed
in [`manifest.xml`](../manifest.xml).
