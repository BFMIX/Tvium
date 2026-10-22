# Local QR pairing

Native Tvium apps can receive a source from a phone when the TV has no convenient keyboard. Pairing starts only after the user selects **Add with your phone** on the first-launch screen. The TV binds a temporary HTTP listener to one private IPv4 interface and displays a QR code for that listener. Web builds omit this option because a browser cannot accept inbound local connections.

The QR contains a random 256-bit session token and a local address. It contains no playlist URL or provider credential. The listener closes after one valid submission, cancellation, or ten minutes. The TV shows a confirmation step before it imports the submitted M3U URL or Xtream connection. The phone page and responses use no-store headers and contain no external scripts or analytics.

The phone submits details directly to the TV over local HTTP. This avoids a cloud relay, but the transfer is not encrypted. Pair only on a trusted home network; do not use this flow on shared or public Wi-Fi. A future version can use authenticated encryption or a trusted relay before recommending pairing on untrusted networks.

Synthetic tests cover token routing, expiration, input validation, and TV confirmation. Android TV and other physical-device pairing still need runtime validation, including LAN discovery and firewall behavior.
