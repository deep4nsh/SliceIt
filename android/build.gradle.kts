buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Required for Firebase
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Optional custom build directory setup (you can keep or remove)
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
    afterEvaluate {
        if (project.plugins.hasPlugin("com.android.library")) {
             project.extensions.configure<com.android.build.gradle.LibraryExtension> {
                 compileSdk = 36
                 if (namespace == null) {
                     namespace = "com.example." + project.name.replace("-", "_").replace(".", "_")
                 }
             }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}



tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}