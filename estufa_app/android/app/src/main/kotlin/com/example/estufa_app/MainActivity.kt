package com.example.estufa_app

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // O plugin flutter_local_notifications so abre as configuracoes de "Nao
    // perturbe" quando a permissao ainda NAO foi concedida; ja concedida, ele
    // apenas responde "true" e o botao nao leva a lugar nenhum. Este canal abre
    // a mesma tela do sistema nos dois casos, para o produtor poder conferir ou
    // revogar o acesso.
    private val canalNaoPerturbe = "sentinela/nao_perturbe"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            canalNaoPerturbe,
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
            } else if (call.method == "abrirNotificacoesDoApp") {
                // Tela de notificacoes DO APP, com a lista de canais. E la que
                // mora o desfazer: cada canal tem o proprio "Ignorar Nao
                // perturbe" e o proprio som, que o produtor pode desligar.
                // Recriar o canal pelo app nao serviria - o Android restaura as
                // configuracoes de um canal apagado quando ele volta com o
                // mesmo id.
                try {
                    val intent = Intent(
                        Settings.ACTION_APP_NOTIFICATION_SETTINGS,
                    )
                    intent.putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    resultado.success(true)
                } catch (erro: Exception) {
                    resultado.success(false)
                }
            } else if (call.method == "abrirConfiguracoes") {
                try {
                    val intent = Intent(
                        Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS,
                    )
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    // Dicas para o app de Configuracoes rolar ate a linha deste
                    // app e dar o "pulso" de destaque, em vez de largar o
                    // produtor na lista crua. Alguns fabricantes ignoram e ai
                    // cai na lista mesmo -- e o melhor que o sistema oferece.
                    val chaveDestaque = packageName
                    intent.putExtra(":settings:fragment_args_key", chaveDestaque)
                    val args = Bundle()
                    args.putString(":settings:fragment_args_key", chaveDestaque)
                    intent.putExtra(":settings:show_fragment_args", args)
                    startActivity(intent)
                    resultado.success(true)
                } catch (erro: Exception) {
                    resultado.success(false)
                }
            } else {
                resultado.notImplemented()
            }
        }
    }
}
