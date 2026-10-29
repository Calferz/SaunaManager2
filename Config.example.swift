//
//  Config.example.swift
//  設定ファイルのひな形。Saunamanager2/ フォルダに Config.swift としてコピーし、URLを書き換えて使う。
//  （このファイルはビルド対象外。Config.swift は .gitignore で除外されている）
//

enum Config {
    // Google Apps Script のウェブアプリURL（デプロイ後に発行されるURL）
    static let sheetsWebAppURL = "https://script.google.com/macros/s/YOUR_DEPLOYMENT_ID/exec"
}
