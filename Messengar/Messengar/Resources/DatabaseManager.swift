//
//  DatabaseManager.swift
//  Messengar
//
//  Created by 김우섭 on 10/31/23.
//

import Foundation
import FirebaseDatabase

final class DatabaseManager {
    
    static let shared = DatabaseManager()
    
    private let database = Database.database(url: "https://messengar-28a8d-default-rtdb.asia-southeast1.firebasedatabase.app").reference()
}

// MARK: - 계정 관리
extension DatabaseManager {
    /// 유효성 검사
    public func userExists(with email: String,
                           completion: @escaping ((Bool) -> Void)) {
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        
        // 네트워킹 처리이기 때문에 @escaping 클로저로 처리한다.
        database.child(safeEmail).observeSingleEvent(of: .value, with: { snapshot in
            guard snapshot.value as? String != nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    /// 데이터베이스에 새로운유저 추가하기
    public func insertUser(with user: chatAppUser, completion: @escaping (Bool) -> Void) {
        // 이메일을 기준으로 사용자를 구분한다.
        database.child(user.safeEmail).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName
        ], withCompletionBlock: { error, _ in
            guard error == nil else {
                print(#fileID, #function, #line, "this is - 데이터베이스에 저장하는데 실패했다.")
                completion(false)
                return
            }
            completion(true)
        })
    }
}

struct chatAppUser {
    let firstName: String
    let lastName: String
    let emailAddress: String
    
    var safeEmail: String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
    var profilePictureFileName: String  {
        return "\(safeEmail)_profile_picture.png"
    }
    
}
