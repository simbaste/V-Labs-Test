//
//  PhotoAlbumController.swift
//  V-Labs-Test
//
//  Created by Stephane Darcy SIMO MBA on 13/10/2017.
//  Copyright © 2017 v-Labs. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import Kingfisher
import RxDataSources

func cachedFileURL(_ fileName: String) -> URL {
    return FileManager.default
        .urls(for: .cachesDirectory, in: .allDomainsMask)
        .first!
        .appendingPathComponent(fileName)
}

private let reuseIdentifier = "PhotoCell"

class PhotoAlbumController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    
    public var userId: Int?
    
    private let URLString = "https://jsonplaceholder.typicode.com/"
    private let albumsFileURL = cachedFileURL("albums.plist")
    private let modifiedAlbFileURL = cachedFileURL("modifiedAlb.txt")
    
    fileprivate let sectionInsets = UIEdgeInsets(top: 20.0, left: 10.0, bottom: 10.0, right: 10.0)
    fileprivate let itemsPerRow: CGFloat = 4
    fileprivate let lastModifiedAlb = Variable<NSString?>(nil)
    
    fileprivate let bag = DisposeBag()
    
    let refreshControl = UIRefreshControl()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Albums Photos"
        
        refreshControl.backgroundColor = UIColor(white: 0.98, alpha: 1.0)
        refreshControl.tintColor = UIColor.darkGray
        refreshControl.attributedTitle = NSAttributedString(string: "refresh Albums")
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        
        self.collectionView?.addSubview(refreshControl)
        self.collectionView?.alwaysBounceVertical = true
        
        let albumsArray = (NSArray(contentsOf: albumsFileURL)
            as? [[String: Any]]) ?? []
        Album.sharedAlbums.value = albumsArray.flatMap(Album.init)
        
        lastModifiedAlb.value = try? NSString(contentsOf: modifiedAlbFileURL, usedEncoding: nil)
        
        refresh()
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Register cell classes
        self.collectionView!.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "PhotoHeaderCell")

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func refresh() {
        let albumQueue = DispatchQueue(label: "fetchAlbumQueue")
        albumQueue.async {
            self.fetchAlbums(dataFound: "users/\(self.userId ?? 0)/albums")
        }
    }
    
    func fetchAlbums(dataFound: String) {
        if (Reachability.isConnectedToNetwork()) {
            let response = Observable.from([dataFound])
                .map { urlString -> URL in
                    return URL(string: "\(self.URLString)\(urlString)")!
                }
                .map { [weak self] url -> URLRequest in
                    var request = URLRequest(url: url)
                    if let modifiedHeader = self?.lastModifiedAlb.value {
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
                    return objects.flatMap(Album.init)
                }
                .subscribe(onNext: { [weak self] newAlbums in
                    self?.processAlbums(newAlbums)
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
                    strongSelf.lastModifiedAlb.value = modifiedHeader
                    try? modifiedHeader.write(to: strongSelf.modifiedAlbFileURL, atomically: true,
                                              encoding: String.Encoding.utf8.rawValue)
                })
                .addDisposableTo(bag)
        } else {
            let alert = UIAlertController(title: "Pas de connexion", message: "Verifiez que vous êtes bien connecté à internet", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func processAlbums(_ newAlbums: [Album]) {
        var updatedAlbums = newAlbums + Album.sharedAlbums.value
        if updatedAlbums.count > 60 {
            updatedAlbums = Array<Album>(updatedAlbums.prefix(upTo: 60))
        }
        Album.sharedAlbums.value = updatedAlbums
        
        DispatchQueue.main.async {
            self.collectionView?.reloadData()
            self.refreshControl.endRefreshing()
        }
        
        let albumsArray = updatedAlbums.map{ $0.dictionary } as NSArray
        albumsArray.write(to: albumsFileURL, atomically: true)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        
        return Album.sharedAlbums.value.count
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of items
        
        return Album.sharedAlbums.value[section].photos.value.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! PhotoCell
    
        let url = URL(string: Album.sharedAlbums.value[indexPath.section].photos.value[indexPath.row].thumbnailUrl)
        
        cell.photoImage.kf.setImage(with: url, placeholder: UIImage(named: "User_icon"))
    
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView,
                                 viewForSupplementaryElementOfKind kind: String,
                                 at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionElementKindSectionHeader:
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                             withReuseIdentifier: "PhotoHeaderCell",
                                                                             for: indexPath) as! PhotoHeaderCell
            headerView.titleLabel.text = Album.sharedAlbums.value[indexPath.section].title
            return headerView
        default:
            assert(false, "Unexpected element kind")
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "DetailPhoto" {
            let vc = segue.destination as! DetailPhotoController
            vc.userId = self.userId
            vc.my_indexPath = (sender as? IndexPath)!
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        performSegue(withIdentifier: "DetailPhoto", sender: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let paddingSpace = sectionInsets.left * (itemsPerRow + 1)
        let availableWidth = view.frame.width - paddingSpace
        let widthPerItem = availableWidth / itemsPerRow
        
        return CGSize(width: widthPerItem, height: widthPerItem)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return sectionInsets
    }
    
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return sectionInsets.left
    }

}
