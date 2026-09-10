# tvium_xtream

Tvium's credential-safe Xtream client. It keeps server profiles separate from credentials, maps common response variations, and returns typed failures without exposing connection details.

The current adapter supports account authentication plus Live TV, Movies, and Series catalog summaries. Automated tests use only fictional `.test` endpoints and credentials.

```sh
dart analyze --fatal-infos
flutter test
```
