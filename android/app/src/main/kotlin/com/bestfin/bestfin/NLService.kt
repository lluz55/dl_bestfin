package com.bestfin.bestfin

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import com.notification_listener_service.NotificationListenerServicePlugin

class NLService : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        sbn?.let { NotificationListenerServicePlugin.onNotificationPosted(it) }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
        sbn?.let { NotificationListenerServicePlugin.onNotificationRemoved(it) }
    }
}
