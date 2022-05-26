import 'package:clipall/Splash.dart';
import 'package:clipall/constants.dart';
import 'package:clipall/main.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutterfire_ui/auth.dart';
import 'package:clipall/MyHomePage.dart';
import 'package:firebase_auth_desktop/firebase_auth_desktop.dart';
import 'package:firebase_core_desktop/firebase_core_desktop.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AuthGate(),
      color: Colors.white,
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
// If the user is already signed-in, use it as initial data
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
// User is not signed in
        if (!snapshot.hasData) {
          return SignInScreen(
              showAuthActionSwitch: false,
              headerBuilder: (context, constraints, _) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Center(
                      child: Hero(
                        tag: 'Logo',
                        child: Image.asset(
                          'Images/NameWithLogo.png',
                        ),
                      ),
                    ),
                  ),
                );
              },
              sideBuilder: (context, constraints) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Center(
                      child: Hero(
                        tag: 'Logo',
                        child: Image.asset(
                          'Images/NameWithLogo.png',
                        ),
                      ),
                    ),
                  ),
                );
              },
              providerConfigs: [
                PhoneProviderConfiguration(),
                GoogleProviderConfiguration(clientId: appID)
              ]);
        } else {
          if (FirebaseAuth.instance.currentUser != null) {
            return MyHomePage();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Error Logging in please retry "),
              backgroundColor: Colors.redAccent,
            ));
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => Splash()));
          }
          return Text('');
        }
// Render your application if authenticated
      },
    );
  }
}
