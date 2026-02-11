import 'dart:io';

import 'package:common/model/device.dart';
import 'package:common/src/task/discovery/http_target_discovery.dart';
import 'package:common/util/subnet_calculator.dart';
import 'package:common/util/task_runner.dart';
import 'package:logging/logging.dart';
import 'package:refena/refena.dart';

final _logger = Logger('HttpScanDiscovery');

final httpScanDiscoveryProvider = ViewProvider((ref) {
  return HttpScanDiscoveryService(
    targetedDiscoveryService: ref.accessor(httpTargetDiscoveryProvider),
  );
});

Map<String, TaskRunner> _runners = {};

class HttpScanDiscoveryService {
  final StateAccessor<HttpTargetDiscoveryService> _targetedDiscoveryService;

  HttpScanDiscoveryService({
    required StateAccessor<HttpTargetDiscoveryService> targetedDiscoveryService,
  }) : _targetedDiscoveryService = targetedDiscoveryService;

  Stream<Device> getStream({
    required String networkInterface,
    required int port,
    required bool https,
    InternetAddress? interfaceAddress,
    int? prefixLength,
  }) {
    List<String> ipList;

    // Try to use subnet-aware scanning if prefix length is provided
    if (prefixLength != null) {
      _logger.info('Using subnet-aware scanning for $networkInterface with prefix /$prefixLength');
      ipList = SubnetCalculator.getIpRangeFromString(networkInterface, prefixLength);

      // If subnet calculation returns empty (e.g., too large subnet or error),
      // fall back to /24 scanning
      if (ipList.isEmpty) {
        _logger.warning('Subnet calculation returned empty list, falling back to /24 scan');
        ipList = _generate24SubnetIps(networkInterface);
      }
    } else if (interfaceAddress != null) {
      // Backward compatibility: Try using InternetAddress if provided
      _logger.info('Using subnet-aware scanning for ${interfaceAddress.address}');
      ipList = SubnetCalculator.getIpRange(interfaceAddress);

      if (ipList.isEmpty) {
        _logger.warning('Subnet calculation returned empty list, falling back to /24 scan');
        ipList = _generate24SubnetIps(networkInterface);
      }
    } else {
      // Fallback to traditional /24 scanning for backward compatibility
      _logger.info('No subnet information provided, using traditional /24 scan for $networkInterface');
      ipList = _generate24SubnetIps(networkInterface);
    }

    _logger.info('Scanning ${ipList.length} IP addresses');

    _runners[networkInterface]?.stop();
    _runners[networkInterface] = TaskRunner<Device?>(
      initialTasks: List.generate(
        ipList.length,
        (index) => () async => _doRequest(ipList[index], port, https),
      ),
      concurrency: 50,
    );

    return _runners[networkInterface]!.stream.where((device) => device != null).cast<Device>();
  }

  /// Generates IP list for traditional /24 subnet scanning.
  /// This is the original behavior for backward compatibility.
  List<String> _generate24SubnetIps(String networkInterface) {
    return List.generate(256, (i) => '${networkInterface.split('.').take(3).join('.')}.$i')
        .where((ip) => ip != networkInterface)
        .toList();
  }

  Stream<Device> getFavoriteStream({required List<(String, int)> devices, required bool https}) {
    final runner = TaskRunner<Device?>(
      initialTasks: List.generate(
        devices.length,
        (index) => () async {
          final device = devices[index];
          return _doRequest(device.$1, device.$2, https);
        },
      ),
      concurrency: 50,
    );

    return runner.stream.where((device) => device != null).cast<Device>();
  }

  Future<Device?> _doRequest(String currentIp, int port, bool https) async {
    _logger.fine('Requesting $currentIp');
    final device = await _targetedDiscoveryService.state.discover(
      ip: currentIp,
      port: port,
      https: https,
      onError: null,
    );
    if (device != null) {
      _logger.info('[DISCOVER/TCP] ${device.alias} (${device.ip}, model: ${device.deviceModel})');
    }

    return device;
  }
}
