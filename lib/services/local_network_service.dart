import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;

import '../controllers/player_controller.dart';
import '../models/phase_three_models.dart';
import '../models/track.dart';

class LocalNetworkService extends ChangeNotifier {
  static const serviceType = '_auralis._tcp';
  HttpServer? _server;
  nsd.Registration? _registration;
  nsd.Discovery? _discovery;
  PlayerController? _player;
  List<Track> Function()? _library;
  final List<RemotePeer> _peers = [];
  String _pairingPin = '000000';
  bool _disposing = false;

  bool get hosting => _server != null;
  int? get port => _server?.port;
  String get pairingPin => _pairingPin;
  List<RemotePeer> get peers => List.unmodifiable(_peers);

  Future<void> startHost({
    required PlayerController player,
    required List<Track> Function() library,
    String deviceName = 'Auralis device',
  }) async {
    if (_server != null) return;
    _player = player;
    _library = library;
    _pairingPin = (100000 + Random.secure().nextInt(900000)).toString();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0, shared: true);
    _server!.listen(_handleRequest);
    try {
      _registration = await nsd.register(
        nsd.Service(
          name: deviceName,
          type: serviceType,
          port: _server!.port,
          txt: {'v': Uint8List.fromList(utf8.encode('1'))},
        ),
      );
    } catch (_) {
      // Direct local links still work if mDNS registration is unavailable.
    }
    if (!_disposing) notifyListeners();
  }

  Future<void> stopHost() async {
    final registration = _registration;
    _registration = null;
    if (registration != null) {
      try {
        await nsd.unregister(registration);
      } catch (_) {}
    }
    await _server?.close(force: true);
    _server = null;
    if (!_disposing) notifyListeners();
  }

  Future<void> discover() async {
    await stopDiscovery();
    try {
      _discovery = await nsd.startDiscovery(
        serviceType,
        ipLookupType: nsd.IpLookupType.v4,
      );
      _discovery!.addListener(_syncPeers);
      _syncPeers();
    } catch (_) {
      _peers.clear();
    }
    if (!_disposing) notifyListeners();
  }

  Future<void> stopDiscovery() async {
    final discovery = _discovery;
    _discovery = null;
    if (discovery != null) {
      discovery.removeListener(_syncPeers);
      try {
        await nsd.stopDiscovery(discovery);
      } catch (_) {}
    }
  }

  void _syncPeers() {
    final services = _discovery?.services ?? const <nsd.Service>[];
    _peers
      ..clear()
      ..addAll(
        services
            .where((service) => service.port != null)
            .map((service) {
              final address = service.addresses
                  ?.where((item) => item.type == InternetAddressType.IPv4)
                  .firstOrNull;
              final host = address?.address ?? service.host ?? '';
              return RemotePeer(
                name: service.name ?? 'Auralis device',
                host: host.replaceAll(RegExp(r'\.$'), ''),
                port: service.port!,
              );
            })
            .where((peer) => peer.host.isNotEmpty),
      );
    if (!_disposing) notifyListeners();
  }

  Future<Map<String, dynamic>> fetchState(RemotePeer peer) =>
      _getJson(peer.baseUri.resolve('/v1/state'));

  Future<List<Map<String, dynamic>>> browse(
    RemotePeer peer, {
    int offset = 0,
    int limit = 100,
  }) async {
    final json = await _getJson(
      peer.baseUri.resolve('/v1/library?offset=$offset&limit=$limit'),
    );
    return (json['tracks'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> control(RemotePeer peer, String action, String pin) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(peer.baseUri.resolve('/v1/control'));
      request.headers.contentType = ContentType.json;
      request.headers.set('x-auralis-pin', pin);
      request.write(jsonEncode({'action': action}));
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Remote rejected command (${response.statusCode})');
      }
    } finally {
      client.close(force: true);
    }
  }

  Uri localLink(String address) => Uri(
    scheme: 'http',
    host: address,
    port: port,
    path: '/v1/connect',
    queryParameters: {'pin': pairingPin},
  );

  Future<void> _handleRequest(HttpRequest request) async {
    request.response.headers.set('x-content-type-options', 'nosniff');
    try {
      if (request.uri.path == '/v1/state') {
        final player = _player!;
        return _json(request, {
          'track': player.current.toSessionJson(),
          'positionMs': player.position.inMilliseconds,
          'playing': player.isPlaying,
        });
      }
      if (request.uri.path == '/v1/library') {
        final all = _library!();
        final offset =
            int.tryParse(request.uri.queryParameters['offset'] ?? '') ?? 0;
        final limit =
            (int.tryParse(request.uri.queryParameters['limit'] ?? '') ?? 100)
                .clamp(1, 500);
        return _json(request, {
          'total': all.length,
          'tracks': all
              .skip(offset)
              .take(limit)
              .map((track) => track.toSessionJson())
              .toList(),
        });
      }
      if (request.uri.path == '/v1/control' && request.method == 'POST') {
        if (request.headers.value('x-auralis-pin') != _pairingPin) {
          request.response.statusCode = HttpStatus.unauthorized;
          return request.response.close();
        }
        final body = await utf8.decoder.bind(request).join();
        final action = (jsonDecode(body) as Map<String, dynamic>)['action'];
        switch (action) {
          case 'playPause':
            _player!.togglePlay();
            break;
          case 'next':
            _player!.next();
            break;
          case 'previous':
            _player!.previous();
            break;
          default:
            request.response.statusCode = HttpStatus.badRequest;
            return request.response.close();
        }
        return _json(request, {'ok': true});
      }
      if (request.uri.path.startsWith('/v1/stream/')) {
        final id = Uri.decodeComponent(request.uri.pathSegments.last);
        final track = _library!().where((item) => item.id == id).firstOrNull;
        final path = track?.filePath;
        if (path == null || !await File(path).exists()) {
          request.response.statusCode = HttpStatus.notFound;
          return request.response.close();
        }
        request.response.headers.contentType = ContentType('audio', 'mpeg');
        await request.response.addStream(File(path).openRead());
        return request.response.close();
      }
      if (request.uri.path == '/v1/connect') {
        request.response.headers.contentType = ContentType.html;
        request.response.write(
          '<h1>Auralis</h1><p>Pairing PIN: $_pairingPin</p>',
        );
        return request.response.close();
      }
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    } catch (error) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(error);
      await request.response.close();
    }
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(uri)).close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      return jsonDecode(await utf8.decoder.bind(response).join())
          as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _json(HttpRequest request, Object body) async {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  @override
  void dispose() {
    _disposing = true;
    unawaited(stopDiscovery());
    unawaited(stopHost());
    super.dispose();
  }
}
