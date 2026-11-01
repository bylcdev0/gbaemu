pluginManagement {
    repositories {
        gradlePluginPortal()
        google()
        mavenCentral()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}
rootProject.name = "GbaEmu"

// Include Android app
include(":android:app")

// Note: iOS uses Swift Package Manager (Package.swift)
// This Gradle build is for Android only
// For iOS, open ios/Package.swift in Xcode or use: swift build