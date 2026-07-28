package com.example.estufa_app

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Consultas ao sistema que o Flutter nao expoe. Hoje so o modo de som: o
    // app precisa saber se o celular esta mudo para avisar que nenhum alerta
    // vai tocar - inclusive o de incendio.
    private val canalSistema = "sentinela/nao_perturbe"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            canalSistema,
        ).setMethodCallHandler { call, resultado ->
            if (call.method == "modoDeSom") {
                // O modo silencioso e o estado que mais cala o app - e o que o
                // produtor entra sem querer (baixando o volume, sobrando de uma
                // reuniao). Saber disso deixa a tela avisar em vez de o alerta
                // simplesmente nao tocar de madrugada.
                try {
                    val audio =
                        getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val modo = when (audio.ringerMode) {
                        AudioManager.RINGER_MODE_SILENT -> "silencioso"
                        AudioManager.RINGER_MODE_VIBRATE -> "vibrar"
                        else -> "normal"
                    }
                    resultado.success(modo)
                } catch (erro: Exception) {
                    resultado.success("normal")
                }
            } else {
                resultado.notImplemented()
            }
        }
    }
}
