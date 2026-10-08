package com.swarm.lucille.data.memory

import android.app.job.JobParameters
import android.app.job.JobService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Periodic memory sync that survives Doze (spec §4, "Android background
 * execution"). JobScheduler batches it into maintenance windows — at most
 * every 15 minutes, only with a network. Platform API, so no WorkManager dependency.
 */
class MemorySyncJobService : JobService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var running: Job? = null

    override fun onStartJob(params: JobParameters): Boolean {
        MemorySyncEngine.start(applicationContext)
        running = scope.launch {
            MemorySyncEngine.syncAll()
            jobFinished(params, false)
        }
        return true
    }

    override fun onStopJob(params: JobParameters): Boolean {
        running?.cancel()
        return true // retry per the job's backoff
    }
}
