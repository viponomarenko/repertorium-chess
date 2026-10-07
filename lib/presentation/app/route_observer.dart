import 'package:flutter/widgets.dart';

/// Page-route observer of the root navigator: lets heavy widgets (the
/// engine) pause while another page covers them.
final pageRouteObserver = RouteObserver<PageRoute<dynamic>>();
