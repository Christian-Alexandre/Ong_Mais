@echo off
rem Abre o ONG Mais ja instalado no emulador/celular conectado (util quando o icone nao aparece na tela inicial)
set PATH=%PATH%;%LOCALAPPDATA%\Android\Sdk\platform-tools
adb shell monkey -p br.com.ongmais.ong_mais -c android.intent.category.LAUNCHER 1
