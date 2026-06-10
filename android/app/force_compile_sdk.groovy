// 强制所有 library 子项目使用 compileSdk = 35 和本地 NDK
subprojects { subproj ->
    subproj.afterEvaluate {
        if (!subproj.hasProperty('android')) return
        def ext = subproj.android
        try { ext.compileSdk = 35 } catch (Exception e) {}
        try { ext.ndkVersion = '27.0.12077973' } catch (Exception e) {}
        try {
            if (ext.hasProperty('namespace') && ext.namespace == null) {
                ext.namespace = "com.ext.${subproj.name.replace('-', '_')}"
            }
        } catch (Exception e) {}
    }
}
