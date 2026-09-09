# Episodes

The Episodes tab: the whole catalogue grouped by season, searchable as you type, with the cast of each episode and a shortcut to watch it on HBO Max.


## Features

- **Seasons.** Episodes are grouped under season headers, each row showing the name, the code and the air date (`S01E01 · December 2, 2013`).
- **Instant search.** The search bar narrows the list on every keystroke, matching name, code and air date. Typing `S03` shows a season, `E01` every premiere, `2013` a year.
- **Cast strip.** Each row carries a horizontal strip of the episode's characters. Tapping an avatar opens that character's detail.
- **Watch on HBO Max.** Episodes available on HBO Max get a play button that opens the app or the web player.
- **Empty states.** "No results" quoting the search, and a failed load with Retry.

## Worth knowing

- The whole catalogue is fetched at once by following the API's `next` page pointer, and cached per page for 7 days under the `episodes` namespace. If any page fails with nothing cached the whole load fails, so search never runs over half a catalogue. See [Storage](../storage.md).
- Search is local, case- and diacritic-insensitive, and has no debounce: the catalogue is in memory and a keystroke costs one pass over the rows.
- The HBO Max lookup is the same JustWatch pipeline the Characters feature uses, duplicated on purpose because feature packages never depend on each other. A failure only hides the play buttons.
- Opening a character appends to the navigation path, so Back returns to the row. The destination is supplied by the app, since Episodes never imports Characters. See [Architecture](../architecture.md).
- Left out on purpose: server-side filtering and on-screen pagination.
