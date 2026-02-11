import 'dart:io';

import 'package:common/util/subnet_calculator.dart';
import 'package:test/test.dart';

void main() {
  group('SubnetCalculator - prefixLengthToMask', () {
    test('Should convert /24 to correct subnet mask', () {
      final mask = SubnetCalculator.prefixLengthToMask(24);
      expect(mask, [255, 255, 255, 0]);
    });

    test('Should convert /23 to correct subnet mask', () {
      final mask = SubnetCalculator.prefixLengthToMask(23);
      expect(mask, [255, 255, 254, 0]);
    });

    test('Should convert /16 to correct subnet mask', () {
      final mask = SubnetCalculator.prefixLengthToMask(16);
      expect(mask, [255, 255, 0, 0]);
    });

    test('Should convert /25 to correct subnet mask', () {
      final mask = SubnetCalculator.prefixLengthToMask(25);
      expect(mask, [255, 255, 255, 128]);
    });

    test('Should convert /28 to correct subnet mask', () {
      final mask = SubnetCalculator.prefixLengthToMask(28);
      expect(mask, [255, 255, 255, 240]);
    });

    test('Should convert /8 to correct subnet mask', () {
      final mask = SubnetCalculator.prefixLengthToMask(8);
      expect(mask, [255, 0, 0, 0]);
    });

    test('Should throw for invalid prefix length', () {
      expect(() => SubnetCalculator.prefixLengthToMask(-1), throwsArgumentError);
      expect(() => SubnetCalculator.prefixLengthToMask(33), throwsArgumentError);
    });
  });

  group('SubnetCalculator - calculateNetworkAddress', () {
    test('Should calculate network address for /24', () {
      final ip = [192, 168, 1, 100];
      final network = SubnetCalculator.calculateNetworkAddress(ip, 24);
      expect(network, [192, 168, 1, 0]);
    });

    test('Should calculate network address for /23', () {
      final ip = [192, 168, 1, 100];
      final network = SubnetCalculator.calculateNetworkAddress(ip, 23);
      expect(network, [192, 168, 0, 0]);
    });

    test('Should calculate network address for /16', () {
      final ip = [192, 168, 1, 100];
      final network = SubnetCalculator.calculateNetworkAddress(ip, 16);
      expect(network, [192, 168, 0, 0]);
    });

    test('Should calculate network address for /25', () {
      final ip = [192, 168, 1, 130];
      final network = SubnetCalculator.calculateNetworkAddress(ip, 25);
      expect(network, [192, 168, 1, 128]);
    });

    test('Should calculate network address for /28', () {
      final ip = [192, 168, 1, 100];
      final network = SubnetCalculator.calculateNetworkAddress(ip, 28);
      expect(network, [192, 168, 1, 96]);
    });
  });

  group('SubnetCalculator - calculateBroadcastAddress', () {
    test('Should calculate broadcast address for /24', () {
      final ip = [192, 168, 1, 100];
      final broadcast = SubnetCalculator.calculateBroadcastAddress(ip, 24);
      expect(broadcast, [192, 168, 1, 255]);
    });

    test('Should calculate broadcast address for /23', () {
      final ip = [192, 168, 1, 100];
      final broadcast = SubnetCalculator.calculateBroadcastAddress(ip, 23);
      expect(broadcast, [192, 168, 1, 255]);
    });

    test('Should calculate broadcast address for /16', () {
      final ip = [192, 168, 1, 100];
      final broadcast = SubnetCalculator.calculateBroadcastAddress(ip, 16);
      expect(broadcast, [192, 168, 255, 255]);
    });

    test('Should calculate broadcast address for /25', () {
      final ip = [192, 168, 1, 130];
      final broadcast = SubnetCalculator.calculateBroadcastAddress(ip, 25);
      expect(broadcast, [192, 168, 1, 255]);
    });

    test('Should calculate broadcast address for /28', () {
      final ip = [192, 168, 1, 100];
      final broadcast = SubnetCalculator.calculateBroadcastAddress(ip, 28);
      expect(broadcast, [192, 168, 1, 111]);
    });
  });

  group('SubnetCalculator - generateIpRange', () {
    test('Should generate correct range for /24 network', () {
      final network = [192, 168, 1, 0];
      final broadcast = [192, 168, 1, 255];
      final currentIp = '192.168.1.100';

      final range = SubnetCalculator.generateIpRange(network, broadcast, currentIp);

      // /24 has 254 usable IPs (256 - 2 for network/broadcast)
      // Minus 1 for current IP = 253
      expect(range.length, 253);
      expect(range.contains('192.168.1.1'), true);
      expect(range.contains('192.168.1.254'), true);
      expect(range.contains('192.168.1.0'), false); // network address
      expect(range.contains('192.168.1.255'), false); // broadcast address
      expect(range.contains('192.168.1.100'), false); // current device IP
    });

    test('Should generate correct range for /23 network', () {
      final network = [192, 168, 0, 0];
      final broadcast = [192, 168, 1, 255];
      final currentIp = '192.168.1.100';

      final range = SubnetCalculator.generateIpRange(network, broadcast, currentIp);

      // /23 has 510 usable IPs (512 - 2 for network/broadcast)
      // Minus 1 for current IP = 509
      expect(range.length, 509);
      expect(range.contains('192.168.0.1'), true);
      expect(range.contains('192.168.0.255'), true);
      expect(range.contains('192.168.1.1'), true);
      expect(range.contains('192.168.1.254'), true);
      expect(range.contains('192.168.0.0'), false); // network address
      expect(range.contains('192.168.1.255'), false); // broadcast address
      expect(range.contains('192.168.1.100'), false); // current device IP
      expect(range.contains('192.168.2.1'), false); // outside range
    });

    test('Should generate correct range for /25 network', () {
      final network = [192, 168, 1, 128];
      final broadcast = [192, 168, 1, 255];
      final currentIp = '192.168.1.130';

      final range = SubnetCalculator.generateIpRange(network, broadcast, currentIp);

      // /25 has 126 usable IPs (128 - 2 for network/broadcast)
      // Minus 1 for current IP = 125
      expect(range.length, 125);
      expect(range.contains('192.168.1.129'), true);
      expect(range.contains('192.168.1.254'), true);
      expect(range.contains('192.168.1.128'), false); // network address
      expect(range.contains('192.168.1.255'), false); // broadcast address
      expect(range.contains('192.168.1.130'), false); // current device IP
      expect(range.contains('192.168.1.127'), false); // outside range
    });

    test('Should generate correct range for /28 network', () {
      final network = [192, 168, 1, 96];
      final broadcast = [192, 168, 1, 111];
      final currentIp = '192.168.1.100';

      final range = SubnetCalculator.generateIpRange(network, broadcast, currentIp);

      // /28 has 14 usable IPs (16 - 2 for network/broadcast)
      // Minus 1 for current IP = 13
      expect(range.length, 13);
      expect(range.contains('192.168.1.97'), true);
      expect(range.contains('192.168.1.110'), true);
      expect(range.contains('192.168.1.96'), false); // network address
      expect(range.contains('192.168.1.111'), false); // broadcast address
      expect(range.contains('192.168.1.100'), false); // current device IP
    });

    test('Should return empty list if range exceeds safety limit', () {
      // /16 network spans 192.168.0.0 to 192.168.255.255 (65536 addresses total)
      // Minus network and broadcast = 65534 usable IPs, which meets the safety limit
      final network = [192, 168, 0, 0];
      final broadcast = [192, 168, 255, 255];
      final currentIp = '192.168.1.100';

      final range = SubnetCalculator.generateIpRange(network, broadcast, currentIp);

      // Should return empty because usable IPs >= maxIpsToScan (65534)
      expect(range.length, 0);
    });

    test('Should handle /32 network (single host)', () {
      final network = [192, 168, 1, 100];
      final broadcast = [192, 168, 1, 100];
      final currentIp = '192.168.1.100';

      final range = SubnetCalculator.generateIpRange(network, broadcast, currentIp);

      // /32 has only 1 IP which is the network/broadcast/current IP
      expect(range.length, 0);
    });

    test('Should handle /31 network (point-to-point)', () {
      final network = [192, 168, 1, 100];
      final broadcast = [192, 168, 1, 101];
      final currentIp = '192.168.1.100';

      final range = SubnetCalculator.generateIpRange(network, broadcast, currentIp);

      // /31 networks are treated as having no usable IPs (traditional behavior)
      // RFC 3021 point-to-point links are not currently supported by this implementation
      expect(range.length, 0);
    });
  });

  group('SubnetCalculator - getIpRange (integration)', () {
    test('Should return empty list for IPv6 addresses', () {
      final address = InternetAddress('::1');
      final range = SubnetCalculator.getIpRange(address);
      expect(range.isEmpty, true);
    });

    test('Should calculate range for IPv4 address (defaults to /24)', () {
      final address = InternetAddress('192.168.1.100');
      final range = SubnetCalculator.getIpRange(address);

      // Default /24 has 254 usable IPs minus current IP = 253
      expect(range.length, 253);
      expect(range.contains('192.168.1.1'), true);
      expect(range.contains('192.168.1.254'), true);
      expect(range.contains('192.168.1.100'), false); // current device IP
    });

    test('Should handle edge cases gracefully', () {
      // Test that it doesn't crash with various IPs
      final addresses = [
        '10.0.0.1',
        '172.16.0.1',
        '192.168.0.1',
        '127.0.0.1',
      ];

      for (final addr in addresses) {
        final address = InternetAddress(addr);
        final range = SubnetCalculator.getIpRange(address);
        expect(range, isA<List<String>>());
      }
    });
  });

  group('SubnetCalculator - getPrefixLength', () {
    test('Should default to /24 for now', () {
      final address = InternetAddress('192.168.1.100');
      final prefixLength = SubnetCalculator.getPrefixLength(address);
      expect(prefixLength, 24);
    });
  });
}
