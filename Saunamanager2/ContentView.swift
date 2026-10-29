//
//  ContentView.swift
//  SaunaManager
//
//  Created on 2026/05/03.
//

// ContentView.swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: GuestStore
    @State private var selectedTab: Int = 1  // 起動時は在館中一覧を表示

    var body: some View {
        TabView(selection: $selectedTab) {

            // 在館中一覧
            GuestListView()
                .tabItem {
                    Label("在館中", systemImage: "person.3.fill")
                }
                .tag(1)

            // ロッカー状況表示
            LockerMapView()
                .tabItem {
                    Label("ロッカー", systemImage: "cabinet.fill")
                }
                .tag(2)
            
            // 履歴（今日の退館済み一覧）
            HistoryView()
                .tabItem {
                    Label("履歴", systemImage: "clock.arrow.circlepath")
                }
                .tag(3)
            
            // 週ごとの設定
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        // URLスキームから入館登録画面を開く
        //.sheet(isPresented: $store.showCheckIn, onDismiss: {
          //  store.clearPendingLockers()
        //}) {
          //  CheckInView()
            //    .environmentObject(store)
        //}
        .onAppear {
            store.load()
        }
    }
}
