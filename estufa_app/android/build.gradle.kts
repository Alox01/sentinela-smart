import com.android.build.gradle.LibraryExtension
import com.android.build.api.variant.LibraryAndroidComponentsExtension

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
    plugins.withId("com.android.library") {
        if (project.name == "isar_flutter_libs") {
            extensions.configure<LibraryExtension>("android") {
                namespace = "dev.isar.isar_flutter_libs"
            }
            // O plugin fixa compileSdk 30 (sem android:attr/lStar) no proprio
            // build.gradle, o que quebra o release. finalizeDsl roda depois do
            // build.gradle do plugin e antes de o AGP travar o DSL, permitindo
            // elevar para um SDK instalado e >= 31.
            extensions.configure<LibraryAndroidComponentsExtension>("androidComponents") {
                finalizeDsl {
                    it.compileSdk = 35
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
