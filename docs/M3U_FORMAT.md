# M3U Format Support

Tvium accepts UTF-8 extended M3U from a local file or HTTP/HTTPS response. Phase 0 recognizes `#EXTM3U`, `#EXTINF`, `tvg-id`, `tvg-name`, `tvg-logo`, `tvg-chno`, `group-title`, `catchup`, and `catchup-source` while retaining every unknown attribute.

An entry consists of an `#EXTINF` line followed by its stream URI, with comments and blank lines tolerated. The parser preserves the original line, title, URI, and attribute values. It accepts LF/CRLF and reports missing titles/URIs as per-entry warnings.

Classification uses explicit evidence such as Xtream type, group context, file extension, EPG identity, and episode patterns. Ambiguous items become unclassified. Normalization never mutates original values.

Limits for response bytes, line length, entry count, redirects, and timeouts are enforced at the source boundary. Charset detection beyond valid UTF-8 and unusual vendor dialects are compatibility work informed by fictional regression fixtures.
