// The WiFi link against a fake Commander over real UDP: what it does when
// packets go missing, the stream goes silent or the app is frozen. Slow by
// design: these are the link's own timings.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tesla_dash/panda.dart';
import 'package:tesla_dash/signals.dart';

Uint8List _rec(int id, int bus, List<int> d) {
  final b = ByteData(16)
    ..setUint32(0, id << 21, Endian.little)
    ..setUint32(4, d.length | bus << 4, Endian.little);
  for (var i = 0; i < d.length; i++) {
    b.setUint8(8 + i, d[i]);
  }
  return b.buffer.asUint8List();
}

/// Filters as the wiki has them; an ACK on a new session, and optionally on
/// every hello or command, which the real one may or may not do.
class _Commander {
  late RawDatagramSocket s;
  InternetAddress? peer;
  int peerPort = 0;
  final filter = <int>{};
  final data = <int, List<int>>{}; // an id's payload, all zeros if not here
  bool can = true, session = false, ackHello = false, ackCommands = false;
  bool Function(List<int>)? drop;
  Set<int>? only; // the ids still on the bus, whatever the filter
  int foreign = 0;
  Timer? _t;

  Future<int> start() async {
    s = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    s.listen((e) {
      if (e != RawSocketEvent.read) return;
      final d = s.receive();
      if (d == null) return;
      peer = d.address;
      peerPort = d.port;
      final b = d.data;
      if (drop?.call(b) ?? false) return;
      if (b.length == 5 && b[0] == 0x65) {
        if (!session || ackHello) {
          session = true;
          ack();
        }
        return;
      }
      if (b[0] == 0x18) filter.clear();
      if (b[0] == 0x0f || b[0] == 0x0e) {
        for (var o = 1; o + 2 < b.length; o += 3) {
          final id = b[o + 1] << 8 | b[o + 2];
          b[0] == 0x0f ? filter.add(id) : filter.remove(id);
        }
      }
      if (ackCommands) ack();
    });
    _t = Timer.periodic(const Duration(milliseconds: 20), (_) {
      if (!can || peer == null || !session) return;
      final out = <int>[
        for (final id in kSubscribeIds)
          if (filter.contains(id) && (only?.contains(id) ?? true)) ..._rec(id, 0, data[id] ?? const [0, 0, 0, 0, 0, 0, 0, 0]),
        for (var i = 0; i < foreign; i++) ..._rec(0x7f0, 0, const [1, 2, 3, 4, 5, 6, 7, 8]),
      ];
      if (out.isNotEmpty) s.send(out, peer!, peerPort);
    });
    return s.port;
  }

  void ack() => s.send(_rec(6, 15, const [0]), peer!, peerPort);

  void stop() {
    _t?.cancel();
    s.close();
  }
}

