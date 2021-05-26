import 'package:tflite_flutter/tflite_flutter.dart';

class Plane {
  final int x;
  final int y;
  var isShot;
  var isHidden;
  int? index;
  Plane(this.x, this.y, {bool? this.isShot, bool? this.isHidden, int? this.index});
  isTriedShot(){
    isShot = true;
  }
  operator + (num other) {
    if(this.isShot) {
      if(this.isHidden) {
        return other + 1;
      }
      return other -1;
    } else {
      return other;
    }
  }
}

class PolicyGradientAgent {
  final int _boardSize;
  final _modelFile = 'plane_strike.tflite';
  late Interpreter _interpreter;
  PolicyGradientAgent(this._boardSize) {
    _loadModel();
  }
  void _loadModel() async {
    _interpreter = await Interpreter.fromAsset(_modelFile);
    assert(_interpreter != null);
  }
  int predict(List<Plane> boardState) {
    var input = [
      List.from(boardState.map((item) => (item+0).toDouble())),
    ];
    var _length = _boardSize * _boardSize;
    var output = List.filled(_length, 0).reshape([1, _length]);
    _interpreter.run(input, output);
    double max = output[0][0].toDouble();
    int maxIdx = 0;
    for (int i = 1; i < _length; i++) {
      if (max < output[0][i]) {
        maxIdx = i;
        max = output[0][i];
      }
    }
    // print('maxIdx ${maxIdx}, ${input[0]}');
    return maxIdx;
  }
}
