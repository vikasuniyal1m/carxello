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

// Logic to inject namespace for misconfigured plugins
subprojects {
    project.afterEvaluate {
        if (project.name != "app" && project.hasProperty("android")) {
            val android = project.extensions.getByName("android")
            // Using reflection to safely set namespace if it doesn't exist
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val namespace = getNamespace.invoke(android) as? String
                
                if (namespace.isNullOrEmpty()) {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    // Create a fallback namespace based on project name
                    val fallbackNamespace = "com.carauction.plugins.${project.name.replace("-", "_").replace(".", "_")}"
                    setNamespace.invoke(android, fallbackNamespace)
                    println("⚠️ Injected namespace '$fallbackNamespace' for project: ${project.name}")
                }
            } catch (e: NoSuchMethodException) {
                // AGP version might be too old or too new for this method signature.
                // This is expected for some older plugins not using AGP 8+.
                println("ℹ️ Could not check/set namespace for ${project.name} due to method not found: ${e.message}")
            } catch (e: Exception) {
                println("❌ Error injecting namespace for ${project.name}: ${e.message}")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
