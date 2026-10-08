package com.swarm.lucille.data.hitl

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * One-tap "Deny" from an approval notification, and restarting the approval
 * link after a reboot or app update. Approving never happens here — it needs
 * the review screen and the screen lock (HitlApprovalActivity).
 */
class HitlActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_DENY = "com.swarm.lucille.hitl.DENY"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_DENY -> {
                val id = intent.getStringExtra(HitlApprovalService.EXTRA_CHALLENGE_ID) ?: return
                HitlApprovalService.respond(context, id, approved = false)
            }
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> HitlApprovalService.sync(context)
        }
    }
}