Future<void> _wait(num secs) => Future.delayed(Duration(milliseconds: (secs * 1000).round()));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const slow = Timeout(Duration(seconds: 40));

  test('a steady stream: polled ids come and go, the rest stay', () async {
    final c = _Commander();
    final p = Panda();
    await p.connect('127.0.0.1', await c.start());
    addTearDown(() async {
      await p.disconnect();
      c.stop();
    });
    await _wait(3.2);
    expect(p.wifiLive, isTrue);
    expect(c.filter.containsAll(Panda.alwaysOn), isTrue);
    expect(c.filter.intersection(Panda.polledIds).length, lessThan(8)); // a group or two
  }, timeout: slow);

  // The basic layout's hidden cards: their ids are taken off the filter
  // (streamed and polled alike), stay off as the wheel turns, and come back
  // when shown, a streamed one at once.
  test('skipped ids leave the filter and come back', () async {
    final c = _Commander();
    final p = Panda();
    await p.connect('127.0.0.1', await c.start());
    addTearDown(() async {
      await p.disconnect();
      c.stop();
    });
    await _wait(3.2);
    expect(c.filter, containsAll([0x3F6, 0x101]));
    p.skip = {0x3F6, 0x101, 0x3A1}; // streamed, streamed, polled
    await _wait(9); // a whole round of the wheel
    expect(c.filter.intersection({0x3F6, 0x101, 0x3A1}), isEmpty);
    expect(c.filter.containsAll(Panda.alwaysOn.difference({0x3F6, 0x101})), isTrue);
    p.skip = const {};
    await _wait(0.3);
    expect(c.filter, containsAll([0x3F6, 0x101]));
    // Its add lost, and another card swiped in straight after: said again
    // all the same, so the streamed ids still come back.
    var lost = 0;
    c.drop = (b) => b[0] == 0x0f && b.length == 4 && (b[2] << 8 | b[3]) == 0x3F6 && lost++ == 0;
    p.skip = {0x3F6, 0x101};
    await _wait(1);
    expect(c.filter.intersection({0x3F6, 0x101}), isEmpty);
    p.skip = {0x101};
    p.skip = const {};
    await _wait(2.5);
    expect(lost, 1);
    expect(c.filter, containsAll([0x3F6, 0x101]));
  }, timeout: const Timeout(Duration(seconds: 30)));

  // The steering angle streams at a crawl, for parking; moving, the path
  // lines follow the yaw rate and its 85 frames a second stay off.
  test('the steering angle leaves the stream once moving', () async {
    final c = _Commander();
    final p = Panda();
    await p.connect('127.0.0.1', await c.start());
    addTearDown(() async {
      await p.disconnect();
      c.stop();
    });
    await _wait(3.2);
    expect(c.filter, contains(0x129)); // standing
    c.data[0x257] = const [0, 0, 0, 30, 0x02, 0, 0, 0]; // 30 km/h
    await _wait(1.5);
    expect(c.filter, isNot(contains(0x129)));
    c.data[0x257] = const [0, 0, 0, 5, 0x02, 0, 0, 0]; // 5 km/h
    await _wait(1.5);
    expect(c.filter, contains(0x129));
  }, timeout: slow);

  // With sparse polling off too, a lost remove of a skipped id is sent again.
  test('sparse off: a skipped id whose remove was lost goes after all', () async {
    final c = _Commander();
    final p = Panda()..sparse = false;
    await p.connect('127.0.0.1', await c.start());
    addTearDown(() async {
      await p.disconnect();
      c.stop();
    });
    await _wait(3.2);
    expect(c.filter, contains(0x129));
    var lost = 0;
    c.drop = (b) => b[0] == 0x0e && lost++ == 0;
    p.skip = {0x129};
    await _wait(3);
    expect(lost, greaterThan(1));
    expect(c.filter, isNot(contains(0x129)));
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('a new stream reads everything before the wheel turns', () async {
    final c = _Commander();
    var removes = 0;
    c.drop = (b) {
      if (b[0] == 0x0e) removes++;
      return false;
    };
    final p = Panda();
    await p.connect('127.0.0.1', await c.start());
    addTearDown(() async {
      await p.disconnect();
      c.stop();
    });
    await _wait(1.5); // past the first tick
    expect(removes, 0);
    expect(p.frames.keys.toSet().containsAll(Panda.polledIds), isTrue);
    await _wait(2);
    expect(removes, greaterThan(0));
  }, timeout: slow);

  test('sparse off streams everything, on the fly, and on trims again', () async {
    final c = _Commander();
    final p = Panda()..sparse = false;
    await p.connect('127.0.0.1', await c.start());
    addTearDown(() async {
      await p.disconnect();
      c.stop();
    });
    await _wait(3.5);
    expect(c.filter.containsAll(Panda.polledIds), isTrue);
    p.sparse = true;
    await _wait(1.5);
    expect(c.filter.intersection(Panda.polledIds).length, lessThan(8));
    // A lost add must not leave a group dark while nothing else would notice.
    var lost = 0;
    c.drop = (b) => b[0] == 0x0f && lost++ == 0;
    p.sparse = false;
    await _wait(9.5);
    expect(lost, greaterThan(1));
    expect(c.filter.containsAll(Panda.polledIds), isTrue);
  }, timeout: slow);

  test('a Commander that only ACKs backs off like a silent one', () async {
    final c = _Commander()
      ..can = false
      ..ackHello = true;
    final p = Panda();
    final said = <String>{};
    p.addListener(() => said.add(p.status));
    await p.connect('127.0.0.1', await c.start());
    addTearDown(() async {
      await p.disconnect();
      c.stop();
    });
    await _wait(21);
    expect(said.any((s) => s.contains('retrying in 3s')), isTrue);
  }, timeout: slow);

  test('a list lost while the wheel runs: speed comes back by itself', () async {
    final c = _Commander();
    final p = Panda();
    await p.connect('127.0.0.1', await c.start());
    addTearDown(() async {
      await p.disconnect();
      c.stop();
    });
    await _wait(2.5);
    // A flood triggers a subscribe; its clear arrives, its list does not.
    final subs = p.subscribes;
    var lost = 0;
    c.drop = (b) {
      if (p.subscribes > subs && lost == 0 && b[0] == 0x0f && b.length > 16) {
        lost++;
        return true;
      }
      return false;
    };
    c.foreign = 4;
    await _wait(2.4);
    c.foreign = 0;
    expect(lost, 1);
    await _wait(6);
    expect(c.filter.containsAll(Panda.alwaysOn), isTrue);
    final was = p.frames[0x257]!.count;
    await _wait(0.5);
    expect(p.frames[0x257]!.count, greaterThan(was));
    expect(p.wifiLive, isTrue);
  }, timeout: slow);

  test('ACKs over a silent stream do not pass for a live link', () async {
    final c = _Commander()..ackHello = true;
    final p = Panda();
    await p.connect('127.0.0.1', await c.start());
    addTearDown(() async {
      await p.disconnect();
      c.stop();
    });
    await _wait(2.5);
    expect(p.wifiLive, isTrue);
    c.can = false;
    await _wait(4.5);
    expect(p.wifiLive, isFalse);
  }, timeout: slow);

  test('polled ids alone cannot hold off the reconnect', () async {
    final c = _Commander();
    var asides = 0;
    final p = Panda()..beforeStream = () async => asides++;
    await p.connect('127.0.0.1', await c.start());
    addTearDown(() async {
      await p.disconnect();
      c.stop();
    });
    await _wait(2.5);
    c.only = Panda.polledIds;
    await _wait(14);
    expect(asides, greaterThan(1)); // it went back through the whole start
  }, timeout: slow);

  test('a Commander that ACKs commands cannot start a subscribe storm', () async {
    final c = _Commander()
      ..can = false
      ..ackCommands = true;
    final p = Panda();
    await p.connect('127.0.0.1', await c.start());
    addTearDown(() async {
      await p.disconnect();
      c.stop();
    });
    await _wait(4);
    expect(p.subscribes, lessThan(8));
  }, timeout: slow);

  test('frozen with old frames waiting: a new stream, through the step aside', () async {
    final c = _Commander();
    var asides = 0;
    final p = Panda()..beforeStream = () async => asides++;
    await p.connect('127.0.0.1', await c.start());
    addTearDown(() async {
      await p.disconnect();
      c.stop();
    });
    await _wait(2.5);
    expect(asides, 1);
    for (var i = 0; i < 20; i++) {
      c.s.send(_rec(0x257, 0, const [0, 0, 0, 0, 0, 0, 0, 0]), c.peer!, c.peerPort);
    }
    c.session = false; // it dropped us while we were frozen
    sleep(const Duration(seconds: 9));
    await _wait(1.5);
    expect(asides, 2);
    expect(c.session, isTrue);
  }, timeout: slow);
}
