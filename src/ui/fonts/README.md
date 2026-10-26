Fonts bundled with the game, so it looks the same everywhere and works offline.
All are under the SIL Open Font License 1.1 (license texts in this folder).

| File | Font | Used for |
|---|---|---|
| `koma-kanji.woff2` | **Potta One** (heavy brush), reduced to 王玉将飛車角行金銀桂馬香歩兵龍竜全圭杏と成棋 | Kanji on the pieces and the 将棋 mark in the top bar |
| `archivo-latin.woff2` | **Archivo**, variable (weight 100–900, width 62–125%), `latin` subset | Titles, buttons, piece names (black, 62% width) and body text |
| `archivo-romaji.woff2` | Archivo, reduced to Ō ō Ū ū | Long vowels in romaji (Ginshō, Ryūō) |
| `plex-mono-{500,700}-latin.woff2` | **IBM Plex Mono** 500 and 700, `latin` subset | Labels, player names, move list |
| `plex-mono-{500,700}-romaji.woff2` | IBM Plex Mono, reduced to Ō ō Ū ū | Romaji in labels |

`koma-kanji.woff2` came from the Google Fonts API with the `text=` parameter, which returns a
font holding only the requested characters (`https://fonts.googleapis.com/css2?family=Potta+One&text=…`).
The Archivo and Plex files are the `latin` and `latin-ext` files the Google Fonts API serves for
`family=Archivo:wdth,wght@62..125,100..900` and `family=IBM+Plex+Mono:wght@500;700`; the
`latin-ext` ones were cut down to the four romaji vowels with fontTools (`pyftsubset`).
The license texts come from the `@fontsource/potta-one`, `@fontsource/archivo` and
`@fontsource/ibm-plex-mono` packages.
