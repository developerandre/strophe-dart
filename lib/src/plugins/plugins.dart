import 'package:strophe/src/enums.dart';

abstract class PluginClass {
  StropheConnection connection;
  Function statusChanged;
  PluginClass();
  init(StropheConnection conn);
}
