//
//  UserListControllerTableViewController.swift
//  V-Labs-Test
//
//  Created by Stephane Darcy SIMO MBA on 12/10/2017.
//  Copyright © 2017 v-Labs. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import Kingfisher

func findFileURL(_ fileName: String) -> URL {
    return FileManager.default
        .urls(for: .cachesDirectory, in: .allDomainsMask)
        .first!
        .appendingPathComponent(fileName)
}

class UserListController: UITableViewController {
    
    let dataFound = "users"
    
    private let URLString = "https://jsonplaceholder.typicode.com/"
    private let userFileURL = findFileURL("userVLabs.plist")
    private let modifiedFileURL = findFileURL("modified.txt")
    
    fileprivate let lastModified = Variable<NSString?>(nil)
    fileprivate let users = Variable<[User]>([])
    fileprivate let bag = DisposeBag()

    // MARK: - ViewController Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Users List"

        self.refreshControl = UIRefreshControl()
        let refreshControl = self.refreshControl!
        
        refreshControl.backgroundColor = UIColor(white: 0.98, alpha: 1.0)
        refreshControl.tintColor = UIColor.darkGray
        refreshControl.attributedTitle = NSAttributedString(string: "refresh List")
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        
        let usersArray = (NSArray(contentsOf: userFileURL) as? [[ String : Any ]]) ?? []
        users.value = usersArray.flatMap(User.init)
        lastModified.value = try? NSString(contentsOf: modifiedFileURL, usedEncoding: nil)

        refresh()
    }
    
    @objc func refresh () {
        let eventQueue = DispatchQueue(label: "fetchUsersQueue")
        eventQueue.async {
            self.fetchUsers(dataFound: "users")
        }
    }
    
    // MARK: - RxSwift Methods
    
    func fetchUsers(dataFound: String) {
        if (Reachability.isConnectedToNetwork()) {
            let response = Observable.from([dataFound])
                .map { urlString -> URL in
                    return URL(string: "\(self.URLString)\(urlString)")!
            }
                .map { [weak self] url -> URLRequest in
                    var request = URLRequest(url: url)
                    if let modifiedHeader = self?.lastModified.value {
                        request.addValue(modifiedHeader as String, forHTTPHeaderField: "Last-Modified")
                    }
                    return request
            }
                .flatMap { request -> Observable<(HTTPURLResponse, Data)> in
                    return URLSession.shared.rx.response(request: request)
            }
            .shareReplay(1)
            
            response
                .filter { response, _ in
                    return 200 ..< 300 ~= response.statusCode
                }
                .map { _, data -> [[ String: Any ]] in
                    guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                        let result = jsonObject as? [[String : Any]] else {
                            return []
                    }
                    return result
                }
                .filter { objects in
                    return objects.count > 0
                }
                .map { objects in
                    return objects.flatMap(User.init)
                }
                .subscribe(onNext: { [weak self] newUsers in
                    self?.processUsers(newUsers)
                })
                .addDisposableTo(bag)
            response
                .filter { response, _ in
                    return 200 ..< 400 ~= response.statusCode
                }
                .flatMap { response, _ -> Observable<NSString> in
                    guard let value = response.allHeaderFields["Last-Modified"]  as? NSString else {
                        return Observable.never()
                    }
                    return Observable.just(value)
                }
                .subscribe(onNext: { [weak self] modifiedHeader in
                    guard let strongSelf = self else { return }
                    strongSelf.lastModified.value = modifiedHeader
                    try? modifiedHeader.write(to: strongSelf.modifiedFileURL, atomically: true,
                                              encoding: String.Encoding.utf8.rawValue)
                })
                .addDisposableTo(bag)
        } else {
            let alert = UIAlertController(title: "Pas de connexion", message: "Verifiez que vous êtes bien connecté à internet", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func processUsers(_ newUsers: [User]) {
        var updatedUsers = newUsers + users.value
        if updatedUsers.count > 100 {
            updatedUsers = Array<User>(updatedUsers.prefix(upTo: 100))
        }
        users.value = updatedUsers
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.refreshControl?.endRefreshing()
        }
        
        let usersArray = updatedUsers.map{ $0.dictionary } as NSArray
        usersArray.write(to: userFileURL, atomically: true)
    }
    
    // MARK: Send Segue
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "AlbumPhoto" {
            let vc = segue.destination as! PhotoAlbumController
            vc.userId = sender as? Int
        }
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.value.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! UserTableViewCell
        
        let user = users.value[indexPath.row]
        cell.nameLabel.text = user.name
        cell.usernameLabel.text = user.username
        let url = URL(string: "User_icon")
        cell.imageView?.kf.setImage(with: url)

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        performSegue(withIdentifier: "AlbumPhoto", sender: users.value[indexPath.row].id)
    }

}
