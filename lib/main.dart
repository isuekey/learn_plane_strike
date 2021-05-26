import 'package:flutter/material.dart';
import 'package:riseup/plane_strike/plane_strike.dart' as planeStrike;

void main() {
  runApp(MyApp());
}

final Map<String, WidgetBuilder> _homeRoutes = {
  '/': (BuildContext context) => MyHomePage(title: '我的Flutter应用'),
};

final _appRoutes = {
  ..._homeRoutes,
  ...planeStrike.planeStrikeRoutes,
};
final _appConfigs = {
  ...planeStrike.planeStrikeConfigs,
};
final _appItems = List.from(_appConfigs.keys.map((key){
      var config = {
        ...?_appConfigs[key],
        'key': key,
      };
      return config;
}));

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IsueKey',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      initialRoute:'/',
      routes: _appRoutes,
    );
  }
}

class MyHomePage extends StatelessWidget {
  final title;
  const MyHomePage({Key? key, String? this.title}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return DefaultTabController (
      length:3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        bottomNavigationBar: Container(
          color: Colors.green,
          child:TabBar(
            tabs:[
              Tab(
                icon: Icon(Icons.directions_car),
                text: '首页',
              ),
              Tab(
                icon: Icon(Icons.directions_transit),
                text: 'mimi',
              ),
              Tab(icon: Icon(Icons.directions_bike)),
            ],
          ),
        ),
        body: Container(
          color: Colors.white,
          child:TabBarView (
            children:[
              HomeGrid(),
              Icon(Icons.directions_transit),
              Icon(Icons.directions_bike),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
      ),
      itemBuilder: (BuildContext context, int index) {
        var itemConfig = _appItems[index];
        return GestureDetector(
          onTap: () {
            print('will print the key ${itemConfig["key"]}');
            Navigator.of(context).pushNamed(itemConfig['key']);
          },
          child: Container(
            height:56.0,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.green,
                width:4,
              ),
            ),
            child: Center(
              child: Text(itemConfig['title']),
            ),
          ),
        );
      },
      itemCount: _appItems.length,
    );
  }
}

