importScripts('https://www.gstatic.com/firebasejs/9.22.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCfAxjVCz0wux86t_DiepAiWxA6vZYtSkY',
  appId: '1:922952422234:web:b0d9aa20617fb18e23d963',
  messagingSenderId: '922952422234',
  projectId: 'quaid-academy',
  authDomain: 'quaid-academy.firebaseapp.com',
  storageBucket: 'quaid-academy.firebasestorage.app'
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification?.title || 'Quaid Academy Notification';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
