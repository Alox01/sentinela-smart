package com.example.estufa_app

import android.content.Intent
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
            if (call.method == "abrirConfiguracoes") {
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
