package com.video.videoweb_flutter

/**
 * 单例持有当前直播间 SVGA 容器；PlatformView 创建时注册，销毁时释放。
 */
object LiveGiftSvgaHolder {
    @Volatile
    var overlay: LiveGiftSvgaOverlay? = null

    private var pendingUrl: String? = null
    private var pendingDuration: Int = 4

    fun register(overlay: LiveGiftSvgaOverlay) {
        this.overlay = overlay
        val url = pendingUrl
        if (!url.isNullOrEmpty()) {
            overlay.play(url, pendingDuration)
            pendingUrl = null
        }
    }

    fun unregister(overlay: LiveGiftSvgaOverlay) {
        if (this.overlay === overlay) {
            this.overlay = null
        }
    }

    fun play(url: String, duration: Int) {
        val o = overlay
        if (o != null) {
            o.play(url, duration)
        } else {
            pendingUrl = url
            pendingDuration = duration
        }
    }

    fun clear() {
        overlay?.clear()
        pendingUrl = null
    }
}
