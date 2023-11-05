//
//  ConversationModel.swift
//  Messengar
//
//  Created by 김우섭 on 11/6/23.
//

import Foundation

struct Conversation {
    let id: String
    let name: String
    let otherUserEmail: String
    let lastestMessage: LastestMessage
}

struct LastestMessage {
    let date: String
    let text: String
    let isRead: Bool
}
