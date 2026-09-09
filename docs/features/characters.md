# Characters

The Characters tab: browse every character as a list or a grid, search and filter them, and open a detail screen with the character's information and the episodes it appears in.

<table>
  <tr>
    <td><img width="585" height="1266" alt="IMG_9749" src="https://github.com/user-attachments/assets/9f6bc52d-ff78-4035-ad35-fe822b0232eb" /></td>
    <td><img width="585" height="1266" alt="IMG_9750" src="https://github.com/user-attachments/assets/6e96af07-b063-4ed1-8089-e4dc94de4006" /></td>
    <td><img width="585" height="1266" alt="IMG_9751" src="https://github.com/user-attachments/assets/20aa932b-1a08-4515-8a17-8e9530623710" /></td>
    <td><img width="585" height="1266" alt="IMG_9752" src="https://github.com/user-attachments/assets/1776dc76-19a2-4460-aa48-8e337def33d5" /></td>
  </tr>
</table>

## Features

- **List or grid.** The same results as rows with avatar, name, status and species, or as a two-column grid of square pictures with the text over each one. A toolbar button toggles the layout; the grid is the default.
- **Search and filters.** A search bar filters by name as you type. A filter sheet adds status, gender, species and type. Active filters show as chips above the results, each removable on its own, plus "Clear all", which never wipes the search text.
- **Infinite scrolling.** A footer loads the next page when reached, shows a spinner while loading, offers Retry if the page fails, and disappears at the end.
- **Empty states.** "No results" quoting the search and filters, with a "Clear filters" shortcut, and "Couldn't load" with Retry.
- **Character detail.** An edge-to-edge picture under the navigation bar, an info card with status, species, type, gender, origin, location and ID, and the episodes the character appears in. Episodes available on HBO Max get a play button that opens the app or the web player.

## Worth knowing

- Search and filters are server-side: any change reloads page 1 for the new query, so the list is always the complete result. The only local work is highlighting the matched substring in names.
- The search bar debounces 300 ms; the filter sheet edits a draft and applies on Done.
- Pages are cached per filter and per page for 24 hours, the detail for 24 hours and the HBO Max offers for 7 days, all under the `characters` namespace. See [Storage](../storage.md).
- HBO Max links come from JustWatch's unofficial endpoint, matched to episodes by season and number. A JustWatch failure only hides the play buttons.
- The route carries a character id, never a model. The detail screen is exposed without a navigation stack of its own so the Episodes and Locations tabs can push it. See [Architecture](../architecture.md).
- Left out on purpose: prefetching pages ahead of the scroll, pull-to-refresh, and tapping through to an episode.
