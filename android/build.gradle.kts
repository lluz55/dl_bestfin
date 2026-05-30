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

subprojects {
    val forceNdk = Action<Project> {
        val android = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        android?.ndkVersion = "27.0.12077973"
    }
    if (state.executed) {
        forceNdk.execute(this)
    } else {
        afterEvaluate(forceNdk)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
