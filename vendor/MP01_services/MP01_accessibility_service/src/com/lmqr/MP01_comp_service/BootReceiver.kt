package com.lmqr.hMP01_comp_service

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("MP01BootReceiver", "Boot receiver triggered with action: ${intent.action}")
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            MP01Defaults.applyIfNeeded(context)
        }

        // Get the intended service from system property
        val propertyValue = MP01SystemProperties.get(
            "persist.accessibility.enabled_service", "")
            
        // Check if service is already enabled
        val serviceName = context.packageName + "/" + 
            MP01AccessibilityService::class.java.canonicalName
        var enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
            
        if (enabledServices == null) enabledServices = ""
        
        // Enable if needed and matching our property
        if (!enabledServices.contains(serviceName) && 
            (propertyValue == serviceName || propertyValue.isEmpty())) {
            
            if (!enabledServices.isEmpty()) {
                enabledServices += ":"
            }
            enabledServices += serviceName
            
            try {
                Settings.Secure.putString(
                    context.contentResolver,
                    Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
                    enabledServices)
                Log.d("MP01BootReceiver", "Successfully enabled accessibility service")
            } catch (e: Exception) {
                Log.e("MP01BootReceiver", "Failed to enable accessibility service", e)
            }
                
            Settings.Secure.putInt(
                context.contentResolver,
                Settings.Secure.ACCESSIBILITY_ENABLED, 1)
        }
    }
}
