package com.video.videoweb_flutter

import android.content.Context
import android.graphics.Color
import android.widget.FrameLayout
import io.flutter.plugin.platform.PlatformView

class LiveGiftSvgaPlatformView(context: Context) : PlatformView {

    private val container = FrameLayout(context).apply {
        setBackgroundColor(Color.TRANSPARENT)
        isClickable = false
        isFocusable = false
    }
    private val overlay = LiveGiftSvgaOverlay(container)

    init {
        LiveGiftSvgaHolder.register(overlay)
    }

    override fun getView() = container

    override fun dispose() {
        overlay.clear()
        LiveGiftSvgaHolder.unregister(overlay)
    }
}
