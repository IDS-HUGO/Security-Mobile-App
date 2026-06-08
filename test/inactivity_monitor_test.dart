import 'package:appmobile_security/core/services/inactivity_monitor.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InactivityMonitor', () {
    test('dispara onTimeout tras la ventana de inactividad', () {
      fakeAsync((async) {
        var fired = 0;
        final monitor = InactivityMonitor(
          timeout: const Duration(seconds: 15),
          onTimeout: () async => fired++,
        )..start();

        async.elapse(const Duration(seconds: 14));
        expect(fired, 0, reason: 'aun no debe cerrarse antes de los 15 s');

        async.elapse(const Duration(seconds: 1));
        expect(fired, 1, reason: 'debe cerrarse exactamente a los 15 s');

        monitor.dispose();
      });
    });

    test('reset reinicia la cuenta regresiva con cada interaccion', () {
      fakeAsync((async) {
        var fired = 0;
        final monitor = InactivityMonitor(
          timeout: const Duration(seconds: 15),
          onTimeout: () async => fired++,
        )..start();

        async.elapse(const Duration(seconds: 10));
        monitor.reset(); // el usuario interactua a los 10 s

        async.elapse(const Duration(seconds: 10)); // 10 s desde el reset
        expect(fired, 0, reason: 'el reset debio reiniciar el contador');

        async.elapse(const Duration(seconds: 5)); // total 15 s desde el reset
        expect(fired, 1);

        monitor.dispose();
      });
    });

    test('onTick reporta el tiempo restante hacia cero', () {
      fakeAsync((async) {
        final ticks = <int>[];
        final monitor = InactivityMonitor(
          timeout: const Duration(seconds: 5),
          onTimeout: () async {},
          onTick: (remaining) => ticks.add(remaining.inSeconds),
        )..start();

        expect(ticks.first, 5, reason: 'start reporta la ventana completa');

        async.elapse(const Duration(seconds: 5));
        expect(ticks.last, 0, reason: 'al final el restante llega a 0');

        monitor.dispose();
      });
    });

    test('no dispara onTimeout despues de dispose', () {
      fakeAsync((async) {
        var fired = 0;
        InactivityMonitor(
          timeout: const Duration(seconds: 15),
          onTimeout: () async => fired++,
        )
          ..start()
          ..dispose();

        async.elapse(const Duration(seconds: 30));
        expect(fired, 0);
      });
    });
  });
}
