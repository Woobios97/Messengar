//
//  ProfileViewModel.swift
//  Messengar
//
//  Created by 김우섭 on 11/6/23.
//

import Foundation

enum ProfileViewModelType {
    case info
    case logout
}

struct ProfileViewModel {
    let viewModelType: ProfileViewModelType
    let title: String
    let handler: (() -> Void)?
}
