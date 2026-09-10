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
    afterEvaluate {
        if (project.extensions.findByName("android") != null) {
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            
            // Fix 1: Set namespace for AGP 8.0+ compatibility
            if (android.namespace == null) {
                if (project.name == "nsd_android") {
                    android.namespace = "com.haberey.flutter.nsd_android"
                } else {
                    android.namespace = "com.${project.name.replace("-", ".")}"
                }
            }

            // Fix 2: Remove 'package' attribute from AndroidManifest.xml if it exists
            // This is required because AGP 8.0+ forbids the 'package' attribute in the manifest
            val manifestFile = project.file("src/main/AndroidManifest.xml")
            if (manifestFile.exists()) {
                val content = manifestFile.readText()
                if (content.contains("package=")) {
                    val updatedContent = content.replace(Regex("package=\"[^\"]*\""), "")
                    manifestFile.writeText(updatedContent)
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
