#!/usr/bin/env python3
"""Generate MacCleaner .lproj Localizable.strings from English + PureMac phrase map + overrides."""

from __future__ import annotations

import json
import plistlib
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EN = ROOT / "OpenCleanMyMac/Sources/OpenCleanMyMac/Resources/en.lproj/Localizable.strings"
RES = ROOT / "OpenCleanMyMac/Sources/OpenCleanMyMac/Resources"
PUREMAC = Path("/Applications/PureMac.app/Contents/Resources")

LANGS = {
    "de": "de",
    "fr": "fr",
    "es": "es",
    "pt-BR": "pt-BR",
    "ja": "ja",
    "zh-Hans": "zh-Hans",
    "el": "el",
    "ru": "ru",
}

# MacCleaner-specific / missing phrases → per-locale overrides (English key value → translation).
OVERRIDES: dict[str, dict[str, str]] = {
    "de": {
        "Applications": "Programme",
        "Orphan Finder": "Verwaiste Dateien",
        "Performance": "Leistung",
        "Startup": "Startobjekte",
        "Developer Cleanup": "Entwickler-Aufräumen",
        "Privileged Helper": "Privilegierter Helper",
        "Space Explorer": "Speicher-Explorer",
        "Privacy & Space": "Datenschutz & Speicher",
        "Duplicate Finder": "Duplikatfinder",
        "Similar Photos": "Ähnliche Fotos",
        "Schedule": "Zeitplan",
        "Updates": "Updates",
        "Settings": "Einstellungen",
        "Smart Care": "Smart Care",
        "Overview": "Übersicht",
        "Tools": "Werkzeuge",
        "Mail Downloads": "Mail-Downloads",
        "Attachments saved from Apple Mail": "Aus Apple Mail gespeicherte Anhänge",
        "Mail Data": "Mail-Daten",
        "Envelope indexes — optional; Mail may rebuild them (off by default)": "Envelope-Indexes — optional; Mail kann sie neu aufbauen (standardmäßig aus)",
        "Updates from Homebrew": "Updates von Homebrew",
        "Review and update apps installed as Homebrew casks. Requires a local Homebrew install.": "Homebrew-Cask-Apps prüfen und aktualisieren. Erfordert eine lokale Homebrew-Installation.",
        "Check installed cask apps": "Installierte Cask-Apps prüfen",
        "Check casks": "Casks prüfen",
        "Checking Homebrew casks…": "Homebrew-Casks werden geprüft…",
        "Upgrade selected": "Auswahl aktualisieren",
        "Upgrading %@…": "%@ wird aktualisiert…",
        "%lld cask(s) have updates": "%lld Cask(s) haben Updates",
        "Homebrew apps are up to date": "Homebrew-Apps sind aktuell",
        "No updates are currently available for the cask apps Homebrew manages.": "Derzeit keine Updates für von Homebrew verwaltete Cask-Apps.",
        "Homebrew was not found in a standard installation location.": "Homebrew wurde an keinem Standardpfad gefunden.",
        "Homebrew command failed.": "Homebrew-Befehl fehlgeschlagen.",
        "Homebrew returned update information that could not be read.": "Homebrew lieferte nicht lesbare Update-Informationen.",
        "Homebrew updated the %lld selected app(s).": "Homebrew hat %lld ausgewählte App(s) aktualisiert.",
        "Updated %lld · %lld failed — check again to verify.": "%lld aktualisiert · %lld fehlgeschlagen — erneut prüfen.",
        "Memory pressure": "Speicherdruck",
        "Compressed %@": "Komprimiert %@",
        "Uptime": "Betriebszeit",
        "Since last restart": "Seit dem letzten Neustart",
        "Open Activity Monitor": "Aktivitätsanzeige öffnen",
        "System processes are best inspected in Activity Monitor.": "Systemprozesse prüfst du am besten in der Aktivitätsanzeige.",
        "Choose System to follow macOS, or force a language shipped with MacCleaner.": "System folgen oder eine mitgelieferte Sprache erzwingen.",
        "Deutsch": "Deutsch",
        "Français": "Français",
        "Español": "Español",
        "Português": "Português",
        "日本語": "日本語",
        "简体中文": "简体中文",
        "English": "English",
        "Italiano": "Italiano",
        "System": "System",
    },
    "fr": {
        "Applications": "Applications",
        "Orphan Finder": "Fichiers orphelins",
        "Performance": "Performances",
        "Startup": "Démarrage",
        "Developer Cleanup": "Nettoyage développeur",
        "Privileged Helper": "Helper privilégié",
        "Space Explorer": "Explorateur d’espace",
        "Privacy & Space": "Confidentialité et espace",
        "Duplicate Finder": "Doublons",
        "Similar Photos": "Photos similaires",
        "Schedule": "Planification",
        "Updates": "Mises à jour",
        "Settings": "Réglages",
        "Overview": "Aperçu",
        "Tools": "Outils",
        "Mail Downloads": "Téléchargements Mail",
        "Attachments saved from Apple Mail": "Pièces jointes enregistrées depuis Apple Mail",
        "Mail Data": "Données Mail",
        "Envelope indexes — optional; Mail may rebuild them (off by default)": "Index envelope — optionnel ; Mail peut les reconstruire (désactivé par défaut)",
        "Updates from Homebrew": "Mises à jour Homebrew",
        "Review and update apps installed as Homebrew casks. Requires a local Homebrew install.": "Vérifiez et mettez à jour les apps installées en casks Homebrew. Homebrew local requis.",
        "Check installed cask apps": "Vérifier les casks installés",
        "Check casks": "Vérifier les casks",
        "Checking Homebrew casks…": "Vérification des casks Homebrew…",
        "Upgrade selected": "Mettre à jour la sélection",
        "Upgrading %@…": "Mise à jour de %@…",
        "%lld cask(s) have updates": "%lld cask(s) ont des mises à jour",
        "Homebrew apps are up to date": "Les apps Homebrew sont à jour",
        "No updates are currently available for the cask apps Homebrew manages.": "Aucune mise à jour pour les casks gérés par Homebrew.",
        "Homebrew was not found in a standard installation location.": "Homebrew introuvable dans un emplacement standard.",
        "Homebrew command failed.": "Échec de la commande Homebrew.",
        "Homebrew returned update information that could not be read.": "Homebrew a renvoyé des infos illisibles.",
        "Homebrew updated the %lld selected app(s).": "Homebrew a mis à jour %lld app(s) sélectionnée(s).",
        "Updated %lld · %lld failed — check again to verify.": "%lld mises à jour · %lld échecs — revérifiez.",
        "Memory pressure": "Pression mémoire",
        "Compressed %@": "Compressée %@",
        "Uptime": "Disponibilité",
        "Since last restart": "Depuis le dernier redémarrage",
        "Open Activity Monitor": "Ouvrir Moniteur d’activité",
        "System processes are best inspected in Activity Monitor.": "Les processus système se consultent mieux dans Moniteur d’activité.",
        "Choose System to follow macOS, or force a language shipped with MacCleaner.": "Suivre le système ou forcer une langue fournie avec MacCleaner.",
    },
    "es": {
        "Applications": "Aplicaciones",
        "Orphan Finder": "Archivos huérfanos",
        "Performance": "Rendimiento",
        "Startup": "Inicio",
        "Developer Cleanup": "Limpieza para desarrolladores",
        "Privileged Helper": "Helper privilegiado",
        "Space Explorer": "Explorador de espacio",
        "Privacy & Space": "Privacidad y espacio",
        "Duplicate Finder": "Duplicados",
        "Similar Photos": "Fotos similares",
        "Schedule": "Programación",
        "Updates": "Actualizaciones",
        "Settings": "Ajustes",
        "Overview": "Resumen",
        "Tools": "Herramientas",
        "Mail Downloads": "Descargas de Mail",
        "Attachments saved from Apple Mail": "Adjuntos guardados desde Apple Mail",
        "Mail Data": "Datos de Mail",
        "Envelope indexes — optional; Mail may rebuild them (off by default)": "Índices envelope — opcional; Mail puede reconstruirlos (desactivado por defecto)",
        "Updates from Homebrew": "Actualizaciones de Homebrew",
        "Review and update apps installed as Homebrew casks. Requires a local Homebrew install.": "Revisa y actualiza apps instaladas como casks de Homebrew. Requiere Homebrew local.",
        "Check installed cask apps": "Comprobar casks instalados",
        "Check casks": "Comprobar casks",
        "Checking Homebrew casks…": "Comprobando casks de Homebrew…",
        "Upgrade selected": "Actualizar seleccionados",
        "Upgrading %@…": "Actualizando %@…",
        "%lld cask(s) have updates": "%lld cask(s) tienen actualizaciones",
        "Homebrew apps are up to date": "Las apps de Homebrew están al día",
        "No updates are currently available for the cask apps Homebrew manages.": "No hay actualizaciones para los casks gestionados por Homebrew.",
        "Homebrew was not found in a standard installation location.": "No se encontró Homebrew en una ubicación estándar.",
        "Homebrew command failed.": "Falló el comando de Homebrew.",
        "Homebrew returned update information that could not be read.": "Homebrew devolvió información ilegible.",
        "Homebrew updated the %lld selected app(s).": "Homebrew actualizó %lld app(s) seleccionada(s).",
        "Updated %lld · %lld failed — check again to verify.": "Actualizadas %lld · %lld fallaron — vuelve a comprobar.",
        "Memory pressure": "Presión de memoria",
        "Compressed %@": "Comprimida %@",
        "Uptime": "Tiempo activo",
        "Since last restart": "Desde el último reinicio",
        "Open Activity Monitor": "Abrir Monitor de actividad",
        "System processes are best inspected in Activity Monitor.": "Los procesos del sistema se revisan mejor en Monitor de actividad.",
        "Choose System to follow macOS, or force a language shipped with MacCleaner.": "Elige Sistema para seguir macOS, o fuerza un idioma incluido en MacCleaner.",
    },
    "pt-BR": {
        "Applications": "Aplicativos",
        "Orphan Finder": "Arquivos órfãos",
        "Performance": "Desempenho",
        "Startup": "Inicialização",
        "Developer Cleanup": "Limpeza para desenvolvedores",
        "Privileged Helper": "Helper privilegiado",
        "Space Explorer": "Explorador de espaço",
        "Privacy & Space": "Privacidade e espaço",
        "Duplicate Finder": "Duplicatas",
        "Similar Photos": "Fotos semelhantes",
        "Schedule": "Agendamento",
        "Updates": "Atualizações",
        "Settings": "Ajustes",
        "Overview": "Visão geral",
        "Tools": "Ferramentas",
        "Mail Downloads": "Downloads do Mail",
        "Attachments saved from Apple Mail": "Anexos salvos do Apple Mail",
        "Mail Data": "Dados do Mail",
        "Envelope indexes — optional; Mail may rebuild them (off by default)": "Índices envelope — opcional; o Mail pode reconstruí-los (desativado por padrão)",
        "Updates from Homebrew": "Atualizações do Homebrew",
        "Review and update apps installed as Homebrew casks. Requires a local Homebrew install.": "Revise e atualize apps instalados como casks do Homebrew. Requer Homebrew local.",
        "Check installed cask apps": "Verificar casks instalados",
        "Check casks": "Verificar casks",
        "Checking Homebrew casks…": "Verificando casks do Homebrew…",
        "Upgrade selected": "Atualizar selecionados",
        "Upgrading %@…": "Atualizando %@…",
        "%lld cask(s) have updates": "%lld cask(s) têm atualizações",
        "Homebrew apps are up to date": "Apps do Homebrew estão atualizados",
        "No updates are currently available for the cask apps Homebrew manages.": "Nenhuma atualização para os casks gerenciados pelo Homebrew.",
        "Homebrew was not found in a standard installation location.": "Homebrew não encontrado em um local padrão.",
        "Homebrew command failed.": "Comando do Homebrew falhou.",
        "Homebrew returned update information that could not be read.": "Homebrew retornou informações ilegíveis.",
        "Homebrew updated the %lld selected app(s).": "Homebrew atualizou %lld app(s) selecionado(s).",
        "Updated %lld · %lld failed — check again to verify.": "Atualizados %lld · %lld falharam — verifique de novo.",
        "Memory pressure": "Pressão de memória",
        "Compressed %@": "Comprimida %@",
        "Uptime": "Tempo ativo",
        "Since last restart": "Desde a última reinicialização",
        "Open Activity Monitor": "Abrir Monitor de Atividade",
        "System processes are best inspected in Activity Monitor.": "Processos do sistema são melhor inspecionados no Monitor de Atividade.",
        "Choose System to follow macOS, or force a language shipped with MacCleaner.": "Escolha Sistema para seguir o macOS ou force um idioma incluído no MacCleaner.",
    },
    "ja": {
        "Applications": "アプリケーション",
        "Orphan Finder": "孤立ファイル",
        "Performance": "パフォーマンス",
        "Startup": "起動項目",
        "Developer Cleanup": "開発クリーンアップ",
        "Privileged Helper": "特権ヘルパー",
        "Space Explorer": "スペースエクスプローラー",
        "Privacy & Space": "プライバシーと空き容量",
        "Duplicate Finder": "重複ファイル",
        "Similar Photos": "類似写真",
        "Schedule": "スケジュール",
        "Updates": "アップデート",
        "Settings": "設定",
        "Overview": "概要",
        "Tools": "ツール",
        "Mail Downloads": "メールのダウンロード",
        "Attachments saved from Apple Mail": "Apple Mail から保存した添付ファイル",
        "Mail Data": "メールデータ",
        "Envelope indexes — optional; Mail may rebuild them (off by default)": "エンベロープ索引 — 任意。Mail が再構築する場合があります（既定オフ）",
        "Updates from Homebrew": "Homebrew のアップデート",
        "Review and update apps installed as Homebrew casks. Requires a local Homebrew install.": "Homebrew cask としてインストールしたアプリを確認・更新します。ローカルの Homebrew が必要です。",
        "Check installed cask apps": "インストール済み cask を確認",
        "Check casks": "cask を確認",
        "Checking Homebrew casks…": "Homebrew cask を確認中…",
        "Upgrade selected": "選択項目をアップグレード",
        "Upgrading %@…": "%@ をアップグレード中…",
        "%lld cask(s) have updates": "%lld 個の cask に更新があります",
        "Homebrew apps are up to date": "Homebrew アプリは最新です",
        "No updates are currently available for the cask apps Homebrew manages.": "Homebrew が管理する cask に更新はありません。",
        "Homebrew was not found in a standard installation location.": "標準の場所に Homebrew が見つかりません。",
        "Homebrew command failed.": "Homebrew コマンドが失敗しました。",
        "Homebrew returned update information that could not be read.": "Homebrew から読めない更新情報が返りました。",
        "Homebrew updated the %lld selected app(s).": "Homebrew が選択した %lld 個のアプリを更新しました。",
        "Updated %lld · %lld failed — check again to verify.": "%lld 件更新 · %lld 件失敗 — 再確認してください。",
        "Memory pressure": "メモリ圧迫",
        "Compressed %@": "圧縮 %@",
        "Uptime": "稼働時間",
        "Since last restart": "前回の再起動から",
        "Open Activity Monitor": "アクティビティモニタを開く",
        "System processes are best inspected in Activity Monitor.": "システムプロセスはアクティビティモニタで確認するのが最適です。",
        "Choose System to follow macOS, or force a language shipped with MacCleaner.": "システムに合わせるか、MacCleaner 同梱の言語を指定します。",
    },
    "zh-Hans": {
        "Applications": "应用程序",
        "Orphan Finder": "孤立文件",
        "Performance": "性能",
        "Startup": "启动项",
        "Developer Cleanup": "开发清理",
        "Privileged Helper": "特权助手",
        "Space Explorer": "空间浏览器",
        "Privacy & Space": "隐私与空间",
        "Duplicate Finder": "重复文件",
        "Similar Photos": "相似照片",
        "Schedule": "计划任务",
        "Updates": "更新",
        "Settings": "设置",
        "Overview": "概览",
        "Tools": "工具",
        "Mail Downloads": "邮件下载",
        "Attachments saved from Apple Mail": "从 Apple Mail 保存的附件",
        "Mail Data": "邮件数据",
        "Envelope indexes — optional; Mail may rebuild them (off by default)": "Envelope 索引 — 可选；邮件可能会重建（默认关闭）",
        "Updates from Homebrew": "Homebrew 更新",
        "Review and update apps installed as Homebrew casks. Requires a local Homebrew install.": "查看并更新以 Homebrew cask 安装的应用。需要本地 Homebrew。",
        "Check installed cask apps": "检查已安装的 cask",
        "Check casks": "检查 cask",
        "Checking Homebrew casks…": "正在检查 Homebrew cask…",
        "Upgrade selected": "升级所选",
        "Upgrading %@…": "正在升级 %@…",
        "%lld cask(s) have updates": "%lld 个 cask 有更新",
        "Homebrew apps are up to date": "Homebrew 应用已是最新",
        "No updates are currently available for the cask apps Homebrew manages.": "Homebrew 管理的 cask 暂无可用更新。",
        "Homebrew was not found in a standard installation location.": "未在标准位置找到 Homebrew。",
        "Homebrew command failed.": "Homebrew 命令失败。",
        "Homebrew returned update information that could not be read.": "Homebrew 返回了无法读取的更新信息。",
        "Homebrew updated the %lld selected app(s).": "Homebrew 已更新所选的 %lld 个应用。",
        "Updated %lld · %lld failed — check again to verify.": "已更新 %lld · 失败 %lld — 请再次检查。",
        "Memory pressure": "内存压力",
        "Compressed %@": "已压缩 %@",
        "Uptime": "运行时间",
        "Since last restart": "自上次重启以来",
        "Open Activity Monitor": "打开活动监视器",
        "System processes are best inspected in Activity Monitor.": "系统进程最好在“活动监视器”中查看。",
        "Choose System to follow macOS, or force a language shipped with MacCleaner.": "选择“系统”以跟随 macOS，或强制使用 MacCleaner 附带的语言。",
    },
}


