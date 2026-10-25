# Room 2.2.5 retains database class names but not their no-argument constructors
# in R8 full mode. WorkManager creates this implementation through reflection
# during AndroidX Startup, before Flutter starts. Keep only that entry point.
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}
