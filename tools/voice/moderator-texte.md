# Moderator-Texte zum Einsprechen (z.B. ElevenLabs)

Jeder Block unten = **eine Aufnahme**. Die Reihenfolge der Zeilen bitte nicht ändern – danach
werden die Aufnahmen wie die Fragen an den Pausen zerlegt, Zeile für Zeile, und die Teile
bekommen die Schlüssel, die unter jedem Block stehen.

Quelle: `ABCSpiel/Core/ModeratorScript.swift` – ändert sich dort ein Text, diese Liste nachführen.

Hinweise:

- **Bausteine** (Regle, Pünkt, Zahle) werden im Spiel aneinandergehängt, z.B.
  «Du hesch …» + «föifevierzg» + «… Sekunde.». Sie sollten darum klingen wie **mitten im Satz**:
  Stimme oben lassen, nicht abschliessen. Die «…» im Text helfen ElevenLabs dabei.
- Die drei Referenz-Sätze für den Stimm-Klon fehlen absichtlich – die braucht es nur für das lokale Modell.
- Die Fragen sind nicht dabei, siehe `split_fragen.py`.
- Total 91 Clips in 9 Aufnahmen.

## 1. Begrüessig (6)

```
Hoi zäme und härzlich willkomme bim ABC!
Grüezi mitenand – es isch Ziit für s'ABC!
Sali! Schön, bisch wieder debii bim ABC.
Guete Morge! Bisch parat für e Rundi ABC?
Hallo, da isch de Ruedi – und das isch s'ABC!
Grüezi mitenand! Ich bi de Ruedi, din Moderator bim ABC.
```

Schlüssel: greeting-1, greeting-2, greeting-3, greeting-4, greeting-5, probe

## 2. Regle (6)

```
Ich stell dir Frage – und all Antworte fanged mit em gliiche Buechstabe aa.
Du hesch …
… Sekunde.
Mit …
… richtige Antworte hesch gwunne.
Wenn d'öppis nid weisch, säg eifach «wiiter».
```

Schlüssel: rules-intro, rules-seconds-pre, rules-seconds-post, rules-target-pre, rules-target-post, rules-pass

## 3. Buechstabe aasäge (3)

```
Din Buechstabe isch:
Hüt spilsch mit em
Und de Buechstabe isch …
```

Schlüssel: announce-1, announce-2, announce-3

## 4. Buechstabe (23)

```
A. A wie Aarau!
Be. Be wie Bärn!
Ze. Ze wie Chur!
De. De wie Davos!
E. E wie Emme!
Eff. Eff wie Fribourg!
Ge. Ge wie Glarus!
Ha. Ha wie Herisau!
I. I wie Interlake!
Jott. Jott wie Jura!
Ka. Ka wie Kreuzlinge!
Ell. Ell wie Luzärn!
Emm. Emm wie Murte!
Enn. Enn wie Nöieburg!
O. O wie Olte!
Pe. Pe wie Pilatus!
Err. Err wie Rhy!
Ess. Ess wie Säntis!
Te. Te wie Thun!
U. U wie Uri!
Fau. Fau wie Vevey!
We. We wie Winterthur!
Zett. Zett wie Zug!
```

Schlüssel: letter-a, letter-b, letter-c, letter-d, letter-e, letter-f, letter-g, letter-h, letter-i, letter-j,
letter-k, letter-l, letter-m, letter-n, letter-o, letter-p, letter-r, letter-s, letter-t, letter-u, letter-v,
letter-w, letter-z

## 5. Countdown (3)

```
Achtung …
fertig …
los!
```

Schlüssel: countdown-1, countdown-2, countdown-3

## 6. Schluss (4)

```
Und Stopp – d'Ziit isch um!
Piiip – fertig!
Stopp! Das wärs gsi.
Wow – mir sind d'Frage usgange!
```

Schlüssel: timeup-1, timeup-2, timeup-3, outofquestions

## 7. Urteil (10)

```
Hoppla – das isch hüt nid din Buechstabe gsi. Nomal probiere!
Gäll, da hets di chli verwütscht. Grad nomal!
Nid schlächt, aber da liit no meh drin!
Es guets Fundament – s'nächscht Mal gits meh!
Knapp verbii – so nöch!
Oh nei, es hät ganz knapp nid glanget!
Gwunne! Gratuliere, du hesch s'ABC gschafft!
Bravo, das isch e Siig. Du chasch stolz sii!
Wahnsinn! Du bisch e richtigi ABC-Legände!
Sone Resultat gits nid all Tag – Huet ab!
```

Schlüssel: verdict-low-1, verdict-low-2, verdict-mid-1, verdict-mid-2, verdict-close-1, verdict-close-2,
verdict-win-1, verdict-win-2, verdict-legend-1, verdict-legend-2

## 8. Pünkt (2)

```
… Pünkt.
Ein Punkt.
```

Schlüssel: score-points, score-one

## 9. Zahle (34)

Wie mitten im Satz sprechen («Du hesch … föifevierzg … Sekunde»), nicht wie beim Abzählen.

```
null
eis
zwei
drü
vier
föif
sächs
sibe
acht
nüün
zäh
elf
zwölf
drizäh
vierzäh
füfzäh
sächzäh
sibzäh
achtzäh
nüünzäh
zwänzg
einezwänzg
zweiezwänzg
drüezwänzg
vierezwänzg
föifezwänzg
sächsezwänzg
sibenezwänzg
achtezwänzg
nüünezwänzg
drissg
föifevierzg
sächzg
nünzg
```

Schlüssel: zahl-0 … zahl-30, zahl-45, zahl-60, zahl-90
