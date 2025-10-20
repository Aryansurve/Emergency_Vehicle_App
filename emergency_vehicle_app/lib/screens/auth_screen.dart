import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'package:lottie/lottie.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Keep the white background
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // --- Top Welcome Text ---
              Column(
                children: <Widget>[
                  FadeInUp(
                    duration: const Duration(milliseconds: 1000),
                    child: const Text(
                      "Welcome",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeInUp(
                    duration: const Duration(milliseconds: 1000),
                    child: const Text(
                      "Reliable Response, in Real-Time.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20, // Larger font size for impact
                        color: Colors.black,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Your chosen tagline
                  FadeInUp(
                    duration: const Duration(milliseconds: 1200),
                    child: Text(
                      "When every second matters, help is on the way.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),

              // --- Central Image (NOT BACKGROUND) ---
              // This is where we'll put your image, similar to the reference
              // FadeInUp(
              //   duration: const Duration(milliseconds: 1400),
              //   child: Container(
              //     // We can remove the fixed height for more flexibility,
              //     // or keep it if the image has specific aspect ratio needs.
              //     // For now, let's let the image define its height naturally.
              //     // height: MediaQuery.of(context).size.height / 3, // Removed fixed height
              //     child: Image.asset(
              //       'assets/central_image.jpg', // ** IMPORTANT: Replace with your actual image path **
              //       height: MediaQuery.of(context).size.height * 0.45, // Adjust height as needed
              //       fit: BoxFit.contain, // Ensures the whole image is visible
              //     ),
              //   ),
              // ),
              FadeInUp(
                duration: const Duration(milliseconds: 1400),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.45, // Adjust height as needed
                  child: Lottie.asset(
                    'assets/animation.json', // Replace with your Lottie JSON file path
                    fit: BoxFit.contain,       // Ensures the full animation fits inside container
                    repeat: true,              // Set to false if you want it to play only once
                  ),
                ),
              ),
              // --- Bottom Buttons ---
              Column(
                children: <Widget>[
                  FadeInUp(
                    duration: const Duration(milliseconds: 1500),
                    child: MaterialButton(
                      minWidth: double.infinity,
                      height: 60,
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                      },
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Colors.black),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Text(
                        "Login",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeInUp(
                    duration: const Duration(milliseconds: 1600),
                    child: MaterialButton(
                      minWidth: double.infinity,
                      height: 60,
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
                      },
                      color: Colors.blueGrey, // Your app's theme color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Text(
                        "Sign up",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 18),
                      ),
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}