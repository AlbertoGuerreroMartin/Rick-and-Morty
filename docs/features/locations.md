# Locations

The Locations tab: travel through every location on a stepped carousel, read about the one in the centre, and jump to any of its residents.

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
