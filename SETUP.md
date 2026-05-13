# Setup Script for UAV GCS PRO v4
# Run this after authenticating with firebase and gh:

# 1. Firebase: create project & configure
#    - Go to https://console.firebase.google.com, create project "uav-gcs-pro"
#    - Register Android app with package: com.uavgcs.uav_gcs_pro
#    - Download google-services.json and replace android/app/google-services.json
#    - Run: flutterfire configure --project=uav-gcs-pro
#    - Or manually update lib/firebase_options.dart and android/app/google-services.json

# 2. GitHub:
#    gh auth login
#    gh repo create uav-gcs-pro --public --push --source .

# 3. Build:
#    flutter build apk --debug
