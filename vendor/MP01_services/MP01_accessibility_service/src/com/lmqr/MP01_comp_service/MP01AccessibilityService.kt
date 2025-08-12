package com.lmqr.hMP01_comp_service

import SystemSettingsManager
import android.accessibilityservice.AccessibilityService
import android.annotation.SuppressLint
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Point
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.Button
import android.widget.CompoundButton
import android.widget.SeekBar
import android.widget.TextView
import androidx.preference.PreferenceManager
import com.lmqr.hMP01_comp_service.button_mapper.ButtonActionManager
import com.lmqr.hMP01_comp_service.command_runners.CommandRunner
import com.lmqr.hMP01_comp_service.command_runners.Commands
import com.lmqr.hMP01_comp_service.command_runners.UnixSocketCommandRunner
import kotlin.math.max
import kotlin.math.min


class MP01AccessibilityService : AccessibilityService(),
    SharedPreferences.OnSharedPreferenceChangeListener {
    private lateinit var commandRunner: CommandRunner
    private lateinit var refreshModeManager: RefreshModeManager
    private lateinit var sharedPreferences: SharedPreferences
    private lateinit var buttonActionManager: ButtonActionManager
    private lateinit var brightnessManager: BrightnessManager

    private var isScreenOn = true
    private val handler = Handler(Looper.getMainLooper())

    // --- AOD Overlay Members ---
    private var aodOverlayView: View? = null
    private lateinit var windowManager: WindowManager
    private var einkAodOnLockEnabled = false

    // --- Brightness Fade Members ---
    // Fade Out
    private var currentFadeOutStep = 0
    private var initialColdBrightnessForFadeOut = 0
    private var initialWarmBrightnessForFadeOut = 0
    private var initialKeyboardBrightnessForFadeOut = 0

    // Fade In
    private var currentFadeInStep = 0
    private var targetColdBrightnessForFadeIn = 0
    private var targetWarmBrightnessForFadeIn = 0
    private var targetKeyboardBrightnessForFadeIn = 0

    // Configurable Durations/Intervals
    private var fadeOffDurationMs = 500L
    private var fadeOnDurationMs = 500L
    private var fadeIntervalMs = 50L

    private fun getFadeOutStepsCount(): Int {
        if (fadeIntervalMs == 0L) return 0
        return (fadeOffDurationMs / fadeIntervalMs).toInt()
    }

    private fun getFadeInStepsCount(): Int {
        if (fadeIntervalMs == 0L) return 0
        return (fadeOnDurationMs / fadeIntervalMs).toInt()
    }


    private fun showAodOverlay() {
        if (aodOverlayView == null) {
            val inflater = LayoutInflater.from(this)
            aodOverlayView = inflater.inflate(R.layout.eink_aod_layout, null)

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            )
            params.gravity = Gravity.TOP or Gravity.START
            try {
                windowManager.addView(aodOverlayView, params)
                Log.d("MP01Service_AOD", "AOD overlay shown")
            } catch (e: Exception) {
                Log.e("MP01Service_AOD", "Error showing AOD overlay", e)
            }
        }
    }

    private fun hideAodOverlay() {
        aodOverlayView?.let {
            try {
                windowManager.removeView(it)
                Log.d("MP01Service_AOD", "AOD overlay hidden")
            } catch (e: Exception) {
                Log.e("MP01Service_AOD", "Error hiding AOD overlay", e)
            }
            aodOverlayView = null
        }
    }

    private fun startBrightnessFadeOut() {
        initialColdBrightnessForFadeOut = brightnessManager.coldBrightness
        initialWarmBrightnessForFadeOut = brightnessManager.warmBrightness
        initialKeyboardBrightnessForFadeOut = brightnessManager.keyboardBrightness

        currentFadeOutStep = 0
        handler.removeCallbacks(brightnessFadeOutRunnable)
        handler.removeCallbacks(brightnessFadeInRunnable) // Stop any fade in

        if (getFadeOutStepsCount() > 0 && fadeIntervalMs > 0) {
            handler.post(brightnessFadeOutRunnable)
            Log.d("MP01Service_Fade", "Brightness fade OUT started: duration=${fadeOffDurationMs}ms, interval=${fadeIntervalMs}ms")
        } else {
            Log.d("MP01Service_Fade", "Brightness fade OUT skipped (duration or interval is zero)")
            brightnessManager.turnOffBrightness()
        }
    }

    private val brightnessFadeOutRunnable = object : Runnable {
        override fun run() {
            currentFadeOutStep++
            val totalFadeSteps = getFadeOutStepsCount()
            if (totalFadeSteps > 0 && currentFadeOutStep <= totalFadeSteps) {
                val progress = currentFadeOutStep.toFloat() / totalFadeSteps.toFloat()

                val newCold = max(0, initialColdBrightnessForFadeOut - (initialColdBrightnessForFadeOut * progress).toInt())
                val newWarm = max(0, initialWarmBrightnessForFadeOut - (initialWarmBrightnessForFadeOut * progress).toInt())
                val newKeyboard = max(0, initialKeyboardBrightnessForFadeOut - (initialKeyboardBrightnessForFadeOut * progress).toInt())

                val commandsToRun = mutableListOf<String>()
                commandsToRun.add("cbc${newCold}")
                commandsToRun.add("cbw${newWarm}")
                commandsToRun.add("ckb${newKeyboard}")

                commandRunner.runCommands(commandsToRun.toTypedArray())
                handler.postDelayed(this, fadeIntervalMs)
            } else {
                Log.d("MP01Service_Fade", "Brightness fade OUT finished")
                brightnessManager.turnOffBrightness()
            }
        }
    }

    private fun startBrightnessFadeIn() {
        targetColdBrightnessForFadeIn = brightnessManager.coldBrightness
        targetWarmBrightnessForFadeIn = brightnessManager.warmBrightness
        targetKeyboardBrightnessForFadeIn = brightnessManager.keyboardBrightness

        currentFadeInStep = 0
        handler.removeCallbacks(brightnessFadeInRunnable)
        handler.removeCallbacks(brightnessFadeOutRunnable) // Stop any fade out

        if (getFadeInStepsCount() > 0 && fadeIntervalMs > 0) {
            // Optionally, ensure brightness starts from 0 for a clean fade-in
            // commandRunner.runCommands(arrayOf("cbc0", "cbw0", "ckb0"))
            handler.post(brightnessFadeInRunnable)
            Log.d("MP01Service_Fade", "Brightness fade IN started: duration=${fadeOnDurationMs}ms, interval=${fadeIntervalMs}ms. Target: C=${targetColdBrightnessForFadeIn}, W=${targetWarmBrightnessForFadeIn}, K=${targetKeyboardBrightnessForFadeIn}")
        } else {
            Log.d("MP01Service_Fade", "Brightness fade IN skipped (duration or interval is zero)")
            brightnessManager.applyBrightness()
        }
    }

    private val brightnessFadeInRunnable = object : Runnable {
        override fun run() {
            currentFadeInStep++
            val totalFadeSteps = getFadeInStepsCount()
            if (totalFadeSteps > 0 && currentFadeInStep <= totalFadeSteps) {
                val progress = currentFadeInStep.toFloat() / totalFadeSteps.toFloat()

                val newCold = min(targetColdBrightnessForFadeIn, (targetColdBrightnessForFadeIn * progress).toInt())
                val newWarm = min(targetWarmBrightnessForFadeIn, (targetWarmBrightnessForFadeIn * progress).toInt())
                val newKeyboard = min(targetKeyboardBrightnessForFadeIn, (targetKeyboardBrightnessForFadeIn * progress).toInt())

                val commandsToRun = mutableListOf<String>()
                commandsToRun.add("cbc${newCold}")
                commandsToRun.add("cbw${newWarm}")
                commandsToRun.add("ckb${newKeyboard}")

                commandRunner.runCommands(commandsToRun.toTypedArray())
                handler.postDelayed(this, fadeIntervalMs)
            } else {
                Log.d("MP01Service_Fade", "Brightness fade IN finished")
                brightnessManager.applyBrightness() // Ensure final brightness values are set
            }
        }
    }


    private val receiver: BroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    Log.d("MP01Service", "ACTION_SCREEN_OFF received")
                    isScreenOn = false
                    menuBinding?.close()
                    handler.removeCallbacks(brightnessFadeInRunnable) // Stop fade IN

                    if (einkAodOnLockEnabled) {
                        showAodOverlay()
                        startBrightnessFadeOut()
                    } else {
                        brightnessManager.turnOffBrightness()
                    }

                    if (sharedPreferences.getBoolean("refresh_on_lock", false)) {
                        handler.postDelayed({
                            commandRunner.runCommands(arrayOf(Commands.SPEED_CLEAR))
                        }, 50)
                    }

                    handler.postDelayed({
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            performGlobalAction(AccessibilityService.GLOBAL_ACTION_LOCK_SCREEN)
                        }
                    }, 100)
                }
                Intent.ACTION_SCREEN_ON -> {
                    Log.d("MP01Service", "ACTION_SCREEN_ON received")
                    isScreenOn = true
                    handler.removeCallbacks(brightnessFadeOutRunnable) // Stop fade OUT

                    if (einkAodOnLockEnabled) {
                        hideAodOverlay()
                        startBrightnessFadeIn()
                    } else {
                        brightnessManager.applyBrightness()
                    }

                    if (sharedPreferences.getBoolean("refresh_on_lock", false)) {
                        refreshModeManager.applyMode()
                    }
                    Log.d("MP01Service", "Brightness restoration initiated for screen on")
                }
            }
        }
    }
    private val receiverEink: BroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if(!sharedPreferences.getBoolean("allow_custom_broadcast", false))
                return

            when (intent.action) {
                "EINK_FORCE_CLEAR" -> {
                    commandRunner.runCommands(arrayOf(Commands.FORCE_CLEAR))
                }
                "EINK_REFRESH_SPEED_BALANCED" -> {
                    refreshModeManager.changeMode(RefreshMode.BALANCED)
                }
                "EINK_REFRESH_SPEED_SMOOTH" -> {
                    refreshModeManager.changeMode(RefreshMode.SMOOTH)
                }
                "EINK_REFRESH_SPEED_FAST" -> {
                    refreshModeManager.changeMode(RefreshMode.SPEED)
                }
            }
        }
    }


    override fun onCreate() {
        super.onCreate()
        Log.d("MP01Service", "onCreate started")
        commandRunner = UnixSocketCommandRunner()
        sharedPreferences = PreferenceManager.getDefaultSharedPreferences(this)
        sharedPreferences.registerOnSharedPreferenceChangeListener(this)

        einkAodOnLockEnabled = sharedPreferences.getBoolean("enable_eink_aod_on_lock", false)
        fadeOffDurationMs = sharedPreferences.getInt("fade_off_duration_ms", 500).toLong()
        fadeOnDurationMs = sharedPreferences.getInt("fade_on_duration_ms", 500).toLong()
        fadeIntervalMs = sharedPreferences.getInt("fade_interval_ms", 50).toLong()

        refreshModeManager = RefreshModeManager(sharedPreferences, commandRunner)
        buttonActionManager = ButtonActionManager(commandRunner, refreshModeManager)
        brightnessManager = BrightnessManager(sharedPreferences, commandRunner)

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        val filterScreen = IntentFilter()
        filterScreen.addAction(Intent.ACTION_SCREEN_ON)
        filterScreen.addAction(Intent.ACTION_SCREEN_OFF)
        registerReceiver(receiver, filterScreen)

        val filterEink = IntentFilter()
        filterEink.addAction("EINK_FORCE_CLEAR")
        filterEink.addAction("EINK_REFRESH_SPEED_BALANCED")
        filterEink.addAction("EINK_REFRESH_SPEED_SMOOTH")
        filterEink.addAction("EINK_REFRESH_SPEED_FAST")
        registerReceiver(receiverEink, filterEink, RECEIVER_EXPORTED)
        Log.d("MP01Service", "onCreate finished. AOD: $einkAodOnLockEnabled, FadeOff: ${fadeOffDurationMs}ms, FadeOn: ${fadeOnDurationMs}ms, Interval: ${fadeIntervalMs}ms")
    }

    override fun onInterrupt() {
        Log.d("MP01Service", "onInterrupt")
    }

    private val hardwareGestureDetector = HardwareGestureDetector(
        object: HardwareGestureDetector.OnGestureListener{
            override fun onSinglePress() {
                if(isScreenOn)
                    buttonActionManager.executeSinglePress(this@MP01AccessibilityService)
                else
                    buttonActionManager.executeSinglePressScreenOff(this@MP01AccessibilityService)
            }

            override fun onDoublePress() {
                if(isScreenOn)
                    buttonActionManager.executeDoublePress(this@MP01AccessibilityService)
                else
                    buttonActionManager.executeDoublePressScreenOff(this@MP01AccessibilityService)
            }

            override fun onLongPress() {
                if(isScreenOn)
                    buttonActionManager.executeLongPress(this@MP01AccessibilityService)
                else
                    buttonActionManager.executeLongPressScreenOff(this@MP01AccessibilityService)
            }
        }
    )

    private val hardwareGestureDetectorTop = HardwareGestureDetector(
        object: HardwareGestureDetector.OnGestureListener{
            override fun onSinglePress() {
                if(isScreenOn)
                    buttonActionManager.executeSinglePressTop(this@MP01AccessibilityService)
                else
                    buttonActionManager.executeSinglePressScreenOffTop(this@MP01AccessibilityService)
            }

            override fun onDoublePress() {
                if(isScreenOn)
                    buttonActionManager.executeDoublePressTop(this@MP01AccessibilityService)
                else
                    buttonActionManager.executeDoublePressScreenOffTop(this@MP01AccessibilityService)
            }

            override fun onLongPress() {
                if(isScreenOn)
                    buttonActionManager.executeLongPressTop(this@MP01AccessibilityService)
                else
                    buttonActionManager.executeLongPressScreenOffTop(this@MP01AccessibilityService)
            }
        }
    )

    override fun onKeyEvent(event: KeyEvent): Boolean {
        if(event.scanCode == 252){
            if (!Settings.canDrawOverlays(this) && sharedPreferences.getBoolean("show_eink_menu", false)) {
                requestOverlayPermission()
            } else if (sharedPreferences.getBoolean("show_eink_menu", false)) {
                hardwareGestureDetector.onKeyEvent(event.action, event.eventTime)
            }
        } else if (event.scanCode == 251) {
            if (!Settings.canDrawOverlays(this) && sharedPreferences.getBoolean("show_eink_menu_top", false)) {
                requestOverlayPermission()
            } else if (sharedPreferences.getBoolean("show_eink_menu_top", false)) {
                hardwareGestureDetectorTop.onKeyEvent(event.action, event.eventTime)
            }
        }
        return super.onKeyEvent(event)
    }


    private fun requestOverlayPermission() {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName")
        )
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            Log.e("OverlayPermission", "Activity not found exception", e)
        }
    }

    private fun getAppUsableScreenSize(context: Context): Point {
        val windowManager = context.getSystemService(WINDOW_SERVICE) as WindowManager
        val display = windowManager.defaultDisplay
        val size = Point()
        display.getSize(size)
        return size
    }

    private fun getRealScreenSize(context: Context): Point {
        val windowManager = context.getSystemService(WINDOW_SERVICE) as WindowManager
        val display = windowManager.defaultDisplay
        val size = Point()
        display.getRealSize(size)
        return size
    }

    private fun getNavBarHeight(): Int {
        val appUsableSize: Point = getAppUsableScreenSize(this)
        val realScreenSize: Point = getRealScreenSize(this)

        if (appUsableSize.y < realScreenSize.y)
            return (realScreenSize.y - appUsableSize.y)

        return 0
    }

    private var menuBinding: FloatingMenuViewAccessor? = null

    @SuppressLint("ClickableViewAccessibility", "InflateParams")
    fun openFloatingMenu() {
        try {
            menuBinding?.run {
                if (root.visibility == View.VISIBLE) {
                    root.visibility = View.GONE
                } else {
                    root.visibility = View.VISIBLE
                    updateButtons(refreshModeManager.currentMode)
                }
            } ?: run {

                val wm = getSystemService(WINDOW_SERVICE) as WindowManager
                val inflater = LayoutInflater.from(this)
                val view = inflater.inflate(R.layout.floating_menu_layout, null, false)

                val layoutParams = WindowManager.LayoutParams().apply {
                    type = WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                    format = PixelFormat.TRANSLUCENT
                    flags =
                        flags or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH
                    width = WindowManager.LayoutParams.MATCH_PARENT
                    height = WindowManager.LayoutParams.WRAP_CONTENT
                    gravity = Gravity.BOTTOM
                    y = getNavBarHeight()
                }

                menuBinding = FloatingMenuViewAccessor(view).apply {
                    root.setOnTouchListener { v: View, event: MotionEvent ->
                        if (event.action == MotionEvent.ACTION_OUTSIDE)
                            close()
                        false
                    }
                    button2.setOnClickListener {
                        refreshModeManager.changeMode(RefreshMode.BALANCED)
                        updateButtons(refreshModeManager.currentMode)
                    }
                    button3.setOnClickListener {
                        refreshModeManager.changeMode(RefreshMode.SMOOTH)
                        updateButtons(refreshModeManager.currentMode)
                    }
                    button4.setOnClickListener {
                        refreshModeManager.changeMode(RefreshMode.SPEED)
                        updateButtons(refreshModeManager.currentMode)
                    }
                    settingsIcon.setOnClickListener {
                        val settingsIntent = Intent(
                            this@MP01AccessibilityService,
                            SettingsActivity::class.java
                        )
                        settingsIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        close()
                        startActivity(settingsIntent)
                    }

                    brightnessManager.setupSeekBars(lightSeekbar, lightWarmSeekbar, lightKeyboardSeekbar)
                    updateButtons(refreshModeManager.currentMode)

                    wm.addView(root, layoutParams)
                }
            }
        } catch (ex: Exception) {
            ex.printStackTrace()
        }
    }

    override fun onDestroy() {
        Log.d("MP01Service", "onDestroy")
        hideAodOverlay()
        handler.removeCallbacks(brightnessFadeOutRunnable)
        handler.removeCallbacks(brightnessFadeInRunnable)
        commandRunner.onDestroy()
        sharedPreferences.unregisterOnSharedPreferenceChangeListener(this)
        unregisterReceiver(receiver)
        unregisterReceiver(receiverEink)
        super.onDestroy()
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d("MP01Service", "Service connected - applying all settings")

        handler.postDelayed({
            refreshModeManager.applyMode()

            handler.postDelayed({
                brightnessManager.applyBrightness()

                handler.postDelayed({
                    updateColorScheme(sharedPreferences)
                    updateMaxBrightness(sharedPreferences)
                    Log.d("MP01Service", "Applied remaining settings")
                }, 500)
            }, 500)
        }, 1000)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event.letPackageNameClassName { pkgName, clsName ->
            val componentName = ComponentName(
                pkgName,
                clsName
            )
            try {
                packageManager.getActivityInfo(componentName, 0)
                refreshModeManager.onAppChange(pkgName)
                menuBinding?.updateButtons(refreshModeManager.currentMode)
            } catch (_: PackageManager.NameNotFoundException) {
            }
        }
    }

    private fun updateColorScheme(sharedPreferences: SharedPreferences) = sharedPreferences.run {
        val type = getString("color_scheme_type", "5")
        val colorString = getInt("color_scheme_color", 20).progressToHex()
        commandRunner.runCommands(arrayOf("theme $type $colorString"))
    }

    private fun updateMaxBrightness(sharedPreferences: SharedPreferences) = sharedPreferences.run {
        try{
            val brightness = Integer.parseInt(getString("override_max_brightness", "2000")?:"2000")
            commandRunner.runCommands(arrayOf("smb$brightness"))
        } catch (e: NumberFormatException) {
            Log.e("MP01Service", "Error updating max brightness", e)
        }
    }

    override fun onSharedPreferenceChanged(sharedPreferences: SharedPreferences?, key: String?) {
        Log.d("MP01Service", "onSharedPreferenceChanged: key=$key")
        sharedPreferences?.let { pref ->
            when (key) {
                "enable_eink_aod_on_lock" -> {
                    einkAodOnLockEnabled = pref.getBoolean(key, false)
                    Log.d("MP01Service", "AOD on lock setting changed: $einkAodOnLockEnabled")
                }
                "fade_off_duration_ms" -> {
                    fadeOffDurationMs = pref.getInt(key, 500).toLong()
                    Log.d("MP01Service", "Fade off duration changed: ${fadeOffDurationMs}ms")
                }
                "fade_on_duration_ms" -> {
                    fadeOnDurationMs = pref.getInt(key, 500).toLong()
                    Log.d("MP01Service", "Fade on duration changed: ${fadeOnDurationMs}ms")
                }
                "fade_interval_ms" -> {
                    fadeIntervalMs = pref.getInt(key, 50).toLong()
                    Log.d("MP01Service", "Fade interval changed: ${fadeIntervalMs}ms")
                }
                "override_max_brightness" -> {
                    updateMaxBrightness(pref)
                }
                "color_scheme_type", "color_scheme_color" -> {
                    updateColorScheme(pref)
                }
                "close_status_bar" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        performGlobalAction(GLOBAL_ACTION_DISMISS_NOTIFICATION_SHADE)
                    }
                }
                "run_clear_screen" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        performGlobalAction(GLOBAL_ACTION_DISMISS_NOTIFICATION_SHADE)
                        handler.postDelayed({
                            commandRunner.runCommands(arrayOf(Commands.FORCE_CLEAR))
                        }, 700)
                    }
                }
                "show_eink_menu", "show_eink_menu_top" -> {
                    Log.d("MP01Service", "Eink menu preference changed: $key")
                }
                else -> {
                    // Handle any other preference keys
                    Log.d("MP01Service", "Unhandled preference key: $key")
                }
            }
        }
    }
}

fun AccessibilityEvent?.letPackageNameClassName(block: (String, String) -> Unit) {
    this?.run {
        if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED)
            this.className?.let { clsName ->
                this.packageName?.let { pkgName -> block(pkgName.toString(), clsName.toString()) }
            }
    }
}

fun Button.deselect() {
    setBackgroundResource(R.drawable.drawable_border_normal)
    setTextColor(Color.BLACK)
}

fun Button.select() {
    setBackgroundResource(R.drawable.drawable_border_pressed)
    setTextColor(Color.WHITE)
}
