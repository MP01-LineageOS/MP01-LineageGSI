package com.lmqr.hMP01_comp_service

import android.util.Log

object MP01SystemProperties {
    private const val TAG = "MP01SystemProperties"

    private val getMethod by lazy {
        Class.forName("android.os.SystemProperties")
            .getMethod("get", String::class.java, String::class.java)
    }

    fun get(key: String, defaultValue: String = ""): String {
        return try {
            getMethod.invoke(null, key, defaultValue) as? String ?: defaultValue
        } catch (e: Exception) {
            Log.w(TAG, "Unable to read system property $key", e)
            defaultValue
        }
    }
}
