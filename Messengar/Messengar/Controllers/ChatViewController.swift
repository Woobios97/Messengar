//
//  ChatViewController.swift
//  Messengar
//
//  Created by 김우섭 on 11/1/23.
//

import UIKit
import MessageKit
import InputBarAccessoryView

// 메시지의 기본 정보를 나타내는 구조체
struct Message: MessageType {
    public var sender: MessageKit.SenderType
    public var messageId: String
    public var sentDate: Date
    public var kind: MessageKit.MessageKind
}

extension MessageKind {
    var messageKindString: String {
        switch self {
        case .text(_):
            return "text"
        case .attributedText(_):
            return "attributed_text"
        case .photo(_):
            return "photo"
        case .video(_):
            return "video"
        case .location(_):
            return "location"
        case .emoji(_):
            return "emoji"
        case .audio(_):
            return "audio"
        case .contact(_):
            return "contact"
        case .linkPreview(_):
            return "likePreview"
        case .custom(_):
            return "custom"
        }
    }
}

// 메시지를 보낸 사람의 정보를 나타내는 구조체
struct Sender: SenderType {
    public var photoURL: String
    public var senderId: String
    public var displayName: String
}

class ChatViewController: MessagesViewController {
    
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = .current
        return formatter
    }()
    
    public let otherUserEmail: String   // 대화 상대의 이메일 주소
    private let conversationId: String?
    public var isNewConversation = false    // 새로운 대화를 시작했는 지 혹은 기존 대화에 메시지를 추가하는 지를 나타내는 값
    
    private var messages = [Message]()
    
    private var selfSender: Sender?  {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        return Sender(photoURL: "",
                      senderId: safeEmail,
                      displayName: "Me")
    }
        
    init(with email: String, id: String?) {
        self.conversationId = id
        self.otherUserEmail = email
        super.init(nibName: nil, bundle: nil)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .green
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messageInputBar.delegate = self
        
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
        if let conversationId = conversationId {
            listenForMessages(id: conversationId, shouldScrollToBottom: true)
        }
    }
    
    private func listenForMessages(id: String, shouldScrollToBottom: Bool) {
        DatabaseManager.shared.getAllMessageForConversation(with: id, completion: { [weak self] result in
            switch result {
            case .success(let message):
                print(#fileID, #function, #line, "this is - 메시지 불러오기 성공 \(message)")
                guard !message.isEmpty else {
                    return
                }
                self?.messages = message
                
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                    
                    if shouldScrollToBottom {
                        self?.messagesCollectionView.scrollToBottom()
                    }
                }
            case .failure(let error):
                print(#fileID, #function, #line, "this is - 메시지 불러오기 실패 \(error)")
            }
        })
    }
    
}

extension ChatViewController: InputBarAccessoryViewDelegate {
    
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        print(#fileID, #function, #line, "this is - send버튼눌림")
        guard !text.replacingOccurrences(of: "", with: "").isEmpty,
              let selfSender = self.selfSender,
              let messageId = createMessageId() else {
            return
        }
        print(#fileID, #function, #line, "this is - \(text)")
        let message = Message(sender: selfSender,
                              messageId: messageId,
                              sentDate: Date(),
                              kind: .text(text))
        // 메시지 보내기
        if isNewConversation {
            // 데이터베이스에 대화 생성
            DatabaseManager.shared.createnewConversation(with: otherUserEmail, name: self.title ?? "User", firstMessage: message, completion: { [weak self] success in
                if success {
                    print(#fileID, #function, #line, "this is - 메시지보내졌다")
                    self?.isNewConversation = false
                } else {
                    print(#fileID, #function, #line, "this is - 메시지보내기실패")
                }
            })
        } 
        else {
            guard let conversationId = conversationId, let name = self.title else {
                return
            }
            // 기존 대화 데이터에 추가
            DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: otherUserEmail, name: name, newMessage: message, completion: { success in
                if success {
                    print(#fileID, #function, #line, "this is - 메시지 보내기 성공")
                } else {
                    print(#fileID, #function, #line, "this is - 메시지 보내기 실패")
                }
            })
        }
    }
    
    private func createMessageId() -> String? {
        // 날짜, 다른유저이메일, 보낸이의 이메일, 랜덤숫자
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let safeCurrentEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        
        let dateString = Self.dateFormatter.string(from: Date())
        let newIdentifier = "\(otherUserEmail)_\(safeCurrentEmail)_\(dateString)"
        
        print(#fileID, #function, #line, "this is - 메시지만든 id \(newIdentifier)")
        return newIdentifier
    }
}

extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
    
    func currentSender() -> SenderType {
        if let sender = selfSender {
            return sender
        }
        fatalError("본인 발신자가 없습니다. 이메일은 캐시되어야 합니다.")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessageKit.MessagesCollectionView) -> MessageKit.MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessageKit.MessagesCollectionView) -> Int {
        return messages.count
    }
}
