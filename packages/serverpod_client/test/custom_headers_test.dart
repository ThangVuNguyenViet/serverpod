@OnPlatform({
  'browser': Skip('HTTP server tests are not supported in browser'),
})
library;

import 'package:relic/relic.dart';
import 'package:serverpod_client/serverpod_client.dart';
import 'package:test/test.dart';

import 'test_utils/test_http_server.dart';
import 'test_utils/test_serverpod_client.dart';

void main() {
  late Uri httpHost;
  late TestServerpodClient client;
  late Future<void> Function() closeServer;

  group('customHeaders', () {
    late Map<String, List<String>> receivedHeaders;

    setUp(() async {
      receivedHeaders = {};

      closeServer = await TestHttpServer.startServer(
        httpRequestHandler: (request) async {
          // Capture all headers from the request
          for (final entry in request.headers.entries) {
            receivedHeaders[entry.key] = entry.value.toList();
          }
          return Response.ok(
            body: Body.fromString('"ok"', mimeType: MimeType.json),
          );
        },
        onConnected: (host) => httpHost = host,
      );

      client = TestServerpodClient(host: httpHost);
    });

    tearDown(() async => await closeServer());

    test(
      'when customHeaders is set then headers are included in request',
      () async {
        client.customHeaders = {'x-api-key': 'cms_r_test1234'};

        await client.callServerEndpoint<String>('test', 'method', {});

        expect(receivedHeaders['x-api-key'], ['cms_r_test1234']);
      },
    );

    test(
      'when multiple custom headers are set then all are included',
      () async {
        client.customHeaders = {
          'x-api-key': 'cms_r_test1234',
          'x-request-id': 'req-abc-123',
        };

        await client.callServerEndpoint<String>('test', 'method', {});

        expect(receivedHeaders['x-api-key'], ['cms_r_test1234']);
        expect(receivedHeaders['x-request-id'], ['req-abc-123']);
      },
    );

    test(
      'when customHeaders is null then no extra headers are sent',
      () async {
        client.customHeaders = null;

        await client.callServerEndpoint<String>('test', 'method', {});

        expect(receivedHeaders.containsKey('x-api-key'), isFalse);
      },
    );

    test(
      'when customHeaders is set alongside auth then both are sent',
      () async {
        client.customHeaders = {'x-api-key': 'cms_r_test1234'};
        client.authKeyProvider = _StaticAuthKeyProvider('my-auth-token');

        await client.callServerEndpoint<String>('test', 'method', {});

        expect(receivedHeaders['x-api-key'], ['cms_r_test1234']);
        expect(receivedHeaders['authorization'], isNotEmpty);
      },
    );

    test(
      'when customHeaders is updated between calls then new values are used',
      () async {
        client.customHeaders = {'x-api-key': 'key-1'};
        await client.callServerEndpoint<String>('test', 'method', {});
        expect(receivedHeaders['x-api-key'], ['key-1']);

        receivedHeaders.clear();

        client.customHeaders = {'x-api-key': 'key-2'};
        await client.callServerEndpoint<String>('test', 'method', {});
        expect(receivedHeaders['x-api-key'], ['key-2']);
      },
    );
  });
}

class _StaticAuthKeyProvider implements ClientAuthKeyProvider {
  final String _value;
  _StaticAuthKeyProvider(this._value);

  @override
  Future<String?> get authHeaderValue async => 'Basic $_value';
}
