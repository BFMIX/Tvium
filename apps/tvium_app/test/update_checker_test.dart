import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tvium_app/features/updates/update_checker.dart';

void main() {
  test('automatic checks run again after an hour or a clock rollback', () {
    final schedule = UpdateCheckSchedule();
    final first = DateTime.utc(2026, 10, 22, 12);
    expect(schedule.shouldCheck(first), isTrue);
    expect(
      schedule.shouldCheck(first.add(const Duration(minutes: 59))),
      isFalse,
    );
    expect(schedule.shouldCheck(first.add(const Duration(hours: 1))), isTrue);
    expect(
      schedule.shouldCheck(first.subtract(const Duration(days: 1))),
      isTrue,
    );
  });

  test('finds the newest published release after the installed prerelease', () async {
    final checker = UpdateChecker(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(<Object>[
            <String, Object>{
              'tag_name': 'v1.0.0-alpha.8',
              'draft': true,
              'prerelease': true,
              'html_url':
                  'https://github.com/BFMIX/Tvium/releases/tag/v1.0.0-alpha.8',
            },
            <String, Object>{
              'tag_name': 'v1.0.0-alpha.7',
              'draft': false,
              'prerelease': true,
              'html_url':
                  'https://github.com/BFMIX/Tvium/releases/tag/v1.0.0-alpha.7',
            },
          ]),
          200,
        ),
      ),
    );
    addTearDown(checker.close);

    final update = await checker.check('v1.0.0-alpha.6');
    expect(update?.tag, 'v1.0.0-alpha.7');
  });

  test('stable installs ignore prereleases', () async {
    final checker = UpdateChecker(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(<Object>[
            <String, Object>{
              'tag_name': 'v1.1.0-beta.1',
              'draft': false,
              'prerelease': true,
              'html_url':
                  'https://github.com/BFMIX/Tvium/releases/tag/v1.1.0-beta.1',
            },
          ]),
          200,
        ),
      ),
    );
    addTearDown(checker.close);

    expect(await checker.check('v1.0.0'), isNull);
  });

  test('development builds make no update request', () async {
    var requests = 0;
    final checker = UpdateChecker(
      client: MockClient((request) async {
        requests++;
        return http.Response('[]', 200);
      }),
    );
    addTearDown(checker.close);

    expect(await checker.check(''), isNull);
    expect(requests, 0);
  });
}
