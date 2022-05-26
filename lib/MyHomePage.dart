import 'dart:async';
import 'dart:io';
import 'package:clipall/constants.dart';
import 'package:flutter/cupertino.dart';
import 'package:universal_io/io.dart' as univio;
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:clipall/main.dart';

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  double progressValue = 0;
  bool paused = false;
  bool progressVisible = false;
  Color unpressedCOlor = Colors.blue;
  Color ColorPaste = Colors.blue;
  Color ColorGet = Colors.blue;
  User? loggedInUser = FirebaseAuth.instance.currentUser;
  IconData pauseIcon = Icons.pause_circle_outlined;
  late FirebaseFirestore firestore;
  dynamic uploadTask;
  TextEditingController controller = TextEditingController(),
      labelcontroller = TextEditingController();

  void signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.push(context, MaterialPageRoute(builder: (context) => MyApp()));
  }

  void showSnackBar(Color color, String text, Duration duration) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: color,
      content: Text(text),
      duration: duration,
    ));
  }

  @override
  initState() {
    firestore = FirebaseFirestore.instance;

    loggedInUser = FirebaseAuth.instance.currentUser;
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null) {
        // print('User is currently signed out!');
      } else {
        // print('User is signed in!');
        loggedInUser = user;
      }
    });
  }

  GetText() async {
    DocumentReference ref =
        firestore.collection('users').doc(loggedInUser?.uid);
    DocumentSnapshot snap = await ref.get();
    Map<String, dynamic> data = snap.data() as Map<String, dynamic>;
    labelcontroller.text = data["PastedText"];
    Clipboard.setData(ClipboardData(text: data["PastedText"]));

    if (data["fileLink"].toString() == "true") {
      showSnackBar(
          Colors.greenAccent.shade400,
          "Fetched and copied Url to device Clipboard.Redirecting to download in 2 seconds",
          Duration(seconds: 2));
      Future.delayed(Duration(seconds: 2), () {
        launch(
          data["PastedText"].toString(),
        );
      });
    } else {
      showSnackBar(Colors.greenAccent.shade400,
          "Fetched and copied to device Clipboard", Duration(seconds: 2));
    }
  }

  PasteText() async {
    if (controller.text != '') {
      try {
        CollectionReference users = firestore.collection('users');
        DocumentReference dref =
            firestore.collection('users').doc(loggedInUser?.uid);
        DocumentSnapshot snap = await dref.get();

        Map<String, dynamic>? data = snap.data() as Map<String, dynamic>?;
        if (data == null) {
          await users
              .doc(loggedInUser?.uid)
              .set({
                'PastedText': controller.text,
                'timestamp': DateTime.now(),
                'fileLink': false
              })
              .then((value) => {
                    showSnackBar(
                        Colors.greenAccent.shade400,
                        "Successfully Pasted to Online Clipboard",
                        Duration(seconds: 1, milliseconds: 300))
                  })
              .catchError((error) => {
                    print(
                      "Failed to paste to clipboard: $error",
                    ),
                    showSnackBar(
                        Colors.red.shade400,
                        "Error : Unable to paste content",
                        Duration(seconds: 1, milliseconds: 300))
                  })
              .timeout(Duration(seconds: 10));
        } else {
          //no previous data exists
          if (data["fileLink"].toString() == "true") {
            FirebaseStorage.instance
                .ref(data["StorageRef"].toString())
                .delete();
          }
          await users
              .doc(loggedInUser?.uid)
              .set({
                'PastedText': controller.text,
                'timestamp': DateTime.now(),
                'fileLink': false
              })
              .then((value) => {
                    showSnackBar(
                        Colors.greenAccent.shade400,
                        "Successfully Pasted to Online Clipboard",
                        Duration(seconds: 1, milliseconds: 300))
                  })
              .catchError((error) => {
                    print(
                      "Failed to paste to clipboard: $error",
                    ),
                    showSnackBar(
                        Colors.red.shade400,
                        "Error : Unable to paste content",
                        Duration(seconds: 1, milliseconds: 300))
                  })
              .timeout(Duration(seconds: 10));
        }
      } on TimeoutException catch (e) {
        print('Timeout');
        // TODO

        showSnackBar(
            Colors.red.shade400,
            "Error : Timeout , Please check Internet connectivity",
            Duration(seconds: 1, milliseconds: 300));
      } on Exception catch (e) {
        print("other exception " + e.toString());
      }
    } else {
      showSnackBar(
          Colors.yellow.shade600,
          "Note - Field is empty please enter something to paste",
          Duration(seconds: 1, milliseconds: 500));
    }
  }

  Future<String> GetClipboardText() async {
    ClipboardData? clipData = await Clipboard.getData('text/plain');
    String clipboardText = clipData?.text ?? '';
    print(clipboardText);
    return clipboardText.isEmpty ? '' : clipboardText;
  }

  SetClipboardText() async {
    controller.text = await GetClipboardText();
  }

  void PickNuploadFile() async {
    // UploadTask uploadTask;
    int? fileSize;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false, dialogTitle: "Pick a file to upload Under 20 MB");

    if (univio.Platform.isAndroid) {
      PlatformFile filep = result!.files.first;

      fileSize = filep.size;
      if (fileSize > maxUploadSize) {
        print('Greater than 20 Mb');

        showSnackBar(
            Colors.yellow.shade600,
            "Exceeded File Size Limit! Please Upload files smaller than 20 MB",
            Duration(seconds: 3));
      } else {
        print('${filep.size} is the filesize');
        String fileName = result.files.first.name;
        File file = File(result.files.single.path!);

        FirebaseStorage storage = FirebaseStorage.instance;
        DocumentReference dref =
            firestore.collection('users').doc(loggedInUser?.uid);
        DocumentSnapshot snap = await dref.get();
        Map<String, dynamic> data = snap.data() as Map<String, dynamic>;
        if (data["fileLink"].toString() == "true") {
          storage.ref(data["StorageRef"].toString()).delete();
        }
        Reference ref = storage.ref('uploads/${loggedInUser?.uid}/$fileName');
        uploadTask = ref.putFile(file);

        uploadTask.snapshotEvents.listen((taskSnapshot) {
          switch (taskSnapshot.state) {
            case TaskState.running:

              // ...

              setState(() {
                pauseIcon = Icons.pause_circle_outlined;
                paused = false;
                progressVisible = true;
                progressValue = ((taskSnapshot.bytesTransferred.toDouble() /
                        taskSnapshot.totalBytes.toDouble()) *
                    100);
                if (progressValue == 100) {
                  progressVisible = false;
                }
              });
              break;
            case TaskState.paused:
              print("paused");
              // ...
              break;
            case TaskState.success:
              // ...
              setState(() {
                progressVisible = false;
              });

              break;
            case TaskState.canceled:

              // ...
              break;
            case TaskState.error:
              // ...
              print("error");
              showSnackBar(
                  Colors.redAccent,
                  "Error ! upload task interrupted Please retry",
                  Duration(seconds: 2));
              setState(() {
                progressVisible = false;
              });

              break;
          }
        });
        uploadTask.then((res) {
          saveUrl(res);
        });
      }
    } else {
      Uint8List? fileBytes = result!.files.first.bytes;
      String fileName = result.files.first.name;

      if (fileBytes!.lengthInBytes > maxUploadSize) {
        print('Greater than 20 Mb');

        showSnackBar(
            Colors.yellow.shade600,
            "Exceeded File Size Limit! Please Upload files smaller than 20 MB",
            Duration(seconds: 3));
      } else {
        FirebaseStorage storage = FirebaseStorage.instance;

        DocumentReference dref =
            firestore.collection('users').doc(loggedInUser?.uid);
        DocumentSnapshot snap = await dref.get();
        Map<String, dynamic> data = snap.data() as Map<String, dynamic>;
        if (data["fileLink"].toString() == "true") {
          storage.ref(data["StorageRef"].toString()).delete();
        }
        Reference ref = storage.ref('uploads/${loggedInUser?.uid}/$fileName');

        uploadTask = ref.putData(fileBytes);

        uploadTask.snapshotEvents.listen((taskSnapshot) {
          switch (taskSnapshot.state) {
            case TaskState.running:

              // ...

              setState(() {
                pauseIcon = Icons.pause_circle_outlined;
                paused = false;
                progressVisible = true;
                progressValue = ((taskSnapshot.bytesTransferred.toDouble() /
                        taskSnapshot.totalBytes.toDouble()) *
                    100);
                if (progressValue == 100) {
                  progressVisible = false;
                }
              });
              break;
            case TaskState.paused:
              print("paused");
              // ...
              break;
            case TaskState.success:
              // ...
              setState(() {
                progressVisible = false;
              });

              break;
            case TaskState.canceled:

              // ...
              break;
            case TaskState.error:
              // ...
              print("error");
              showSnackBar(
                  Colors.redAccent,
                  "Error ! upload task interrupted Please retry",
                  Duration(seconds: 2));
              setState(() {
                progressVisible = false;
              });

              break;
          }
        });
        uploadTask.then((res) {
          saveUrl(res);
        });
      }
    }
  }

  void saveUrl(TaskSnapshot ts) async {
    String s = await ts.ref.getDownloadURL();
    print(s);
    CollectionReference users = firestore.collection('users');
    await users.doc(loggedInUser?.uid).set({
      'PastedText': s,
      'timestamp': DateTime.now(),
      'fileLink': true,
      'StorageRef': ts.ref.fullPath
    }).then((value) => {
          print("Successfully Pasted to Clipboard"),
          showSnackBar(
              Colors.greenAccent.shade400,
              "Successfully saved file to online clipboard",
              Duration(seconds: 1, milliseconds: 300))
        });
  }

  void togglePause() {
    if (paused) {
      ResumeTask();
    } else {
      PauseTask();
    }
  }

  void PauseTask() async {
    await uploadTask.pause();
    setState(() {
      pauseIcon = Icons.play_circle_fill;
    });
  }

  void ResumeTask() async {
    await uploadTask.resume();
    setState(() {
      pauseIcon = Icons.pause_circle_outlined;
    });
  }

  void CancelTask() async {
    if (paused) {
      ResumeTask();
    }
    await uploadTask.cancel();
    setState(() {
      progressValue = 0;
      progressVisible = false;
    });
    showSnackBar(Colors.redAccent, "Upload Cancelled", Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        drawer: Drawer(
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  child: FractionallySizedBox(
                    widthFactor: 1,
                    heightFactor: 0.2,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 3),
                            child: Icon(
                              Icons.verified_user,
                              size: 45,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 7,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: Text(
                                loggedInUser!.phoneNumber ??
                                    loggedInUser!.displayName.toString(),
                                style: TextStyle(
                                    fontSize: 20,
                                    overflow: TextOverflow.ellipsis)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  color: Colors.blue,
                ),
              ),
              Expanded(
                flex: 2,
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    child: Text('Instructions'),
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text('How to use this site ?'),
                              content: Container(
                                width: MediaQuery.of(context).size.width * 0.5,
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: RichText(
                                        text: TextSpan(
                                          text:
                                              '1. Signin to clip-all on two devices using the same social account or phone number',
                                        ),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: RichText(
                                        text: TextSpan(
                                            text:
                                                '2. Paste any file or text on the client and retrieve from any device'),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: RichText(
                                        text: TextSpan(
                                            text:
                                                'The files are persisted for 24 hours on the clipboard'),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            );
                          });
                    },
                  ),
                ),
              ),
              Divider(
                thickness: 3,
              ),
              Expanded(
                flex: 2,
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      signOut();
                    },
                    child: Text('Signout'),
                  ),
                ),
              ),
              Divider(
                thickness: 3,
              ),
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 20,
                ),
              )
            ],
          ),
        ),
        // backgroundColor: Colors.black,
        appBar: AppBar(
          title: TabBar(tabs: [
            Row(
              children: [
                Icon(
                  Icons.text_format,
                  size: 50,
                ),
                Text('Text')
              ],
            ),
            Row(
              children: [Icon(Icons.file_copy, size: 50), Text('Files')],
            )
          ]),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              BuildTab1(),
              BuildTab2(),
            ],
          ),
        ),
        // This trailing comma makes auto-formatting nicer for build methods.
      ),
    );
  }

  Center BuildTab1() {
    return Center(
      child: Column(
        // mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Hero(
                tag: 'Logo',
                child: Image.asset(
                  'Images/NameWithLogo.png',
                  fit: BoxFit.scaleDown,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: FractionallySizedBox(
                widthFactor: 0.8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 8,
                      child: TextField(
                        onTap: () {
                          if (controller.text.isEmpty) {
                            SetClipboardText();
                          }
                        },
                        controller: controller,
                        decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(40),
                                    bottomLeft: Radius.circular(40))),
                            hintText: 'Enter Text to Paste to Clipboard'),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Listener(
                        onPointerDown: (PointerDownEvent event) {
                          setState(() {
                            ColorPaste = Colors.blueGrey;
                          });
                        },
                        onPointerUp: (PointerUpEvent event) {
                          setState(() {
                            ColorPaste = unpressedCOlor;
                          });
                        },
                        child: GestureDetector(
                          onTap: () {
                            PasteText();
                          },
                          child: Container(
                            height: 60,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.paste_rounded),
                                // Text(
                                //   'Paste',
                                //   overflow: TextOverflow.visible,
                                //   style: TextStyle(
                                //       fontWeight: FontWeight.bold),
                                // ),
                              ],
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.grey.shade400, width: 1),
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(50),
                                bottomRight: Radius.circular(50),
                              ),
                              color: ColorPaste,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: FractionallySizedBox(
                widthFactor: 0.8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 8,
                      child: TextField(
                        readOnly: true,
                        controller: labelcontroller,
                        decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(40),
                                    bottomLeft: Radius.circular(40))),
                            hintText: 'Clipboard Content'),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Listener(
                        onPointerDown: (PointerDownEvent event) {
                          setState(() {
                            ColorGet = Colors.blueGrey;
                          });
                        },
                        onPointerUp: (PointerUpEvent event) {
                          setState(() {
                            ColorGet = unpressedCOlor;
                          });
                        },
                        child: GestureDetector(
                          onTap: () {
                            GetText();
                          },
                          child: Container(
                            height: 60,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.file_download),
                                // Text(
                                //   'Get',
                                //   style: TextStyle(
                                //       fontWeight: FontWeight.bold),
                                // ),
                              ],
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.grey.shade400, width: 1),
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(50),
                                bottomRight: Radius.circular(50),
                              ),
                              color: ColorGet,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Center BuildTab2() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Hero(
                tag: 'Logo', child: Image.asset('Images/NameWithLogo.png')),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: progressVisible
                  ? FractionallySizedBox(
                      widthFactor: 0.8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 8,
                            child: SliderTheme(
                              data: SliderThemeData(
                                  trackHeight: 15,
                                  thumbShape: RoundSliderThumbShape(
                                      enabledThumbRadius: 0,
                                      disabledThumbRadius: 0),
                                  thumbColor: Colors.transparent,
                                  activeTrackColor: Colors.greenAccent.shade400,
                                  inactiveTrackColor: Colors.blueGrey,
                                  disabledThumbColor: Colors.transparent),
                              child: Slider(
                                value: progressValue,
                                max: 100,
                                min: 0,
                                onChanged: (value) {},
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: IconButton(
                                      onPressed: () {
                                        togglePause();
                                        paused = !paused;
                                      },
                                      icon: Icon(pauseIcon),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: IconButton(
                                        onPressed: () {
                                          CancelTask();
                                        },
                                        icon: Icon(Icons.cancel_outlined)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: FractionallySizedBox(
              widthFactor: 0.8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 2,
                    child: Listener(
                      onPointerDown: (PointerDownEvent event) {
                        setState(() {
                          ColorPaste = Colors.blueGrey;
                        });
                      },
                      onPointerUp: (PointerUpEvent event) {
                        setState(() {
                          ColorPaste = unpressedCOlor;
                        });
                      },
                      child: GestureDetector(
                        onTap: () {
                          PickNuploadFile();
                        },
                        child: Container(
                          height: 50,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.file_upload),
                              Text(
                                'Upload',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Colors.grey.shade400, width: 1),
                            borderRadius: BorderRadius.all(Radius.circular(50)),
                            color: ColorPaste,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: FractionallySizedBox(
              widthFactor: 0.8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Expanded(
                  //   flex: 8,
                  //   child: TextField(
                  //     readOnly: true,
                  //     controller: labelcontroller,
                  //     decoration: InputDecoration(
                  //         border: OutlineInputBorder(
                  //             borderRadius: BorderRadius.only(
                  //                 topLeft: Radius.circular(40),
                  //                 bottomLeft: Radius.circular(40))),
                  //         hintText: 'Clipboard Content'),
                  //   ),
                  // ),
                  Expanded(
                    flex: 2,
                    child: Listener(
                      onPointerDown: (PointerDownEvent event) {
                        setState(() {
                          ColorGet = Colors.blueGrey;
                        });
                      },
                      onPointerUp: (PointerUpEvent event) {
                        setState(() {
                          ColorGet = unpressedCOlor;
                        });
                      },
                      child: GestureDetector(
                        onTap: () {
                          GetText();
                        },
                        child: Container(
                          height: 50,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.file_download),
                              Text(
                                'Download',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Colors.grey.shade400, width: 1),
                            borderRadius: BorderRadius.all(Radius.circular(50)),
                            color: ColorGet,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
