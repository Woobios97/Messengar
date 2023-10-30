//
//  ConservationViewController.swift
//  Messengar
//
//  Created by 김우섭 on 10/30/23.
//

import UIKit

class ConservationViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .red
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let isLoggedIn = UserDefaults.standard.bool(forKey: "logged_in")
        
        if !isLoggedIn {
            let vc = LoginViewController()
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen // 로그인 후 화면닫기를 원하기 때문에 -> fullScreen
            present(nav, animated: false)
        }
    }


}

