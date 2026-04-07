# flutteradgents

Flutteradgents is a solution designed for testers and QA teams responsible for app validation. **Directly from within the project**, it allows users to log in with their Jira account, capture screenshots, add annotations, and easily create and assign bug tickets to developers.

Each generated ticket automatically includes all the essential information needed for faster resolution, such as:  
🌍 Environment: dev  
📟 Platform: iOS  
📱 Device: iPhone 17 Pro · iOS 26.2  
🔢 Build number: 1  
📌 Build version: 1.0.0  
📲 App name: Demo


## Dependencies

In your app `pubspec.yaml`:

```yaml  
dependencies:   
 flutteradgents: x.x.x 
```  

## Get started

     return FlutterAdgentsHosts(  
          settings: FlutterAdgentsSettings.simple(  
            projectId: 'fad_XXXXXXXX',  <--- Step 1 
            flavor: 'develop',  <--- Step 2 
          ),  
          child: MaterialApp(  
            builder: FlutterAdgents.materialAppBuilder,  <--- Step 3
          ),  
        );
