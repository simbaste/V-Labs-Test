//
//  Album.swift
//  V-Labs-Test
//
//  Created by Stephane Darcy SIMO MBA on 13/10/2017.
//  Copyright © 2017 v-Labs. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class Album {
    var id: Int
    var title: String
    
    private let URLString = "https://jsonplaceholder.typicode.com/"
    private let photosFileURL = cachedFileURL("photos.plist")
    private let modifiedPhoFileURL = cachedFileURL("modifiedPho.txt")
    
    fileprivate let lastModifiedPho = Variable<NSString?>(nil)
    fileprivate let bag = DisposeBag()
    
    public var photos = Variable<[Photo]>([])
    
    static public var sharedAlbums = Variable<[Album]>([])
    
    // MARK: - FlatMap Event -> JSON
    init?(dictionary: AnyDict) {
        guard let m_id = dictionary["id"] as? Int,
            let m_title = dictionary["title"] as? String
            else {
                return nil
        }
        
        let photosArray = (NSArray(contentsOf: photosFileURL)
            as? [[String: Any]]) ?? []
        photos.value = photosArray.flatMap(Photo.init)
        
        lastModifiedPho.value = try? NSString(contentsOf: modifiedPhoFileURL, usedEncoding: nil)
        
        id = m_id
        title = m_title
        
        loadDatas()
    }
    
    // MARK: - Event -> JSON
    var dictionary: AnyDict {
        return [
            "id": id,
            "title" : title
        ]
    }
    
    func loadDatas() {
        let photoQueue = DispatchQueue(label: "fetchPhotoQueue")
        photoQueue.async {
            self.fetchPhotos(dataFound: "albums/\(self.id)/photos")
        }
    }
    
    func fetchPhotos(dataFound: String) {
        if (Reachability.isConnectedToNetwork()) {
            let response = Observable.from([dataFound])
                .map { urlString -> URL in
                    return URL(string: "\(self.URLString)\(urlString)")!
                }
                .map { [weak self] url -> URLRequest in
                    var request = URLRequest(url: url)
                    if let modifiedHeader = self?.lastModifiedPho.value {
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
                    return objects.flatMap(Photo.init)
                }
                .subscribe(onNext: { [weak self] newPhotos in
                    self?.processPhotos(newPhotos)
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
                    strongSelf.lastModifiedPho.value = modifiedHeader
                    try? modifiedHeader.write(to: strongSelf.modifiedPhoFileURL, atomically: true,
                                              encoding: String.Encoding.utf8.rawValue)
                })
                .addDisposableTo(bag)
        }
    }
    
    func processPhotos(_ newPhotos: [Photo]) {
        var updatedPhotos = newPhotos + photos.value
        if updatedPhotos.count > 70 {
            updatedPhotos = Array<Photo>(updatedPhotos.prefix(upTo: 70))
        }
        
        photos.value = updatedPhotos
        
        let photosArray = updatedPhotos.map{ $0.dictionary } as NSArray
        photosArray.write(to: photosFileURL, atomically: true)
    }
}
