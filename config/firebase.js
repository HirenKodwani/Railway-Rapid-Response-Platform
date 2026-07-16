const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');
const { getFirestore } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const path = require('path');
const fs = require('fs');

const initFirebase = () => {
  try {
    const localPath = path.join(__dirname, '..', 'firebase-adminsdk.json');
    const renderPath = '/etc/secrets/firebase-adminsdk.json';
    
    let serviceAccountPath = null;
    if (fs.existsSync(localPath)) {
      serviceAccountPath = localPath;
    } else if (fs.existsSync(renderPath)) {
      serviceAccountPath = renderPath;
    }

    if (!serviceAccountPath) {
      console.warn('⚠️ Firebase Admin SDK private key not found at local or Render secrets path.');
      console.warn('Push notifications will not be sent.');
      return false;
    }

    const serviceAccount = require(serviceAccountPath);

    initializeApp({
      credential: cert(serviceAccount),
      storageBucket: 'railway-rapid-response.firebasestorage.app' 
    });

    console.log('✅ Firebase Admin SDK initialized successfully');
    return true;
  } catch (error) {
    console.error('❌ Failed to initialize Firebase Admin SDK:', error.message);
    return false;
  }
};

const sendPushNotification = async (fcmToken, payload) => {
  if (getApps().length === 0) {
    console.warn('Firebase not initialized. Cannot send push notification.');
    return;
  }

  if (!fcmToken) {
    console.warn('No FCM token provided. Skipping push notification.');
    return;
  }

  try {
    const message = {
      token: fcmToken,
      data: payload,
      // Priority high is REQUIRED to wake up Doze mode on Android
      android: {
        priority: 'high',
      }
    };

    const response = await getMessaging().send(message);
    console.log('Successfully sent Firebase push notification:', response);
    return response;
  } catch (error) {
    console.error('Error sending Firebase push notification:', error.message);
    throw error;
  }
};

module.exports = { initFirebase, sendPushNotification, getFirestore };
