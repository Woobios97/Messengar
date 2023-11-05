//
//  ChatViewController.swift
//  Messengar
//
//  Created by 김우섭 on 11/1/23.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import AVFoundation
import AVKit
import CoreLocation

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

struct Media: MediaItem {
    var url: URL?
    var image: UIImage?
    var placeholderImage: UIImage
    var size: CGSize
}

struct Location: LocationItem {
    var location: CLLocation
    var size: CGSize
}

class ChatViewController: MessagesViewController, CLLocationManagerDelegate {
    
    private var senderPhotoURL: URL?
    private var otherUserPhotoURL: URL?
    
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = .current
        return formatter
    }()
    
    public let otherUserEmail: String   // 대화 상대의 이메일 주소
    private var conversationId: String?
    public var isNewConversation = false    // 새로운 대화를 시작했는 지 혹은 기존 대화에 메시지를 추가하는 지를 나타내는 값
    let locationManager = CLLocationManager()
    
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
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
        setupInputButton()
        
        locationManager.delegate = self
        requestLocationPermission()
    }
    
    func requestLocationPermission() {
           switch CLLocationManager.authorizationStatus() {
           case .notDetermined:
               locationManager.requestWhenInUseAuthorization()
           case .restricted, .denied:
               // 위치 서비스 거부됨. 사용자에게 설정에서 권한을 허용하도록 안내
               break
           case .authorizedWhenInUse, .authorizedAlways:
               // 위치 서비스 허용됨
               break
           @unknown default:
               break
           }
       }
    
    private func setupInputButton() {
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35, height: 35), animated: false)
        button.setImage(UIImage(systemName: "paperclip"), for: .normal)
        button.onTouchUpInside({ [weak self] _ in
            self?.presentInputActionSheet()
        })
        
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
    }
    
    private func presentInputActionSheet() {
        let actionSheet = UIAlertController(title: "첨부목록",
                                            message: "메세지에 무엇을 첨부할 것입니까?",
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "사진", style: .default, handler: { [weak self] _ in
            self?.presentPhotoInputActionSheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "비디오", style: .default, handler: { [weak self] _ in
            self?.presentVideoInputActionSheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "오디오", style: .default, handler: { _ in
            
        }))
        actionSheet.addAction(UIAlertAction(title: "위치", style: .default, handler: { [weak self] _ in
            self?.presentLocationPicker()
        }))
        actionSheet.addAction(UIAlertAction(title: "취소", style: .cancel, handler: nil))
        
        present(actionSheet, animated: true)
    }
    
    private func presentLocationPicker() {
        let vc = LocationPickerViewController(coordinates: nil)
        vc.title = "위치를 선택해보세요"
        vc.navigationItem.largeTitleDisplayMode = .never
        vc.completion = { [weak self] selectedCoordinates in
            
            guard let strongSelf = self else {
                return
            }
            
            guard let messageId = strongSelf.createMessageId(),
                  let conversationId = strongSelf.conversationId,
                  let selfSender = strongSelf.selfSender,
                  let name = strongSelf.title else {
                return
            }
            
            let longtitude: Double = selectedCoordinates.longitude
            let latitude: Double = selectedCoordinates.latitude
            
            print(#fileID, #function, #line, "this is - \(longtitude), \(latitude)")
            
            let location = Location(location: CLLocation(latitude: latitude, longitude: longtitude),
                                 size: .zero)
            
            let message = Message(sender: selfSender,
                                  messageId: messageId,
                                  sentDate: Date(),
                                  kind: .location(location))
            
            DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message, completion: { success in
                if success {
                    print(#fileID, #function, #line, "this is - 위치보내기성공")
                } else {
                    print(#fileID, #function, #line, "this is - 위치보내기실패")
                }
            })
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func presentPhotoInputActionSheet() {
        let actionSheet = UIAlertController(title: "사진",
                                            message: "사진을 어디로부터 첨부할 것입니까?",
                                            preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "카메라", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "앨범", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "취소", style: .cancel, handler: nil))
        
        present(actionSheet, animated: true)
    }
    
    private func presentVideoInputActionSheet() {
        let actionSheet = UIAlertController(title: "비디오",
                                            message: "비디오를 어디로부터 첨부할 것입니까?",
                                            preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "카메라", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "앨범", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "취소", style: .cancel, handler: nil))
        
        present(actionSheet, animated: true)
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
        if let conversationId = conversationId {
            listenForMessages(id: conversationId, shouldScrollToBottom: true)
        }
    }
}

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        guard let messageId = createMessageId(),
              let conversationId = conversationId,
              let selfSender = selfSender,
              let name = self.title
        else {
            return
        }
        
        if let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage,
           let imageData = image.pngData() {
            let fileName = "photo_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".png"
            
            // 이미지업로드
            StorageManager.shared.uploadMessagePhoto(with: imageData, fileName: fileName, completion: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                switch result {
                case .success(let urlString):
                    // 메시지 준비하기
                    print(#fileID, #function, #line, "this is - 업로딩메세지 사진 \(urlString)")
                    
                    guard let url = URL(string: urlString),
                          let placeholder = UIImage(systemName: "plus") else {
                        return
                    }
                    
                    let media = Media(url: url,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: .zero)
                    
                    let message = Message(sender: selfSender,
                                          messageId: messageId,
                                          sentDate: Date(),
                                          kind: .photo(media))
                    
                    DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message, completion: { success in
                        if success {
                            print(#fileID, #function, #line, "this is - 사진보내기 ")
                        } else {
                            print(#fileID, #function, #line, "this is - 사진보내기실패")
                        }
                    })
                    
                case .failure(let error):
                    print(#fileID, #function, #line, "this is - 이미지 메세지 보내기 실패\(error)")
                }
            })
        } else if let videoUrl = info[.mediaURL] as? URL {
            let fileName = "photo_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".mov"
            
            // 비디오 업로드
            StorageManager.shared.uploadMessageVideo(with: videoUrl, fileName: fileName, completion: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                switch result {
                case .success(let urlString):
                    // 메시지 준비하기
                    print(#fileID, #function, #line, "this is - 업로딩메세지 비디오 \(urlString)")
                    
                    guard let url = URL(string: urlString),
                          let placeholder = UIImage(systemName: "plus") else {
                        return
                    }
                    
                    let media = Media(url: url,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: .zero)
                    
                    let message = Message(sender: selfSender,
                                          messageId: messageId,
                                          sentDate: Date(),
                                          kind: .video(media))
                    
                    DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message, completion: { success in
                        if success {
                            print(#fileID, #function, #line, "this is - 사진보내기 ")
                        } else {
                            print(#fileID, #function, #line, "this is - 사진보내기실패")
                        }
                    })
                    
                case .failure(let error):
                    print(#fileID, #function, #line, "this is - 이미지 메세지 보내기 실패\(error)")
                }
            })
        }
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
                    let newConversationId = "conversation_\(message.messageId)"
                    self?.conversationId = newConversationId
                    self?.listenForMessages(id: newConversationId, shouldScrollToBottom: true)
                    self?.messageInputBar.inputTextView.text = nil
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
            DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: otherUserEmail, name: name, newMessage: message, completion: { [weak self] success in
                if success {
                    self?.messageInputBar.inputTextView.text = nil
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
    
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let message = message as? Message else {
            return
        }
        
        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else {
                return
            }
            imageView.sd_setImage(with: imageUrl, completed: nil)
        default:
            break
        }
    }
    
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        let sender = message.sender
        if sender.senderId == selfSender?.senderId {
            // 우리가 보낸 메세지
            return .link
        }
        return .green
    }
    
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        let sender = message.sender
        
        if sender.senderId == selfSender?.senderId {
            // 본인 이미지
            if let currentUserImageURL = self.senderPhotoURL {
                avatarView.sd_setImage(with: currentUserImageURL, completed: nil)
            } else {
                guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
                    return
                }
                
                let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
                let path = "images/\(safeEmail)_profile_picture.png"
                
                // fetch URL
                StorageManager.shared.downloadURL(for: path, completion: { [weak self] result in
                    switch result {
                    case .success(let url):
                        self?.senderPhotoURL = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url, completed: nil)
                        }
                    case .failure(let error):
                        print(#fileID, #function, #line, "this is - \(error)")
                    }
                })
            }
        }
        else {
            // 대화상대 이미지
            if let otherUserPhotoURL = self.otherUserPhotoURL {
                avatarView.sd_setImage(with: otherUserPhotoURL, completed: nil)
            } else {
                // fetch URL
                let email = self.otherUserEmail
                
                let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
                let path = "images/\(safeEmail)_profile_picture.png"
                
                // fetch URL
                StorageManager.shared.downloadURL(for: path, completion: { [weak self] result in
                    switch result {
                    case .success(let url):
                        self?.otherUserPhotoURL = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url, completed: nil)
                        }
                    case .failure(let error):
                        print(#fileID, #function, #line, "this is - \(error)")
                    }
                })
            }
        }

    }
    
}

extension ChatViewController: MessageCellDelegate {
    
    func didTapMessage(in cell: MessageCollectionViewCell) {
        print(#fileID, #function, #line, "this is - ")
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            return
        }
        let message = messages[indexPath.section]
        print(#fileID, #function, #line, "this is - \(message)")
        switch message.kind {
        case .location(let locationData):
            let coordinates = locationData.location.coordinate
            let vc = LocationPickerViewController(coordinates: coordinates)
            vc.title = "위치"
            self.navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }
    
    func didTapImage(in cell: MessageCollectionViewCell) {
        print(#fileID, #function, #line, "this is - ")
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            return
        }
        let message = messages[indexPath.section]
        print(#fileID, #function, #line, "this is - \(message)")
        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else {
                return
            }
            let vc = PhotoViewerViewController(with: imageUrl)
            self.navigationController?.pushViewController(vc, animated: true)
        case .video(let media):
            guard let videoUrl = media.url else {
                return
            }
            let vc = AVPlayerViewController()
            vc.player = AVPlayer(url: videoUrl)
            present(vc, animated: true)
            
        default:
            break
        }
    }
}
