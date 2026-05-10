package ralcock.cbf

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Enable edge-to-edge display for Android 15+ (API 35) compatibility.
        // This ensures system bars are transparent and content draws behind them,
        // satisfying Android 15's mandatory edge-to-edge enforcement. Calling this
        // before super.onCreate() also provides backward compatibility on Android 9–14.
        // Flutter's Scaffold/AppBar/NavigationBar handle window insets automatically.
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}
