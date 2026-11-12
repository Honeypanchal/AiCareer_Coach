package com.ex.ai_career_coach

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // Called when the user presses or swipes back on the first screen
    // (Home or Login). Flutter's default is to finish() the activity, which
    // destroys the Flutter engine; reopening then restarts the app inside the
    // old process and Firebase has to re-initialise, which could leave a
    // white screen. Moving the app to the background instead is what Android
    // does for launcher apps since Android 12: reopening resumes instantly
    // exactly where the user left off.
    override fun popSystemNavigator(): Boolean {
        moveTaskToBack(true)
        return true
    }
}
