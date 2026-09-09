# Locations

The Locations tab: travel through every location on a stepped carousel, read about the one in the centre, and jump to any of its residents.

<table>
  <tr>
    <td><img width="585" height="1266" alt="IMG_9756" src="https://github.com/user-attachments/assets/2a06ae08-8de9-43cb-86be-b2f5525e73d6" /></td>
    <td><img width="585" height="1266" alt="IMG_9757" src="https://github.com/user-attachments/assets/d1e423cb-1704-4496-9b3b-7ab8c0c7d7ad" /></td>
    <td><img width="585" height="1266" alt="IMG_9758" src="https://github.com/user-attachments/assets/39b259cd-09f5-48c6-ba88-4bef74510d9c" /></td>
  </tr>
</table>

## Features

- **Carousel.** A row of large circles, one per location, that snaps one location at a time to the centre of the screen. Circles grow and brighten as they reach the centre, and tapping one centres it. The carousel design is inspired on the show's "Central Finite Curve" concept.
- **Location card.** Under the carousel, a card describes the centred location: its type and dimension when the API has them, and its residents with avatar, name and status. Tapping a resident opens the character detail.
- **Pagination.** The last stop of the carousel is a spinner that loads the next page when scrolled to, or a Retry if the page failed.
- **Empty states.** A failed first page with Retry, and an empty catalogue.

## Worth knowing

- The centred location is the selected one, whether it got there by scrolling or by a tap. The selection is a location id held by the view model, so the card, the auto-selection of the first location and a reload all agree.
- Residents use a small entity of their own rather than the Characters feature's, since some locations have hundreds of residents and Locations never imports Characters.
- Pages are cached for 7 days under the `locations` namespace. See [Storage](../storage.md).
- Opening a resident appends to the navigation path, so Back returns to the card. The destination is supplied by the app. See [Architecture](../architecture.md).
- Left out on purpose: search or filters, a per-type icon on each circle, and an index to jump across the carousel.
