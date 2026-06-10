package com.video.videoweb_flutter

import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.widget.FrameLayout
import com.opensource.svgaplayer.SVGADrawable
import com.opensource.svgaplayer.SVGAImageView
import com.opensource.svgaplayer.SVGAParser
import com.opensource.svgaplayer.SVGAVideoEntity
import java.net.URL

/**
 * 屏幕中间 SVGA 礼物动画（对齐原生 LiveGiftSvgaOverlay.kt）
 */
class LiveGiftSvgaOverlay(private val container: FrameLayout) {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val parser by lazy { SVGAParser(container.context) }
    private val playing = mutableListOf<SVGAImageView>()

    fun play(svgaUrl: String, durationSeconds: Int) {
        val fullUrl = svgaUrl.trim()
        if (fullUrl.isEmpty() || !isSvgaUrl(fullUrl)) return

        clear()

        val imageView = SVGAImageView(container.context).apply {
            loops = 0
            clearsAfterStop = true
        }
        val lp = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
        ).apply { gravity = Gravity.CENTER }
        container.addView(imageView, lp)
        playing.add(imageView)

        try {
            parser.decodeFromURL(URL(fullUrl), object : SVGAParser.ParseCompletion {
                override fun onComplete(videoItem: SVGAVideoEntity) {
                    if (imageView.parent == null) return
                    imageView.setImageDrawable(SVGADrawable(videoItem))
                    imageView.startAnimation()
                }

                override fun onError() {
                    remove(imageView)
                }
            })
        } catch (_: Exception) {
            remove(imageView)
            return
        }

        val durationMs = durationSeconds.coerceAtLeast(1) * 1000L
        mainHandler.postDelayed({ stopAndRemove(imageView) }, durationMs)
    }

    fun clear() {
        playing.toList().forEach { stopAndRemove(it) }
    }

    private fun stopAndRemove(imageView: SVGAImageView) {
        try {
            imageView.stopAnimation(true)
            imageView.clear()
        } catch (_: Exception) {
        }
        if (imageView.parent == container) {
            container.removeView(imageView)
        }
        playing.remove(imageView)
    }

    private fun remove(imageView: SVGAImageView) {
        if (imageView.parent == container) {
            container.removeView(imageView)
        }
        playing.remove(imageView)
    }

    private fun isSvgaUrl(url: String): Boolean {
        val path = url.substringBefore('?').lowercase()
        return path.endsWith(".svga")
    }
}
