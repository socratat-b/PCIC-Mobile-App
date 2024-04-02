import 'package:gpx/gpx.dart';

class GpxUtil {
  static Gpx createGpx(List<Wpt> routePoints) {
    var gpx = Gpx();
    var track = Trk();
    var segment = Trkseg();

    segment.trkpts.addAll(routePoints);
    track.trksegs.add(segment);
    gpx.trks.add(track);

    gpx.creator = 'Your App Name';
    gpx.version = '1.1';
    gpx.metadata = Metadata(
      name: 'Generated Route',
      desc: 'Route generated by your app',
      time: DateTime.now(),
    );

    return gpx;
  }
}
