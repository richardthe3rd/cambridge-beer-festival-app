package ralcock.cbf

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Enable edge-to-edge before Flutter sets up the window.
        // This prevents Flutter from calling the deprecated Window.setStatusBarColor
        // and Window.setNavigationBarColor APIs (deprecated in Android 15).
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}
