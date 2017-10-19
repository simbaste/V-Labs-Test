//
//  DetailPhotoControllerViewController.swift
//  V-Labs-Test
//
//  Created by Stephane Darcy SIMO MBA on 13/10/2017.
//  Copyright © 2017 v-Labs. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift
import Foundation

enum DirectionScroll {
    case DirectionLeft
    case DirectionRight
    case none
}

class DetailPhotoController: UIViewController, UIScrollViewDelegate {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var commentTexiField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var textFieldConstraint: NSLayoutConstraint!
    
    public var my_indexPath: IndexPath = []
    public var userId: Int?
    
    private var lastContentOffset: CGFloat = 0
    private var direction: DirectionScroll = .none
    private var keyboardHeight: CGFloat = 258.0
    
    fileprivate let bag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.delegate = self
        
        sendButton.isEnabled = false
        sendButton.layer.cornerRadius = 10
        textFieldConstraint.constant = 384
        scrollView.isScrollEnabled = true
        scrollView.isPagingEnabled = true
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: Notification.Name.UIKeyboardDidShow, object: nil)
        loadData()
        fetchTextField()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func keyboardWillShow(_ notification: Notification) {
        if let keyboardFrame: NSValue = notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue {
            let keyboardRectangle = keyboardFrame.cgRectValue
            self.keyboardHeight = keyboardRectangle.height
        }
    }
    
    func fetchTextField() {
        let section = self.my_indexPath.section
        commentTexiField.rx.controlEvent([.editingDidEndOnExit])
            .subscribe({text in
                self.commentTexiField.resignFirstResponder()
                self.textFieldConstraint.constant = 384
                self.sendButton.isEnabled = !(self.commentTexiField.text?.isEmpty)!
            }).addDisposableTo(bag)
        
        commentTexiField.rx.controlEvent([.editingDidBegin])
            .subscribe(onNext: { _ in
                self.sendButton.isEnabled = !(self.commentTexiField.text?.isEmpty)!
                
                self.textFieldConstraint.constant = self.view.frame.height - (self.keyboardHeight + 110)
        }).addDisposableTo(bag)
        
        sendButton.rx.tap.subscribe(onNext: { _ in
            if (Reachability.isConnectedToNetwork()) {
                let url = URL(string: "http://jsonplaceholder.typicode.com/posts")
                var urlRequest = URLRequest(url: url!)
                urlRequest.httpMethod = "POST"
                let dict: [String: Any] = [
                    "title": Album.sharedAlbums.value[section].photos.value[(self.my_indexPath.row)].title,
                    "body" : self.commentTexiField.text ?? "",
                    "userId": self.userId ?? 0
                    ]
                
                do {
                    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: dict, options: [])
                    urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
                    URLSession.shared.dataTask(with: urlRequest, completionHandler: {data, response, error in
                        
                        if error != nil {
                            print(error ?? "Error")
                        }
                        do {
                            let json = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers)
                            let alertCommentHandler = { (action:UIAlertAction!) -> Void in
                                self.commentTexiField.text = ""
                                self.sendButton.isEnabled = false
                            }
                            let alert = UIAlertController(title: "Message Envoyé", message: "Votre commentaire a bien été transmis", preferredStyle: UIAlertControllerStyle.alert)
                            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: alertCommentHandler))
                            self.present(alert, animated: true, completion: nil)
                            print(json)
                        } catch let jsonError {
                            print(jsonError)
                        }
                    }).resume()
                } catch let jsonError {
                    print(jsonError)
                }
            } else {
                let alert = UIAlertController(title: "Pas de connexion", message: "Verifiez que vous êtes bien connecté à internet", preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }).addDisposableTo(bag)
        
    }
    
    func loadData() {

        for i in 0..<Album.sharedAlbums.value[my_indexPath.section].photos.value.count {
            
            let imageView = UIImageView()
            let url = URL(string: Album.sharedAlbums.value[my_indexPath.section].photos.value[i].thumbnailUrl)
            imageView.kf.setImage(with: url, placeholder: #imageLiteral(resourceName: "User_icon"))
            imageView.contentMode = .scaleAspectFit
            let xPos = self.view.frame.width * CGFloat(i)
            imageView.frame = CGRect(x: xPos, y: 0, width: self.scrollView.frame.width, height: self.scrollView.frame.height)
            scrollView.contentSize = CGSize(width: view.frame.width * CGFloat(i + 1), height: self.scrollView.frame.height)
            scrollView.addSubview(imageView)
        }
        let contentOffset = CGPoint(x: (self.view.frame.width * CGFloat(my_indexPath.row)), y: 0)
        scrollView.setContentOffset(contentOffset, animated: false)
        
        title = Album.sharedAlbums.value[my_indexPath.section].title
        titleLabel.text = Album.sharedAlbums.value[my_indexPath.section].photos.value[my_indexPath.row].title

    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        direction = (lastContentOffset > scrollView.contentOffset.x) ? .DirectionRight : .DirectionLeft
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let a = fabs(Double(CGFloat(lastContentOffset - scrollView.contentOffset.x)))
        if (a > 0.0 && (my_indexPath.row < Album.sharedAlbums.value.count)) {
            my_indexPath.row = (direction == .DirectionLeft) ? (my_indexPath.row+1) : (my_indexPath.row-1)
            titleLabel.text = Album.sharedAlbums.value[my_indexPath.section].photos.value[my_indexPath.row].title
        }
        lastContentOffset = scrollView.contentOffset.x
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
