import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize(
      debug: true // optional: set false to disable printing logs to console
      );
  await Permission.storage.request();

  if (Platform.isAndroid) {
    await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Init.instance.initialize(),
      builder: (context, AsyncSnapshot snapshot) {
        return MaterialApp(
          title: 'Flutter Demo',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch: Colors.blue,
          ),
          home: const MyHomePage(title: 'Flutter Demo Home Page'),
        );

        /*
        // Show splash screen while waiting for app resources to load:
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Splash(),
            debugShowCheckedModeBanner: false,
          );
        } else {
          // Loading is done, return the app:

        }*/
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey webViewKey = GlobalKey();
  late bool _isLoading;
  late bool _permissionReady;

  ReceivePort _port = ReceivePort();
  InAppWebViewController? webViewController;
  InAppWebViewGroupOptions options = InAppWebViewGroupOptions(
      crossPlatform: InAppWebViewOptions(
        javaScriptEnabled: true,
        useOnDownloadStart: true,
        useShouldOverrideUrlLoading: false,
        mediaPlaybackRequiresUserGesture: false,
      ),
      android: AndroidInAppWebViewOptions(
        useHybridComposition: true,
        domStorageEnabled: true,
      ),
      ios: IOSInAppWebViewOptions(allowsInlineMediaPlayback: true));

  late PullToRefreshController pullToRefreshController;
  String url = "";
  final String asdf = "asdfg";
  double progress = 0;
  final urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bindBackgroundIsolate();

    FlutterDownloader.registerCallback(downloadCallback);
    _isLoading = true;
    _permissionReady = false;

    pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(
        color: Colors.yellow,
        backgroundColor: Colors.blue,
      ),
      onRefresh: () async {
        if (Platform.isAndroid) {
          if (webViewController != null) {
            Uri? url = await webViewController?.getUrl();
            String strUrl = url.toString();
            webViewController!.loadUrl(
                urlRequest: URLRequest(url: Uri.parse(strUrl.split('#')[0])));
          }
        } else if (Platform.isIOS) {
          webViewController?.loadUrl(
              urlRequest: URLRequest(url: await webViewController?.getUrl()));
        }
      },
    );
  }

  @override
  void dispose() {
    _unbindBackgroundIsolate();
    super.dispose();
  }

  static void downloadCallback(
      String id, DownloadTaskStatus status, int progress) {
    final SendPort send =
        IsolateNameServer.lookupPortByName('downloader_send_port')!;
    send.send([id, status, progress]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Erdemo??lu Holding Rapor")),
      body: SafeArea(
          child: Column(children: <Widget>[
        Expanded(
          child: Stack(
            children: [
              InAppWebView(
                key: webViewKey,
                initialUrlRequest: URLRequest(
                    url: Uri.parse("https://rapor.merinoshali.com.tr/")),
                initialOptions: options,
                pullToRefreshController: pullToRefreshController,
                onWebViewCreated: (controller) {
                  webViewController = controller;
                },
                onLoadStart: (controller, url) {
                  setState(() {
                    this.url = url.toString();
                    urlController.text = this.url;
                  });
                },
                androidOnPermissionRequest:
                    (controller, origin, resources) async {
                  return PermissionRequestResponse(
                      resources: resources,
                      action: PermissionRequestResponseAction.GRANT);
                },
                onLoadStop: (controller, url) async {
                  pullToRefreshController.endRefreshing();
                  setState(() {
                    this.url = url.toString();
                    urlController.text = this.url;
                  });
                },
                onLoadError: (controller, url, code, message) {
                  pullToRefreshController.endRefreshing();
                },
                onProgressChanged: (controller, progress) {
                  if (progress == 100) {
                    pullToRefreshController.endRefreshing();
                  }
                  setState(() {
                    this.progress = progress / 100;
                    urlController.text = this.url;
                  });
                },
                onUpdateVisitedHistory: (controller, url, androidIsReload) {
                  setState(() {
                    this.url = url.toString();
                    urlController.text = this.url;
                  });
                },
                onConsoleMessage: (controller, consoleMessage) {
                  print("onConsoleMessage -> $consoleMessage");
                },
                onDownloadStart: (controller, url) async {
                  print("=====>DOWNLOAD A BASILDI...");
                  print("=====>??Z??N ??STENECEK...");
                  final status = await Permission.storage.request();
                  print("=====>??Z??N ??STEND??...");
                  if (status.isGranted) {
                    print("=====>??Z??N OKEY...");
                    String _localPath = (await findLocalPath()) +
                        Platform.pathSeparator +
                        'Merinos Raporlar??';
                    print("=====>LOCAL PATH ------ : $_localPath");
                    final savedDir = Directory(_localPath);
                    print("=====>SAVE D??RECTORY... ------ : $_localPath");
                    bool hasExisted = await savedDir.exists();
                    if (!hasExisted) {
                      print("=====>D??RECTORY YOK YARATILACAK... ----");
                      savedDir.create();
                    }

                    print("=====>DOWNLOAD ??ALI??TIRILACAK... -----");
                    final id = await FlutterDownloader.enqueue(
                        url: url.toString(),
                        savedDir: _localPath,
                        showNotification: true,
                        openFileFromNotification: true,
                        saveInPublicStorage: true);
                    print("=====>DOWNLOAD ??ALI??TIRILDI... -----");
                  } else {
                    print('Permission Denied');
                  }
                },
              ),
              progress < 1.0
                  ? LinearProgressIndicator(value: progress)
                  : Container(),
            ],
          ),
        ),
      ])),
      floatingActionButton: SpeedDial(
          icon: Icons.share,
          backgroundColor: Colors.amber,
          children: [
            SpeedDialChild(
              child: Icon(Icons.arrow_downward),
              label: 'Merinos Tufting',
              backgroundColor: Colors.amberAccent,
              onTap: () {
                webViewController!.loadUrl(
                    urlRequest: URLRequest(
                        url: Uri.parse(
                            "https://rapor.merinoshali.com.tr/MerinosTufting/Index")));
              },
            ),
            SpeedDialChild(
              child: Icon(Icons.arrow_upward),
              label: 'Merinos',
              backgroundColor: Colors.amberAccent,
              onTap: () {
                webViewController!.loadUrl(
                    urlRequest: URLRequest(
                        url: Uri.parse(
                            "https://rapor.merinoshali.com.tr/Merinos/Index")));
              },
            ),
            SpeedDialChild(
              child: Icon(Icons.home),
              label: 'Anasayfa',
              backgroundColor: Colors.amberAccent,
              onTap: () {
                webViewController!.loadUrl(
                    urlRequest: URLRequest(
                        url: Uri.parse(
                            "https://rapor.merinoshali.com.tr/Home/Index")));
              },
            ),
          ]),
    );
  }

  void _unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
  }

  void _bindBackgroundIsolate() {
    bool isSuccess = IsolateNameServer.registerPortWithName(
        _port.sendPort, 'downloader_send_port');
    if (!isSuccess) {
      _unbindBackgroundIsolate();
      _bindBackgroundIsolate();
      return;
    }
    _port.listen((dynamic data) {
      String id = data[0];
      DownloadTaskStatus status = data[1];
      int progress = data[2];
      setState(() {});
    });
  }
}

Future<String> findLocalPath() async {
  var externalDir;
  if (Platform.isIOS) {
    // Platform is imported from 'dart:io' package
    externalDir = await getTemporaryDirectory();
  } else if (Platform.isAndroid) {
    externalDir = await getExternalStorageDirectory();
  }
  return externalDir!.path;
}

class Splash extends StatelessWidget {
  const Splash({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool lightMode =
        MediaQuery.of(context).platformBrightness == Brightness.light;
    return Scaffold(
      backgroundColor:
          lightMode ? const Color(0xffe1f5fe) : const Color(0xff042a49),
      body: Center(
          child: lightMode
              ? Image.asset('assets/erdemoglu2.png')
              : Image.asset('assets/erdemoglu2.png')),
    );
  }
}

class Init {
  Init._();

  static final instance = Init._();

  Future initialize() async {
    // This is where you can initialize the resources needed by your app while
    // the splash screen is displayed.  Remove the following example because
    // delaying the user experience is a bad design practice!
    await Future.delayed(const Duration(seconds: 2));
  }
}
