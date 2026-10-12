package com.geopunch.attendance

import android.app.Application
import org.osmdroid.config.Configuration

class GeoPunchApp : Application() {

    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)

        // osmdroid's tile-usage policy requires a distinct user agent to identify requests.
        val osmdroidPrefs = getSharedPreferences("${packageName}_osmdroid", MODE_PRIVATE)
        Configuration.getInstance().load(this, osmdroidPrefs)
        Configuration.getInstance().userAgentValue = packageName
    }
}
