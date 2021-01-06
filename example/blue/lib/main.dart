import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:esc_pos_bluetooth_forked/esc_pos_bluetooth.dart';
import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:image/image.dart' as printImg;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OKToast(
      child: MaterialApp(
        title: 'Bluetooth demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: MyHomePage(title: 'Bluetooth demo'),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  PrinterBluetoothManager printerManager = PrinterBluetoothManager();
  List<PrinterBluetooth> _devices = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){
      _asyncMethod();
    });
  }

  _asyncMethod() async {
    printerManager.scanResults.listen((devices) async {
      // print('UI: Devices found ${devices.length}');
      setState(() {
        _devices = devices;
      });
    });
  }

  void _startScanDevices() {
    setState(() {
      _devices = [];
    });
    
    printerManager.startScan(Duration(seconds: 4)).catchError((e) {
      print('startScan error -> ${e.message}');
    });
  }

  void _stopScanDevices() {
    printerManager.stopScan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ListView.builder(
          itemCount: _devices.length,
          itemBuilder: (BuildContext context, int index) {
            return InkWell(
              onTap: () => _testPrint(_devices[index]),
              child: Column(
                children: <Widget>[
                  Container(
                    height: 60,
                    padding: EdgeInsets.only(left: 10),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.print),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text(_devices[index].device.name ?? ''),
                              Text(_devices[index].device.address),
                              Text(
                                'Click to print a test receipt',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  Divider(),
                ],
              ),
            );
          }),
      floatingActionButton: StreamBuilder<bool>(
        //stream: printerManager.isScanningStream,
        initialData: false,
        builder: (c, snapshot) {
          // if (snapshot.data) {
          //   return FloatingActionButton(
          //     child: Icon(Icons.stop),
          //     onPressed: _stopScanDevices,
          //     backgroundColor: Colors.red,
          //   );
          // } else {
          return FloatingActionButton(
            child: Icon(Icons.search),
            onPressed: _startScanDevices,
          );
          // }
        },
      ),
    );
  }

  void _testPrint(PrinterBluetooth printer) async {
    PaperSize paper = PaperSize.mm58;
    final profile = await CapabilityProfile.load();
    printerManager.setGenerator(paper, profile);
    printerManager.text(
        'Regular: aA bB cC dD eE fF gG hH iI jJ kK lL mM nN oO pP qQ rR sS tT uU vV wW xX yY zZ');
    printerManager.text('Text size 200%',
        styles: PosStyles(
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ));
    printerManager.cut();
    await printerManager.connectPrinter(printer);
    await printerManager.print();
    await Future.delayed(const Duration(milliseconds: 100), () async {
      //await printerManager.disconnectPrinter();
    });

  }
}
