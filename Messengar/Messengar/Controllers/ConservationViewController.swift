//
//  ConservationViewController.swift
//  Messengar
//
//  Created by 김우섭 on 10/30/23.
//

import UIKit
import FirebaseAuth
import JGProgressHUD

/// 대화 목록을 보여주는 컨트롤러
final class ConservationViewController: UIViewController {
    
    private let spinner = JGProgressHUD(style: .extraLight)
    
    private var conversations = [Conversation]()
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.isHidden = true
        table.register(ConversationTableViewCell.self,
                       forCellReuseIdentifier: ConversationTableViewCell.identifier)
        return table
    }()
    
    private let noConversationLable: UILabel = {
        let label = UILabel()
        label.text = "대화가 없습니다!"
        label.textAlignment = .center
        label.textColor = .gray
        label.font = .systemFont(ofSize: 21, weight: .medium)
        label.isHidden = true
        return label
    }()
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        noConversationLable.frame = CGRect(x: 10,
                                           y: (view.height-100) / 2,
                                           width: view.width - 20,
                                           height: 100)
    }
    
    private var loginObserver: NSObjectProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(didTapComposeButton))
        view.backgroundColor = .systemBackground
        view.addSubview(tableView)
        view.addSubview(noConversationLable)
        
        setupTableView()
        
        startListeningForConversation()
        
        loginObserver = NotificationCenter.default.addObserver(forName: .didLogInNotification, object: nil, queue: .main, using: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.startListeningForConversation()
        })
    }
    
    private func startListeningForConversation() {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        
        if let observer = loginObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        DatabaseManager.shared.getAllConversations(for: safeEmail, completion: { [weak self] result in
            switch result {
            case .success(let conversations):
                guard !conversations.isEmpty else {
                    self?.tableView.isHidden = true
                    self?.noConversationLable.isHidden = false
                    return
                }
                self?.noConversationLable.isHidden = true
                self?.tableView.isHidden = false
                self?.conversations = conversations
                
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
                    
            case .failure(let error):
                self?.tableView.isHidden = true
                self?.noConversationLable.isHidden = false
                print(#fileID, #function, #line, "this is - 대화불러오기 실패 \(error)")
            }
        })
    }
    
    @objc private func didTapComposeButton() {
        let vc = NewConsersationViewController()
        vc.completion = { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            let currentConversations = strongSelf.conversations
            
            if let targetConversation = currentConversations.first(where: {
                $0.otherUserEmail == DatabaseManager.safeEmail(emailAddress: result.email)
            }) {
                let vc = ChatViewController(with: targetConversation.otherUserEmail, id: targetConversation.id)
                vc.isNewConversation = false
                vc.title = targetConversation.name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            } else {
                strongSelf.createNewConversation(result: result)
            }
        }
        let navVC = UINavigationController(rootViewController: vc)
        present(navVC, animated: true)
    }
    
    private func createNewConversation(result: SearchResult) {
        let name = result.name
        let email = DatabaseManager.safeEmail(emailAddress: result.email)
        
        // 이 두 사용자와의 대화가 존재하는지 데이터베이스에서 확인합니다.
        // 그렇다면 대화 ID를 재사용합니다.
        // 그렇지 않으면 기존 코드를 사용합니다.
        DatabaseManager.shared.conversationExists(with: email, completion: { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            switch result {
            case .success(let conversationId):
                let vc = ChatViewController(with: email, id: conversationId)
                vc.isNewConversation = false
                vc.title = name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            case .failure(_):
                let vc = ChatViewController(with: email, id: nil)
                vc.isNewConversation = true
                vc.title = name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            }
        })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        validateAuth()
    }
    
    // 유저 현재 로그인했는 지 안헀는 지의 여부
    private func validateAuth() {
        if FirebaseAuth.Auth.auth().currentUser == nil {
            let vc = LoginViewController()
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            // 로그인 후 화면닫기를 원하기 때문에 -> fullScreen
            present(nav, animated: true)
        }
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
    }
}

extension ConservationViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = conversations[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: ConversationTableViewCell.identifier, for: indexPath) as! ConversationTableViewCell
        cell.configure(with: model)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let model = conversations[indexPath.row]
        openConversation(model)
    }
    
    func openConversation(_ model: Conversation) {
        let vc = ChatViewController(with: model.otherUserEmail, id: model.id)
        vc.title = model.name
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(vc, animated: true)
    }
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // 삭제 시작
            let conversationId = conversations[indexPath.row].id
            tableView.beginUpdates()
            self.conversations.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .left)
            
            DatabaseManager.shared.deleteConversation(conversationsId: conversationId, completion: { success in
                if !success {
                   // 모델 및 행을 다시 추가하고 오류 경고 표시
                }
            })
            tableView.endUpdates()
        }
    }
    
}

