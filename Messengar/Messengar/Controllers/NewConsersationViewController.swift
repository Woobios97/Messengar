//
//  NewConsersationViewController.swift
//  Messengar
//
//  Created by 김우섭 on 10/30/23.
//

import UIKit
import JGProgressHUD

class NewConsersationViewController: UIViewController {
    
    private let spinner = JGProgressHUD(style: .extraLight)
    
    private var users = [[String: String]]()
    private var results = [[String: String]]()
    private var hasFetched = false
    
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "유저를 검색해보세요"
        return searchBar
    }()
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.isHidden = true
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        return table
    }()
    
    private let noResultsLabel: UILabel = {
        let lable = UILabel()
        lable.isHidden = true
        lable.text = "결과가 없어요! 🙅🏻‍♂️"
        lable.textAlignment = .center
        lable.textColor = .systemBlue
        lable.numberOfLines = 0
        lable.font = .systemFont(ofSize: 40, weight: .medium)
        return lable
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(noResultsLabel)
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.topItem?.titleView = searchBar
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancle",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(dismissSelf))
        searchBar.becomeFirstResponder()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        noResultsLabel.frame = CGRect(x: 0,
                                      y: (view.frame.height - 100) / 2,
                                      width: view.frame.width,
                                      height: 100)
    }
    
    @objc private func dismissSelf() {
        dismiss(animated: true, completion: nil)
    }
    
}

extension NewConsersationViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = results[indexPath.row]["name"]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // 새로운 대화창
    }
    
    
}

extension NewConsersationViewController: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text, !text.isEmpty else {
            return
        }
        searchBar.resignFirstResponder()
        
        results.removeAll() // 새로운 검색이 있을 때마다 삭제
        spinner.show(in: view)
        
        self.searchUsers(query: text)
    }
    
    func searchUsers(query: String) {
        // 배열에 Firebase 결과가 있는 지 확인
        if hasFetched {
            // 그렇다면 필터
            filterUser(with: query)
        } else {
            // 그렇지 않다면 필터가져오기
            DatabaseManager.shared.getAllUsers(completion: { [weak self] result in
                switch result {
                case .success(let userCollection):
                    self?.hasFetched = true
                    self?.users = userCollection
                    self?.filterUser(with: query)
                case .failure(let error):
                    print(#fileID, #function, #line, "this is - 유저가져오기 실패 \(error)")
                }
            })
        }
    }
    
    func filterUser(with term: String) {
        // 업데이트 UI: 결과를 표시하거나 결과 없음 레이블을 표시하거나
        guard hasFetched else {
            return
        }
        
        self.spinner.dismiss()
        
        var results: [[String: String]] = self.users.filter ({
            guard let name = $0["name"]?.lowercased() else {
                return false
            }
            return name.hasPrefix(term.lowercased())
        })
        
        self.results = results
        updateUI()
    }
    
    func updateUI() {
        if results.isEmpty {
            self.noResultsLabel.isHidden = false
            self.tableView.isHidden = true
        } else {
            self.noResultsLabel.isHidden = true
            self.tableView.isHidden = false
            self.tableView.reloadData()
        }
    }
}
