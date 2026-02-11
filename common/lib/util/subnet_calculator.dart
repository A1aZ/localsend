import 'dart:io';

import 'package:logging/logging.dart';

final _logger = Logger('SubnetCalculator');

/// Utility class for calculating subnet ranges and generating IP addresses to scan.
///
/// This class handles subnet mask calculations for various CIDR prefix lengths
/// and generates the list of usable IP addresses within a subnet.
class SubnetCalculator {
  /// Maximum number of IPs to scan to prevent excessive network load.
  /// This is a safety limit for very large subnets like /16 (65,534 hosts).
  static const int maxIpsToScan = 65534;

  /// Returns a list of all usable IP addresses in the subnet for the given address.
  ///
  /// For IPv4, this attempts to determine the prefix length from the InternetAddress
  /// or estimates it from common patterns. It then calculates the network and
  /// broadcast addresses and generates all IPs in between (excluding network,
  /// broadcast, and the current device's IP).
  ///
  /// For IPv6, returns an empty list (not yet supported for scanning).
  ///
  /// Returns an empty list if:
  /// - The address is IPv6
  /// - The calculated range exceeds maxIpsToScan
  /// - An error occurs during calculation
  static List<String> getIpRange(InternetAddress address, [int? prefixLength]) {
    try {
      // Only support IPv4 for now
      if (address.type != InternetAddressType.IPv4) {
        _logger.fine('IPv6 addresses not supported for subnet scanning: ${address.address}');
        return [];
      }

      final ipBytes = address.rawAddress;
      final effectivePrefixLength = prefixLength ?? getPrefixLength(address);

      _logger.info('Calculating subnet range for ${address.address} with prefix length /$effectivePrefixLength');

      final networkAddr = calculateNetworkAddress(ipBytes, effectivePrefixLength);
      final broadcastAddr = calculateBroadcastAddress(ipBytes, effectivePrefixLength);

      final ipRange = generateIpRange(networkAddr, broadcastAddr, address.address);

      _logger.info('Generated ${ipRange.length} IP addresses to scan (prefix: /$effectivePrefixLength)');
      return ipRange;
    } catch (e, stackTrace) {
      _logger.warning('Error calculating IP range for ${address.address}', e, stackTrace);
      return [];
    }
  }

  /// Returns a list of all usable IP addresses in the subnet for the given IP string.
  ///
  /// This is a convenience method that parses the IP string into an InternetAddress
  /// and then calls [getIpRange].
  ///
  /// The [prefixLength] parameter specifies the CIDR prefix length (e.g., 24 for /24).
  /// If not provided, defaults to 24 (most common for home/office networks).
  static List<String> getIpRangeFromString(String ipAddress, [int prefixLength = 24]) {
    try {
      final address = InternetAddress(ipAddress);
      return getIpRange(address, prefixLength);
    } catch (e, stackTrace) {
      _logger.warning('Error parsing IP address $ipAddress', e, stackTrace);
      return [];
    }
  }

  /// Gets the prefix length from the InternetAddress or estimates from common patterns.
  ///
  /// Note: Dart's InternetAddress doesn't directly expose the subnet mask or prefix length.
  /// This method attempts to extract it if available, otherwise defaults to /24.
  ///
  /// In the future, this could be enhanced by:
  /// - Parsing the subnet mask from NetworkInterface if available
  /// - Using platform-specific APIs to get actual subnet information
  /// - Allowing manual override through configuration
  static int getPrefixLength(InternetAddress address) {
    // TODO: In the future, extract actual prefix length from NetworkInterface
    // For now, we'll need to pass it from the caller or default to /24

    // Default to /24 (most common for home/small office networks)
    return 24;
  }

  /// Calculates the network address from an IP address and prefix length.
  ///
  /// The network address is calculated by applying a subnet mask derived from
  /// the prefix length via bitwise AND operation on each byte of the IP address.
  ///
  /// Example: 192.168.1.100 with /23 -> 192.168.0.0
  static List<int> calculateNetworkAddress(List<int> ipBytes, int prefixLength) {
    final mask = prefixLengthToMask(prefixLength);
    return List.generate(4, (i) => ipBytes[i] & mask[i]);
  }

  /// Calculates the broadcast address from an IP address and prefix length.
  ///
  /// The broadcast address is calculated by applying the inverted subnet mask
  /// via bitwise OR operation on each byte of the IP address.
  ///
  /// Example: 192.168.1.100 with /23 -> 192.168.1.255
  static List<int> calculateBroadcastAddress(List<int> ipBytes, int prefixLength) {
    final mask = prefixLengthToMask(prefixLength);
    return List.generate(4, (i) => ipBytes[i] | (~mask[i] & 0xFF));
  }

  /// Converts a CIDR prefix length to a subnet mask in byte form.
  ///
  /// Examples:
  /// - /24 -> [255, 255, 255, 0]
  /// - /23 -> [255, 255, 254, 0]
  /// - /16 -> [255, 255, 0, 0]
  static List<int> prefixLengthToMask(int prefixLength) {
    if (prefixLength < 0 || prefixLength > 32) {
      throw ArgumentError('Prefix length must be between 0 and 32, got $prefixLength');
    }

    final mask = List<int>.filled(4, 0);
    for (int i = 0; i < prefixLength; i++) {
      mask[i ~/ 8] |= 1 << (7 - (i % 8));
    }
    return mask;
  }

  /// Generates all usable IP addresses between network and broadcast addresses.
  ///
  /// This excludes:
  /// - The network address (first IP in range)
  /// - The broadcast address (last IP in range)
  /// - The current device's IP address
  ///
  /// Returns an empty list if the range exceeds maxIpsToScan for safety.
  static List<String> generateIpRange(
    List<int> networkAddr,
    List<int> broadcastAddr,
    String currentIp,
  ) {
    // Calculate total number of addresses in range
    int totalAddresses = 0;
    for (int i = 0; i < 4; i++) {
      totalAddresses = totalAddresses * 256 + (broadcastAddr[i] - networkAddr[i]);
    }
    totalAddresses += 1; // Include the last address

    // Subtract network and broadcast addresses
    final usableAddresses = totalAddresses - 2;

    if (usableAddresses <= 0) {
      _logger.warning('No usable addresses in subnet range');
      return [];
    }

    if (usableAddresses >= maxIpsToScan) {
      _logger.warning(
        'Subnet has $usableAddresses usable addresses, exceeding safety limit of $maxIpsToScan. '
        'Skipping scan to prevent network overload.',
      );
      return [];
    }

    final result = <String>[];

    // Generate IPs by incrementing from network address + 1 to broadcast address - 1
    final current = List<int>.from(networkAddr);

    // Increment past network address
    _incrementIp(current);

    while (_compareIp(current, broadcastAddr) < 0) {
      final ipStr = current.join('.');
      if (ipStr != currentIp) {
        result.add(ipStr);
      }
      _incrementIp(current);
    }

    return result;
  }

  /// Increments an IP address by one.
  static void _incrementIp(List<int> ip) {
    for (int i = 3; i >= 0; i--) {
      if (ip[i] < 255) {
        ip[i]++;
        break;
      }
      ip[i] = 0;
    }
  }

  /// Compares two IP addresses.
  /// Returns negative if a < b, 0 if a == b, positive if a > b.
  static int _compareIp(List<int> a, List<int> b) {
    for (int i = 0; i < 4; i++) {
      if (a[i] != b[i]) {
        return a[i] - b[i];
      }
    }
    return 0;
  }
}
