class RawDeviceSpecs {
  const RawDeviceSpecs({
    this.totalRamMb = 0,
    this.availRamMb = 0,
    this.cpuCores = 4,
    this.isLowRamDevice = false,
    this.sdkInt = 0,
    this.deviceModel = '',
    this.isMobilePlatform = true,
    this.isWebPlatform = false,
  });

  final int totalRamMb;
  final int availRamMb;
  final int cpuCores;
  final bool isLowRamDevice;
  final int sdkInt;
  final String deviceModel;
  final bool isMobilePlatform;
  final bool isWebPlatform;
}
