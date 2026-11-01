# Pôvodné postavy prototypu 0.3

Každý SVG má plátno 96 × 112 a spoločný bod pod korčuľami (42, 106).
Orientácia kresby je doprava; Godot postavu zrkadlí pri pohybe doľava.
Samostatne kreslené číslo v hre sa nezrkadlí.

Dres má približne oblasť x=25..61, y=34..70. Predný klubový znak je
v oblasti x=42..58, y=46..62. Krk, hlava, rukávy a rukavice sú samostatné
vrstvy kreslené v generátore; hotové SVG možno ďalej upravovať aj ručne.
SVG sú pôvodné pracovné kresby, nie importované klubové logá.

## Úpravy

1. Zmeň farby `KITS` alebo časti kresby v `tools/generate_skaters.py`.
2. V koreňovom priečinku spusti `python3 tools/generate_skaters.py`.
3. Otvor Godot a nechaj ho importovať zmenené SVG.
4. Spusti projekt a over čitateľnosť v pohybe aj z oboch strán.

Generátor prepíše SVG; ručné zmeny treba preniesť späť do generátora,
alebo generátor po ručných úpravách nepoužiť. `idle` je poloha pre sklz,
`00` až `07` sú fázy záberu. Časovanie riadi každý hráč samostatne cez
`phase` a `effort` v `scripts/match.gd`, nie globálny čas.

V ďalšej výtvarnej fáze možno SVG nahradiť exportmi z Aseprite so zachovaním
kotviaceho bodu a rovnakých rozmerov; v načítavaní treba upraviť príponu.
