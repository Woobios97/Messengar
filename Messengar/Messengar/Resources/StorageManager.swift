//
//  StorageManager.swift
//  Messengar
//
//  Created by 김우섭 on 11/1/23.
//

import Foundation
import FirebaseStorage

enum StorageError: Error {
    case failedToUploda
    case failedToDownloadURL
}

final class StorageManager {
    
    static let shared = StorageManager()
    
    private let storage =  Storage.storage().reference() // Firebase Storage의 루트 참조를 가져오기
    
    public typealias UploadPictureCompletion = (Result<String, Error>) -> Void
    
    /// Firebase 저장소에 사진을 업로드하고 다운로드할 URL 문자열로 완료를 반환합니다.
    public func uploadProfilePicture(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        storage.child("images/\(fileName)").putData(data, metadata: nil, completion: { metaData, error in
            guard error == nil else {
                // failed
                completion(.failure(StorageError.failedToUploda))
                return
            }
            
            self.storage.child("images/\(fileName)").downloadURL(completion: { url, error in
                guard let url = url else {
                    print(#fileID, #function, #line, "this is - ")
                    completion(.failure(StorageError.failedToDownloadURL))
                    return
                }
                
                let urlString = url.absoluteString
                print(#fileID, #function, #line, "this is - \(urlString)")
                completion(.success(urlString))
            })
        })
    }
    
    /// 대화 메시지로 보낼 이미지 업로드
    public func uploadMessagePhoto(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        storage.child("mesaage_images/\(fileName)").putData(data, metadata: nil, completion: { metaData, error in
            guard error == nil else {
                // failed
                completion(.failure(StorageError.failedToUploda))
                return
            }
            
            self.storage.child("mesaage_images/\(fileName)").downloadURL(completion: { url, error in
                guard let url = url else {
                    print(#fileID, #function, #line, "this is - ")
                    completion(.failure(StorageError.failedToDownloadURL))
                    return
                }
                
                let urlString = url.absoluteString
                print(#fileID, #function, #line, "this is - \(urlString)")
                completion(.success(urlString))
            })
        })
    }
    
    public func downloadURL(for path: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let reference = storage.child(path)
        reference.downloadURL(completion: { url, error in
            guard let url = url, error == nil else {
                completion(.failure(StorageError.failedToDownloadURL))
                return
            }
            completion(.success(url))
        })
    }
    
}
