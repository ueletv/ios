import com.android.build.gradle.LibraryExtension

allprojects {
    repositories {
        maven { setUrl("https://maven.aliyun.com/repository/public/") }
        maven { setUrl("https://maven.aliyun.com/repository/google/") }
        maven { setUrl("https://jitpack.io") }
        google()
        mavenCentral()
    }
}

subprojects {
    buildscript {
        repositories {
            maven { setUrl("https://maven.aliyun.com/repository/public/") }
            maven { setUrl("https://maven.aliyun.com/repository/google/") }
            google()
            mavenCentral()
        }
    }
}

// AGP 8+ 要求 library 插件声明 namespace；fijkplayer 0.11.0 未适配
subprojects {
    pluginManager.withPlugin("com.android.library") {
        extensions.configure<LibraryExtension>("android") {
            if (namespace.isNullOrBlank()) {
                namespace = when (name) {
                    "fijkplayer" -> "com.befovy.fijkplayer"
                    else -> group.toString().ifBlank { "com.ext.${name.replace('-', '_')}" }
                }
            }
            compileSdk = 35
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    // 仅插件子工程等待 :app，避免 :app 自身 evaluationDependsOn(":app") 导致 Flutter 插件重复应用
    if (project.name != "app") {
        project.evaluationDependsOn(":app")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
