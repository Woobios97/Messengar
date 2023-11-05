//
//  LoginViewController.swift
//  Messengar
//
//  Created by 김우섭 on 10/30/23.
//

import UIKit
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import JGProgressHUD

class LoginViewController: UIViewController {
    
    private let spinner = JGProgressHUD(style: .extraLight)
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        return scrollView
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "logo")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let emailField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.attributedPlaceholder = NSAttributedString(
            string: "이메일를 입력해주세요",
            attributes: [NSAttributedString.Key.foregroundColor : UIColor.gray]
        )
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 15, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .white
        field.textColor = .black
        return field
    }()
    
    private let passwordField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.attributedPlaceholder = NSAttributedString(
            string: "비밀번호를 입력해주세요",
            attributes: [NSAttributedString.Key.foregroundColor : UIColor.gray]
        )
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 15, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .white
        field.isSecureTextEntry = true
        field.textColor = .black
        return field
    }()
    
    private let loginButton: UIButton = {
        let button = UIButton()
        button.setTitle("로그인", for: .normal)
        button.backgroundColor = .link
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return button
    }()
    
    private let GoogleloginButton: UIButton = {
        let button = UIButton()
        button.setTitle("구글로그인", for: .normal)
        button.backgroundColor = .link
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "로그인"
        view.backgroundColor = .blue
        
        // 타이틀 텍스트 색상 변경
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        
        let button = UIButton(type: .custom)
        button.frame = CGRect(x: 0, y: 0, width: 50, height: 50)  // 여기에서 크기를 설정합니다
        button.setTitle("등록", for: .normal)
        button.setTitleColor(UIColor.white, for: .normal)  // 버튼 텍스트 색상 설정
        button.addTarget(self, action: #selector(didTapRegister), for: .touchUpInside)
        
        let barButtonItem = UIBarButtonItem(customView: button)
        navigationItem.rightBarButtonItem = barButtonItem
        
        loginButton.addTarget(self,
                              action: #selector(loginButtonTapped),
                              for: .touchUpInside)
        
        GoogleloginButton.addTarget(self,
                                    action: #selector(googleLogin),
                                    for: .touchUpInside)
        
        emailField.delegate = self
        passwordField.delegate = self
        
        // Add Subviews
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(emailField)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(loginButton)
        scrollView.addSubview(GoogleloginButton)
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        let size = scrollView.width/3
        imageView.frame = CGRect(x: (scrollView.width-size)/2,
                                 y: 20,
                                 width: size,
                                 height: size)
        emailField.frame = CGRect(x: 30,
                                  y: imageView.bottom + 10,
                                  width: scrollView.width - 60,
                                  height: 52)
        passwordField.frame = CGRect(x: 30,
                                     y: emailField.bottom + 10,
                                     width: scrollView.width - 60,
                                     height: 52)
        loginButton.frame = CGRect(x: 30,
                                   y: passwordField.bottom + 10,
                                   width: scrollView.width - 60,
                                   height: 52)
        GoogleloginButton.frame = CGRect(x: 30,
                                         y: loginButton.bottom + 10,
                                         width: scrollView.width - 60,
                                         height: 52)
    }
    
    @objc private func loginButtonTapped() {
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()
        
        guard let email = emailField.text, let password = passwordField.text,
              !email.isEmpty, !password.isEmpty, password.count >= 6 else {
            alertUserLoginError()
            return
        }
        
        spinner.show(in: view)
        
        // Firebase Login
        FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password , completion: { [weak self] authResult, error in
            
            guard let strongself = self else {
                return
            }
            DispatchQueue.main.async {
                strongself.spinner.dismiss()
            }
            
            guard let result = authResult, error == nil else {
                print(#fileID, #function, #line, "this is - 로그인실패")
                return
            }
            let user = result.user
            let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
            DatabaseManager.shared.getDataFor(path: safeEmail, completion: { result in
                switch result {
                case .success(let data):
                    guard let userData = data as? [String: Any],
                          let firstName = userData["first_name"] as? String,
                          let lastName = userData["last_name"] as? String else {
                        return
                    }
                    UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
                case .failure(let error):
                    print(#fileID, #function, #line, "this is - 데이터불러오기실패 \(error)")
                }
            })
            
            UserDefaults.standard.set(email, forKey: "email") // 현재 로그인유저가 누구인 지 알기위해서 userDefaults에 저장
            
            print(#fileID, #function, #line, "this is - 로그인유저 : \(user.email)")
            strongself.navigationController?.dismiss(animated: true)
        })
    }
    
    func alertUserLoginError() {
        let alert = UIAlertController(title: "확인",
                                      message: "로그인을 먼저해주세요",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "취소",
                                      style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func didTapRegister() {
        let vc = RegisterViewController()
        vc.title = "Create Account"
        navigationController?.pushViewController(vc, animated: true)
    }
    
}

extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if textField == emailField {
            passwordField.becomeFirstResponder()
        }
        else if textField == passwordField {
            loginButtonTapped()
        }
        return true
    }
}

extension LoginViewController {
    
    @objc private func googleLogin() {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        
        // Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Start the sign in flow!
        GIDSignIn.sharedInstance.signIn(withPresenting: self) { [unowned self] result, error in
            guard let result = result, error == nil else {
                print(#fileID, #function, #line, "this is - ")
                return
            }
            
            guard let profile = result.user.profile else {
                return
            }
            
            let email = profile.email
            let firstName = profile.givenName
            let lastName = profile.familyName
            
            guard let firstName = firstName,
                  let lastName = lastName else {
                return
            }
            
            UserDefaults.standard.set(email, forKey: "email")   // // 현재 로그인유저가 누구인 지 알기위해서 userDefaults에 저장
            UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
            
            DatabaseManager.shared.userExists(with: email, completion: { exists in
                if !exists {
                    let chatUser = chatAppUser(firstName: firstName,
                                               lastName: lastName,
                                               emailAddress: email)
                    DatabaseManager.shared.insertUser(with: chatUser, completion: { success in
                        if success {
                            // 이미지 업로드
                            if profile.hasImage {
                                guard let url = profile.imageURL(withDimension: 200) else {
                                    return
                                }
                                URLSession.shared.dataTask(with: url, completionHandler: { data, _, _ in
                                    guard let data = data else {
                                        return
                                    }
                                    let fileName = chatUser.profilePictureFileName
                                    StorageManager.shared.uploadProfilePicture(with: data, fileName: fileName, completion: { result in
                                        switch result {
                                        case .success(let downloadUrl):
                                            UserDefaults.standard.set(downloadUrl, forKey: "profile_picture_url")
                                            print(#fileID, #function, #line, "this is - \(downloadUrl)")
                                        case .failure(let error):
                                            print(#fileID, #function, #line, "this is - \(error)")
                                        }
                                    })
                                    
                                })
                                .resume()
                            }
                        }
                    })
                }
            })
            
            let user = result.user
            
            print(#fileID, #function, #line, "this is - \(user)")
            guard let idToken = user.idToken?.tokenString else {
                print(#fileID, #function, #line, "this is - 토큰가져오기실패")
                return
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: user.accessToken.tokenString)
            Auth.auth().signIn(with: credential) { result, error in
                guard result != nil, error == nil else {
                    print(#fileID, #function, #line, "this is - 로그인실패")
                    return
                }
                self.navigationController?.dismiss(animated: true)
                print(#fileID, #function, #line, "this is - 로그인성공")
            }
            
        }
    }
}