def load_strings(path: Path) -> dict[str, str]:
    data = subprocess.check_output(
        ["/usr/bin/plutil", "-convert", "json", "-o", "-", "--", str(path)],
        text=True,
    )
    return json.loads(data)


def escape_strings_value(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
    )


def write_strings(path: Path, mapping: dict[str, str], header: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [header, ""]
    for key in sorted(mapping.keys()):
        lines.append(f'"{escape_strings_value(key)}" = "{escape_strings_value(mapping[key])}";')
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def phrase_map(lang_folder: str) -> dict[str, str]:
    en_path = PUREMAC / "en.lproj" / "Localizable.strings"
    loc_path = PUREMAC / f"{lang_folder}.lproj" / "Localizable.strings"
    if not en_path.exists() or not loc_path.exists():
        return {}
    en = load_strings(en_path)
    loc = load_strings(loc_path)
    out: dict[str, str] = {}
    for key, en_val in en.items():
        if key in loc and isinstance(en_val, str) and isinstance(loc[key], str):
            out[en_val] = loc[key]
    return out


def main() -> None:
    en = load_strings(EN)
    for code, pm_folder in LANGS.items():
        pm = phrase_map(pm_folder)
        overrides = OVERRIDES.get(code, {})
        merged = dict(overrides)
        # PureMac phrase map fills gaps; overrides win.
        for en_val, tr in pm.items():
            merged.setdefault(en_val, tr)

        out: dict[str, str] = {}
        missing = 0
        for key, en_val in en.items():
            if en_val in merged:
                out[key] = merged[en_val]
            else:
                out[key] = en_val
                missing += 1

        # Always keep language menu labels localized / native.
        for k in (
            "settings.language.german",
            "settings.language.french",
            "settings.language.spanish",
            "settings.language.portuguese",
            "settings.language.japanese",
            "settings.language.chinese",
            "settings.language.english",
            "settings.language.italian",
            "settings.language.system",
        ):
            if k in en:
                out[k] = overrides.get(en[k], en[k]) if False else en[k]
                # Prefer native script from EN file for these labels.
                out[k] = en[k]

        dest = RES / f"{code}.lproj" / "Localizable.strings"
        write_strings(
            dest,
            out,
            f"/* MacCleaner — {code} (generated from en + PureMac phrase map + overrides) */",
        )
        print(f"{code}: {len(out)} keys, {missing} left in English → {dest}")


if __name__ == "__main__":
    main()
