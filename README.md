# On Ice: A Winter Classic — prototyp 0.1

PC hokej inšpirovaný rokmi 1924–1927. Godot 4.6, GDScript, bez externých závislostí.

## Spustenie

1. Nainštaluj Godot 4.6 (štandardná verzia, .NET nie je potrebný).
2. Importuj súbor `project.godot` do Godotu.
3. Stlač F6 pre otvorenú hlavnú scénu alebo F5 pre celý projekt.
4. Enter spustí tréningový zápas.

Príkazový riadok: `godot --path cesta/k/on-ice`

## Ovládanie

- Šípky: pohyb so zotrvačnosťou a brzdením.
- C s pukom: prihrávka najbližšiemu spoluhráčovi a prevzatie jeho ovládania.
- C bez puku: prepnutie na najbližšieho iného korčuliara k puku.
- Medzerník: strela smerom na súperovu bránku.
- X: vypichnutie puku súperovi v dosahu.
- Escape: pauza / pokračovanie.
- R: nový zápas.

Ovládaš Boston (zlatá farba), útočíš doprava. Montreal ovláda AI.
Aktívny hráč má zlatý kruh a šípku. Brankári automaticky vyrážajú získaný puk.
Zápas trvá tri minúty. Po góle sa obnoví rozostavenie.

## Rozsah a historické východiská

Ide o technický prototyp: 3 korčuliari a brankár za každý tím, jednoduchá AI,
procedurálna dočasná pixelová kresba bez prevzatých log, vonkajšie ihrisko.
Boston a Montreal sú pracovné tímy v zvolenom období. Dresy nie sú historicky
zrekonštruované. Hra zatiaľ nesimuluje konkrétnu sezónu ani presné dobové pravidlá.
Nie sú implementované fauly (Y), tresty, pravidlá prihrávok, striedanie, celé zostavy,
sezóna, manažment, zvuk, ukladanie ani ovládač. Puk sa získava dotykom, góly sa
počítajú pri prechode voľného puku cez otvor bránky na koncovom mantineli.

## Ďalšie kroky

1. Používateľské overenie rýchlosti korčuľovania, odozvy a čitateľnosti puku.
2. Rozdelenie zápasu na samostatné scény hráča, puku, ihriska a rozhrania.
3. Výber konkrétnej sezóny 1924–1927 a zdokumentovanie pravidiel aj výnimiek.
4. Plné zostavy, lepšia AI brankárov, tresty a fauly.
5. Animované sprity v Aseprite, zvuky a hlavné menu.

## Overenie

`godot --headless --path . --script res://scripts/smoke_test.gd`

Overuje vytvorenie tímov, strelu, prihrávku, oba góly, odraz od mantinelu,
získanie puku, pauzu, koniec času a 60 sekúnd simulácie bez neplatných súradníc.
Automatické overenie nehodnotí herný pocit ani vizuálnu kvalitu.

## Súbory

- `project.godot`: konfigurácia projektu.
- `main.tscn`: hlavná scéna.
- `scripts/match.gd`: simulácia, ovládanie, AI a dočasná kresba.
- `scripts/smoke_test.gd`: automatické kontroly.
