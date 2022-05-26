import 'package:clipall/authprocess.dart';
import 'package:clipall/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:clipall/MyHomePage.dart';

//Splashscreen for the application

class Splash extends StatefulWidget {
  const Splash({Key? key}) : super(key: key);

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with TickerProviderStateMixin {
  late AnimationController controller;

  @override
  dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  initState() {
    User? user = FirebaseAuth.instance.currentUser;
    controller = AnimationController(
        vsync: this, duration: Duration(seconds: 1), upperBound: 1);
    controller.forward(from: 0);
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // print('completed splash');

        if (user != null) {
          Navigator.push(
              context, MaterialPageRoute(builder: (context) => MyHomePage()));
        } else {
          Navigator.push(
              context, MaterialPageRoute(builder: (context) => AuthScreen()));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Hero(
          tag: 'Logo',
          child: Image.asset(
            'Images/NameWithLogo.png',
            opacity: controller,
          ),
        ),
      ),
    );
  }
}
