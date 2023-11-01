//
//  DatabaseManager.swift
//  Messengar
//
//  Created by 김우섭 on 10/31/23.
//

import Foundation
import FirebaseDatabase

enum DatabaseError: Error {
    case failedFetch
}

final class DatabaseManager {
    
    static let shared = DatabaseManager()
    
    private let database = Database.database(url: "https://messengar-28a8d-default-rtdb.asia-southeast1.firebasedatabase.app").reference()
    
    static func safeEmail(emailAddress: String) -> String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
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
            
            // 전체 사용자 정보 가져오기
            self.database.child("users").observeSingleEvent(of: .value, with: { snapshot in
                // 이미 'user'에 정보가 있다면, 새로운 사용자 정보를 기존의 배열에 추가한다.
                if var usersCollection = snapshot.value as? [[String: String]] {
                    // 유저딕셔너리 추가하기
                    let newElement =  [
                        "name": user.firstName + " " + user.lastName,
                         "email": user.safeEmail
                        ]
                    usersCollection.append(newElement)
                    
                    self.database.child("users").setValue(usersCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                    // 만약 'user'에 아무런 정보가 없다면, 새로운 배열을 생성하고 그 안의 사용자 정보를 추가한다.
                } else {
                    // 배열 생성하기
                    let newCollection: [[String: String]] = [
                        [
                        "name": user.firstName + " " + user.lastName,
                         "email": user.safeEmail
                        ]
                    ]
                    // users 키 아래에 사용자 정보를 업데이트한다.
                    self.database.child("users").setValue(newCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }
            })
            completion(true)
        })
    }
    
    public func getAllUsers(completion: @escaping (Result<[[String: String]], Error>) -> Void) {
        database.child("users").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value as? [[String: String]] else {
                completion(.failure(DatabaseError.failedFetch))
                return
            }
            completion(.success(value))
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
