allprojects {
    repositories {
        google()
        mavenCentral()
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
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}


// 规避上游 url_launcher_android 的 lint 解析器崩溃。
// 仅禁用该插件的 Release lint 任务；flutter analyze 与全部单元测试不受影响。
subprojects {
    if (name == "url_launcher_android") {
        tasks.configureEach {
            if (name == "lintVitalAnalyzeRelease") {
                enabled = false
            }
        }
    }
}
