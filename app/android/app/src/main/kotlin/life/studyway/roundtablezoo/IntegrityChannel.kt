package life.studyway.roundtablezoo

import android.content.Context
import com.google.android.gms.tasks.Task
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.StandardIntegrityManager
import com.google.android.play.core.integrity.StandardIntegrityManager.PrepareIntegrityTokenRequest
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityToken
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenProvider
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenRequest
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Single-method channel backing `PlayIntegrityTokenProvider`
 * (`specs/007-ai-proxy/contracts/integrity-token-provider.md` §4): fetches
 * one Standard-API Play Integrity token per call. The token provider
 * itself is prepared lazily on first use and reused after that
 * (research.md R4) — preparing it is the slow, quota-relevant step, not
 * requesting a token from an already-prepared provider.
 */
class IntegrityChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        // TODO(quickstart.md §0): the GCP project number linked to Play
        // Integrity for life.studyway.roundtablezoo, not a placeholder.
        private const val CLOUD_PROJECT_NUMBER = 0L
    }

    private val integrityManager: StandardIntegrityManager by lazy {
        IntegrityManagerFactory.createStandard(context)
    }

    private var tokenProvider: StandardIntegrityTokenProvider? = null
    private var preparingProvider: Task<StandardIntegrityTokenProvider>? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "requestToken") {
            result.notImplemented()
            return
        }
        requestToken(result)
    }

    private fun requestToken(result: MethodChannel.Result) {
        val prepared = tokenProvider
        if (prepared != null) {
            fetchToken(prepared, result)
            return
        }

        val inFlight = preparingProvider
        if (inFlight != null) {
            inFlight
                .addOnSuccessListener { provider -> fetchToken(provider, result) }
                .addOnFailureListener { error ->
                    result.error("integrity_prepare_failed", error.message, null)
                }
            return
        }

        val request = PrepareIntegrityTokenRequest.builder()
            // TODO: replace with the real GCP project number once the Play
            // Console project from quickstart.md §0 exists — the Standard
            // API requires the *cloud* project number, not the Android
            // applicationId (analogous to the applicationId TODO in
            // app/android/app/build.gradle.kts).
            .setCloudProjectNumber(CLOUD_PROJECT_NUMBER)
            .build()

        val task = integrityManager.prepareIntegrityToken(request)
        preparingProvider = task
        task
            .addOnSuccessListener { provider ->
                tokenProvider = provider
                preparingProvider = null
                fetchToken(provider, result)
            }
            .addOnFailureListener { error ->
                preparingProvider = null
                result.error("integrity_prepare_failed", error.message, null)
            }
    }

    private fun fetchToken(provider: StandardIntegrityTokenProvider, result: MethodChannel.Result) {
        val request = StandardIntegrityTokenRequest.builder().build()
        provider
            .request(request)
            .addOnSuccessListener { token: StandardIntegrityToken ->
                result.success(token.token())
            }
            .addOnFailureListener { error ->
                result.error("integrity_token_failed", error.message, null)
            }
    }
}
