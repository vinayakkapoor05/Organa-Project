//
//  ContentView.swift
//  Organa
//
//  Created by Vinayak Kapoor on 12/4/24.
//

import SwiftUI

struct LoginView: View {
    @State private var userId = ""
    @State private var isLoggedIn = false
    
    var body: some View {
        VStack {
            if !isLoggedIn {
                Text("Organa")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                TextField("Enter User ID", text: $userId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                    .padding()
                
                Button(action: {
                    if !userId.isEmpty {
                        isLoggedIn = true
                    }
                }) {
                    Text("Login")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .disabled(userId.isEmpty)
            } else {
                MainView(userId: userId, isLoggedIn: $isLoggedIn)
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        LoginView()
    }
}
