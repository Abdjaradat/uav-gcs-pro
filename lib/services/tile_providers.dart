import 'package:flutter_map/flutter_map.dart';

enum MapType { osm, satellite, topo, dark, light }

class TileProviderConfig {
  final MapType type;
  final String label;
  final TileLayer Function() builder;

  const TileProviderConfig({required this.type, required this.label, required this.builder});
}

TileLayer _osm() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.uavgcs.uav_gcs_pro',
    );

TileLayer _satellite() => TileLayer(
      urlTemplate:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      userAgentPackageName: 'com.uavgcs.uav_gcs_pro',
    );

TileLayer _topo() => TileLayer(
      urlTemplate: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.uavgcs.uav_gcs_pro',
    );

TileLayer _dark() => TileLayer(
      urlTemplate: 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png',
      userAgentPackageName: 'com.uavgcs.uav_gcs_pro',
    );

TileLayer _light() => TileLayer(
      urlTemplate: 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png',
      userAgentPackageName: 'com.uavgcs.uav_gcs_pro',
    );

const List<TileProviderConfig> mapTypes = [
  TileProviderConfig(type: MapType.osm, label: 'OSM Street', builder: _osm),
  TileProviderConfig(type: MapType.satellite, label: 'Satellite', builder: _satellite),
  TileProviderConfig(type: MapType.topo, label: 'Topo Terrain', builder: _topo),
  TileProviderConfig(type: MapType.dark, label: 'Night Dark', builder: _dark),
  TileProviderConfig(type: MapType.light, label: 'Light Street', builder: _light),
];
