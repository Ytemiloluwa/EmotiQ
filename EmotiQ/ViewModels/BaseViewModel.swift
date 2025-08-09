//
//  BaseViewModel.swift
//  EmotiQ
//
//  Created by Temiloluwa on 05-08-2025.
//

import Foundation
import Combine

class BaseViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    var cancellables = Set<AnyCancellable>()
    
    deinit {
        cancellables.removeAll()
    }
    
    func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
        }
    }
    
    func clearError() {
        errorMessage = nil

    }
    
    func setLoading(_ loading: Bool) {
        DispatchQueue.main.async {
            self.isLoading = loading
        }
    }
}

