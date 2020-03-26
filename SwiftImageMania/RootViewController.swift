//
//  RootViewController.swift
//  SwiftImageMania
//
//  Created by Alex Nagy on 15/04/2019.
//  Copyright © 2019 Alex Nagy. All rights reserved.
//

import TinyConstraints
import FirebaseStorage
import FirebaseFirestore
import Kingfisher

struct MyKeys {
  static let imagesFolder = "imagesFolder"
  static let imagesCollection = "imagesCollection"
  static let uid = "uid"
  static let imageUrl = "imageUrl"
}

class RootViewController: UIViewController {
  
  // MARK: - View Elements
  lazy var takePhotoBarButtonItem = UIBarButtonItem(title: "Take", style: .done, target: self, action: #selector(takePhoto))
  
  lazy var savePhotoBarButtonItem = UIBarButtonItem(title: "Save", style: .plain, target: self, action: #selector(savePhoto))
  
  lazy var uploadPhotoBarButtonItem = UIBarButtonItem(title: "Upload", style: .done, target: self, action: #selector(uploadPhoto))
  
  lazy var downloadPhotoBarButtonItem = UIBarButtonItem(title: "Download", style: .plain, target: self, action: #selector(downloadPhoto))
  
  lazy var imagePickerController: UIImagePickerController = {
    let controller = UIImagePickerController()
    controller.delegate = self
    controller.sourceType = .camera
    return controller
  }()
  
  lazy var imageView: UIImageView = {
    let iv = UIImageView()
    iv.contentMode = .scaleAspectFill
    iv.backgroundColor = .lightGray
    return iv
  }()
  
  let activityIndicator = UIActivityIndicatorView(style: .gray)
  
  // MARK: - View Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.
    setupNavigationItem()
    setupViews()
  }
  
  // MARK: - Setup Methods
  fileprivate func setupNavigationItem() {
    navigationItem.setLeftBarButtonItems([takePhotoBarButtonItem, savePhotoBarButtonItem], animated: false)
    navigationItem.setRightBarButtonItems([uploadPhotoBarButtonItem, downloadPhotoBarButtonItem], animated: false)
  }
  
  fileprivate func setupViews() {
    view.backgroundColor = .white
    
    view.addSubview(imageView)
    view.addSubview(activityIndicator)
    
    imageView.edgesToSuperview()
    activityIndicator.centerInSuperview()
  }
  
  // MARK: - Button methods
  @objc fileprivate func takePhoto() {
    present(imagePickerController, animated: true, completion: nil)
  }
  
  @objc fileprivate func savePhoto() {
    
    // unwrap image
    guard let image = imageView.image else { return }
    activityIndicator.startAnimating()
    // Saves photo to local device
//    UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    saveToAlbum(named: "Swift 5 UIImage", image: image)
    
  }
  
  @objc fileprivate func uploadPhoto() {
    // add code here
    
    activityIndicator.startAnimating()
    
    guard let image = imageView.image, let data = image.jpegData(compressionQuality: 1.0) else {
      presentAlert(title: "Error", message: "Something went wrong")
      return
    }
    
    // Make UID
    let imageName = UUID().uuidString
    
    // Make image reference
    let imageReference = Storage.storage().reference()
      .child(MyKeys.imagesFolder)
      .child(imageName)
    
    imageReference.putData(data, metadata: nil) { (metadata, error) in
      if let error = error {
        self.presentAlert(title: "Error", message: error.localizedDescription)
        return
      }
      
      imageReference.downloadURL { (url, error) in
        if let error = error {
          self.presentAlert(title: "Error", message: error.localizedDescription)
          return
        }
        
        guard let url = url else {
          self.presentAlert(title: "Error", message: "Something went wrong")
          return
        }
        
        // create data reference to firestore
        let dataReference = Firestore.firestore().collection(MyKeys.imagesCollection).document()
        let documentUID = dataReference.documentID
        let urlString = url.absoluteString
        
        // mock data
        let data = [
          MyKeys.uid: documentUID,
          MyKeys.imageUrl: urlString
        ]
        
        dataReference.setData(data) { (error) in
          if let error = error {
            self.presentAlert(title: "Error", message: error.localizedDescription)
            return
          }
          
          UserDefaults.standard.set(documentUID, forKey: MyKeys.uid)
          self.imageView.image = UIImage()
          self.presentAlert(title: "Success", message: "Successfully saved image to database")
        }
      }
    }
  }
  
  @objc fileprivate func downloadPhoto() {
    
    activityIndicator.startAnimating()
    
    guard let uid = UserDefaults.standard.value(forKey: MyKeys.uid) else {
      self.presentAlert(title: "Error", message: "Something went wrong")
      return
    }
    
    let query = Firestore.firestore()
      .collection(MyKeys.imagesCollection)
      .whereField(MyKeys.uid, isEqualTo: uid)
    
    query.getDocuments { (snapshot, error) in
      if let error = error {
        self.presentAlert(title: "Error", message: error.localizedDescription)
        return
      }
      
      guard let snapshot = snapshot,
        let data = snapshot.documents.first?.data(),
        let urlString = data[MyKeys.imageUrl] as? String,
        let url = URL(string: urlString) else {
        self.presentAlert(title: "Error", message: "There was an error")
        return
      }
      
      let resource = ImageResource(downloadURL: url)
      self.imageView.kf.setImage(with: resource) { (result) in
        switch result {
        case .success(_):
          self.presentAlert(title: "Success", message: "Successfully downloaded from the database")
        case .failure(let error):
          self.presentAlert(title: "Error", message: error.localizedDescription)
        }
      }
    }
  }
  
  func saveToAlbum(named: String, image: UIImage) {
    // add code here
    
    let album = CustomAlbum(name: named)
    album.save(image: image) { (result) in
      DispatchQueue.main.async {
        switch result {
        case .success(_):
          self.presentAlert(title: "Success!", message: "Successfully saved photo to album \"\(named)")
        case .failure(let error):
          self.presentAlert(title: "Error", message: error.localizedDescription)
        }
      }
    }
  }
  
  @objc func image(_ image: UIImage, didFinishSavingWithError err: Error?, contextInfo: UnsafeRawPointer) {
    activityIndicator.stopAnimating()
    if let err = err {
      // we got back an error!
      presentAlert(title: "Error", message: err.localizedDescription)
    } else {
      presentAlert(title: "Saved!", message: "Image saved successfully")
    }
  }
  
  func presentAlert(title: String, message: String) {
    activityIndicator.stopAnimating()
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    present(alert, animated: true)
  }
  
}

extension RootViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    guard let selectedImage = info[.originalImage] as? UIImage else {
      print("Image not found!")
      return
    }
    imageView.image = selectedImage
    imagePickerController.dismiss(animated: true, completion: nil)
  }
}

