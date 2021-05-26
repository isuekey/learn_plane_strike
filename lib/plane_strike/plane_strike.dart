import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:riseup/plane_strike/game_agent.dart';

class PlaneStrike extends StatefulWidget {
  const PlaneStrike({Key? key}) : super(key: key);
  @override
  _PlaneStrikeState createState() => _PlaneStrikeState();
}

enum Orientation {
  up, right, bottom, left
}

class _PlaneStrikeState extends State<PlaneStrike> {
  int _boardSize = 8;
  int _pieceCount = 8;
  late List<Plane> agentAirportList;
  late List<Plane> playerAirportList;
  late PolicyGradientAgent _policyGradientAgent;
  var _agentHits = 0;
  var _playerHits = 0;
  _prepareHiddenPlane(List<Plane> airportList) {
    //  |
    // -*- | |  ---  | |
    //  |  |-*-  |  -*-|
    // --- | |  -*-  | |
    //           |
    //  0    1   2   3
    var rnd = math.Random();
    var orientation = Orientation.values[rnd.nextInt(4)];
    // print('Orientation up ${orientation}');
    var positionX, positionY;
    switch(orientation) {
      case Orientation.up:
      positionX = rnd.nextInt(_boardSize - 2) + 1;
      positionY = rnd.nextInt(_boardSize - 3) + 1;
      airportList[(positionY + 2) * _boardSize + positionX - 1].isHidden = true;
      airportList[(positionY + 2) * _boardSize + positionX].isHidden = true;
      airportList[(positionY + 2) * _boardSize + positionX + 1].isHidden = true;
      break;
      case Orientation.right:
      positionX = rnd.nextInt(_boardSize - 3) + 2;
      positionY = rnd.nextInt(_boardSize - 2) + 1;
      airportList[(positionY - 1) * _boardSize + positionX - 2].isHidden = true;
      airportList[(positionY) * _boardSize + positionX - 2].isHidden = true;
      airportList[(positionY + 1) * _boardSize + positionX - 2].isHidden = true;
      break;
      case Orientation.bottom:
      positionX = rnd.nextInt(_boardSize - 2) + 1;
      positionY = rnd.nextInt(_boardSize - 3) + 2;
      airportList[(positionY - 2) * _boardSize + positionX - 1].isHidden = true;
      airportList[(positionY - 2) * _boardSize + positionX].isHidden = true;
      airportList[(positionY - 2) * _boardSize + positionX + 1].isHidden = true;
      break;
      case Orientation.left:
      default:
      positionX = rnd.nextInt(_boardSize - 3) + 1;
      positionY = rnd.nextInt(_boardSize - 2) + 1;
      airportList[(positionY - 1) * _boardSize + positionX + 2].isHidden = true;
      airportList[(positionY) * _boardSize + positionX + 2].isHidden = true;
      airportList[(positionY + 1) * _boardSize + positionX + 2].isHidden = true;
      break;
    }
    airportList[positionY * _boardSize + positionX - 1].isHidden = true;
    airportList[positionY * _boardSize + positionX].isHidden = true;
    airportList[positionY * _boardSize + positionX + 1].isHidden = true;
    airportList[(positionY - 1) * _boardSize + positionX].isHidden = true;
    airportList[(positionY + 1) * _boardSize + positionX].isHidden = true;
    return airportList;
  }
  List<Plane> _generateEmptyPlaneList(){
    return List<Plane>.generate(
      _boardSize * _boardSize,
      (index) => Plane((index/_boardSize).floor(), index%_boardSize, isShot:false, isHidden:false, index:index),
    );
  }
  void _resetGame() {
    agentAirportList = _generateEmptyPlaneList();
    _prepareHiddenPlane(agentAirportList);
    playerAirportList = _generateEmptyPlaneList();
    _prepareHiddenPlane(playerAirportList);
    _agentHits = 0;
    _playerHits = 0;
    _policyGradientAgent = PolicyGradientAgent(_boardSize);
  }
  @override
  initState(){
    super.initState();
    SystemChrome.setPreferredOrientations(
      [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]
    );
    _resetGame();
  }
  @override
  dispose(){
    super.dispose();
    SystemChrome.setPreferredOrientations(
      [
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]
    );
  }
  @override
  Widget build(BuildContext context) {
    final bodySize = MediaQuery.of(context).size;
    final containerHeight = math.max(256, (bodySize.height - 256)/2);
    final planeHeight = containerHeight/8;
    final size = Size.square(planeHeight);
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                Navigator.of(context).pop();
              }
            );
          },
        ),
        title: const Text('飞机'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              constraints: BoxConstraints.tight(Size.square(containerHeight.toDouble())),
              margin: const EdgeInsets.only(
                left:0, top:10, right:0, bottom:0
              ),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width:2.0)
              ),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                ),
                itemBuilder: (context, index) {
                  var plane = agentAirportList[index];
                  return GestureDetector(
                    onTap:(){
                      setState(
                        (){
                          _playerItemTapped(context, index);
                        }
                      );
                    },
                    child: GridTile(
                      child:_Airport(plane, size:size, player:1, index:index),
                    ),
                  );
                },
                itemCount: _boardSize * _boardSize,
              )
            ),
            Text(
              "电脑的机场，被你击落${_playerHits}架",
              style: new TextStyle(
                fontSize:18, color:Colors.blue, fontWeight:FontWeight.bold
              ),
            ),
            const Divider(
              height:20, thickness:5, indent:20, endIndent:20,
            ),
            Text(
              "我的机场，被击落${_agentHits}架",
              style: new TextStyle(
                fontSize:18, color:Colors.purple, fontWeight:FontWeight.bold
              ),
            ),
            Container(
              constraints: BoxConstraints.tight(Size.square(containerHeight.toDouble())),
              margin: const EdgeInsets.only(
                left:0, top:10, right:0, bottom:0
              ),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width:2.0)
              ),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                ),
                itemBuilder: (context, index) {
                  var plane = playerAirportList[index];
                  return GridTile(
                    child:_Airport(plane, size:size, index:index)
                  );
                },
                itemCount: _boardSize * _boardSize,
              )
            ),
            Padding(
              padding: const EdgeInsets.only(
                left:0, top:0, right:0, bottom:10
              ),
              child: ElevatedButton(
                onPressed:(){
                  _resetGame();
                  setState((){ });
                },
                child: Text('reset game'),
              ),
            )
          ],
        )
      ),
    );
  }

  void _playerItemTapped(context, index) {
    var plane = agentAirportList[index];
    if(plane.isHidden) {
      if(!plane.isShot) {
        _playerHits++;
      }
    }
    plane.isShot = true;

    // agent take action
    int agentAction = _policyGradientAgent.predict(playerAirportList);
    var player = playerAirportList[agentAction];
    if(player.isHidden) {
      if(!player.isShot){
        _agentHits++;
      }
    }
    player.isShot = true;
    String result = '';
    if(_playerHits == _pieceCount && _agentHits == _pieceCount) {
      result = '平局';
      new Timer(const Duration(seconds:2), () {
          _resetGame();
          setState((){});
      });
    } else if(_playerHits == _pieceCount) {
      result = '你赢了';
      new Timer(const Duration(seconds:2), () {
          _resetGame();
          setState((){});
      });
    } else if(_agentHits == _pieceCount) {
      result = '真菜，电脑都比不过。其实很正常';
      new Timer(const Duration(seconds:2), () {
          _resetGame();
          setState((){});
      });
    }
    if (result != '') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result),
          duration: const Duration(seconds:2),
      ));
    }
  }

}

class _Airport extends StatelessWidget {
  final Plane _plane;
  final Size _size;
  int _player = 0;
  int _index = -1;
  _Airport(this._plane, {Key? key, required Size size, int player = 0, int index=-1}) : this._size = size, super(key:key) {
    _player = player;
    _index = index;
  }
  @override
  Widget build(BuildContext context) {
    Color backgroundColor = Colors.white;
    if(_plane.isHidden) {
      // backgroundColor = Colors.teal;
    }
    if(_plane.isShot) {
      backgroundColor = Colors.lime;
      if(_plane.isHidden) {
        backgroundColor = Colors.red.shade800;
      }
    }
    return Container(
      decoration:BoxDecoration(
        color: backgroundColor,
        border: Border.all(
          color: Colors.black,
          width: 0.5,
        )
      ),
      alignment:Alignment.center,
      constraints: BoxConstraints.tight(_size),
    );
  }
}

const _PLANE_STRIKE_ROUTE = '/plane_strike';

final Map<String, WidgetBuilder> planeStrikeRoutes = {
  _PLANE_STRIKE_ROUTE: (BuildContext context) => PlaneStrike(),
};

final planeStrikeConfigs = {
  _PLANE_STRIKE_ROUTE: {
    'title': '飞机',
  },
};
