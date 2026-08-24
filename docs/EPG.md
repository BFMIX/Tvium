# EPG Plan

Tvium will support separate XMLTV URLs/files and Xtream EPG data. EPG is cached locally, parsed outside the UI isolate, and indexed by channel plus programme time range.

Channel association order is exact `tvg-id`, user mapping, then a high-confidence normalized-name match. Automatic name matches remain reversible and never overwrite source identifiers.

The UI exposes Now, Next, progress, a full guide, details, adjacent days when supplied, and indexed local programme search. Missing data is represented honestly; Tvium does not invent schedules.

Parsing uses bounded streaming XML, rejects unsafe external entity behavior, tolerates bad individual records, and reports sanitized warnings. Retention and refresh windows are configurable later based on measured storage and provider behavior.
