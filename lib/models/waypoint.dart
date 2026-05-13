class Waypoint {
  final double x, y;
  double alt;
  bool reached;

  Waypoint({required this.x, required this.y, this.alt = 50, this.reached = false});
}
