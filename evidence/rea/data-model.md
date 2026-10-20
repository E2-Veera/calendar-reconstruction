Source: `Contents/Resources/iCal.sdef` (public AppleScript dictionary).

### calendar

| Property | Type | Access | Description |
|---|---|---|---|
| name | text | rw | This is the calendar title. |
| title | text | rw | This is the calendar title. |
| color | RGB color | rw | The calendar color. |
| calendarIdentifier | text | r | An unique calendar key |
| writable | boolean | r | This is the calendar title. |
| description | text | rw | This is the calendar description. |

### event

| Property | Type | Access | Description |
|---|---|---|---|
| description | text | rw | The events notes. |
| start date | date | rw | The event start date. |
| end date | date | rw | The event end date. |
| allday event | boolean | rw | True if the event is an all-day event |
| recurrence | text | rw | The iCalendar (RFC 2445) string describing the event recurrence, if defined |
| sequence | integer | r | The event version. |
| stamp date | date | rw | The event modification date. |
| excluded dates | None | rw | The exception dates. |
| status | event status | rw | The event status. |
| summary | text | rw | This is the event summary. |
| location | text | rw | This is the event location. |
| uid | text | r | An unique event key. |
| url | text | rw | The URL associated to the event. |

- enum `participation status`: unknown, accepted, declined, tentative
- enum `event status`: cancelled, confirmed, none, tentative
- enum `calendar priority`: no priority, low priority, medium priority, high priority
- enum `view type`: day view, week view, month view
