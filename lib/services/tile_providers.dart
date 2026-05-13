import 'package:flutter_map/flutter_map.dart';

enum MapType { osm, satellite, terrain, dark, hybrid }

class TileProviderConfig {
  final MapType type;
  final String label;
  final TileLayer Function(bool dark) builder;

  const TileProviderConfig({required this.type, required this.label, required this.builder});
}

TileLayer _osm(bool dark) => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.uavgcs.uav_gcs_pro',
    );

TileLayer _satellite(bool dark) => TileLayer(
      urlTemplate:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      userAgentPackageName: 'com.uavgcs.uav_gcs_pro',
    );

TileLayer _terrain(bool dark) => TileLayer(
      urlTemplate: 'https://tile.thunderforest.com/landscape/{z}/{x}/{y}.png?apikey=YOUR_API_KEY',
      userAgentPackageName: 'com.uavgcs.uav_gcs_pro',
    );

TileLayer _dark(bool dark) => TileLayer(
      urlTemplate: 'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}.png?api_key=YOUR_API_KEY',
      userAgentPackageName: 'com.uavgcs.uav_gcs_pro',
    );

TileLayer _hybrid(bool dark) => TileLayer(
      urlTemplate:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      userAgentPackageName: 'com.uavgcs.uav_gcs_pro',
      additionalOptions: const {
        'layers': 'World_Imagery,World_Transportation,World_Reference_Overlay',
      },
    );

const List<TileProviderConfig> mapTypes = [
  TileProviderConfig(type: MapType.osm, label: 'Street', builder: _osm),
  TileProviderConfig(type: MapType.satellite, label: 'Satellite', builder: _satellite),
  TileProviderConfig(type: MapType.terrain, label: 'Terrain', builder: _terrain),
  TileProviderConfig(type: MapType.dark, label: 'Dark', builder: _dark),
  TileProviderConfig(type: MapType.hybrid, label: 'Hybrid', builder: _hybrid),
];
