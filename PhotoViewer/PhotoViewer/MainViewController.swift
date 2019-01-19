//
//  MainViewController.swift
//  PhotoViewer
//
//  Created by Matthew Dias on 1/5/19.
//  Copyright © 2019 Matt Dias. All rights reserved.
//

import UIKit
import Photos

enum SourceOptions: String {
    case local = "Your Photo Library"
    case aww = "reddit/r/aww"
    case earth = "reddit/r/earthPorn"

    static func url(for option: SourceOptions) -> URL? {
        switch option {
        case .local:
            return nil
        case .aww:
            return URL(string: "http://www.reddit.com/r/aww.json")
        case .earth:
            return URL(string: "http://www.reddit.com/r/earthPorn.json")
        }
    }

    static let allValues: [SourceOptions] = [.local, .aww, .earth]
}

class MainViewController: UIViewController {
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var collectionView: UICollectionView!
    @IBOutlet var sourceTextField: UITextField!

    var allPhotos = [UIImage]()
    let sourcePicker = UIPickerView()

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(UINib(nibName: "ImageCollectionViewCell", bundle: Bundle.main), forCellWithReuseIdentifier: ImageCollectionViewCell.identifier)

        sourcePicker.dataSource = self
        sourcePicker.delegate = self

        sourceTextField.text = SourceOptions.local.rawValue
        sourceTextField.inputView = sourcePicker

        PHPhotoLibrary.requestAuthorization { status in
            switch status {
            case .authorized:
                self.getAllPhotos()
            case .denied, .restricted:
                print("Not allowed")
            case .notDetermined:
                // Should not see this when requesting
                print("Not determined yet")
            }
        }
    }

    func getAllPhotos() {
        self.allPhotos = []
        let fetchOptions = PHFetchOptions()
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        assets.enumerateObjects { (asset, _, _) in
            self.getImage(for: asset) { (image) in
                guard let image = image else { return }

                self.allPhotos.append(image)

                if self.allPhotos.count == assets.count {
                    self.initialCollectionSetup()
                }
            }
        }
    }

    func initialCollectionSetup() {
        DispatchQueue.main.async {
            self.collectionView.reloadData()

            guard self.allPhotos.count > 0 else { return }

            self.imageView.image = self.allPhotos.first
        }
    }

    func getImage(for asset: PHAsset, completion: @escaping (UIImage?) -> ()) {
        let options = PHImageRequestOptions()
        options.resizeMode = PHImageRequestOptionsResizeMode.exact
        options.deliveryMode = PHImageRequestOptionsDeliveryMode.opportunistic
        options.isSynchronous = false

        let manager = PHImageManager.default()
        manager.requestImage(for: asset,
                             targetSize: CGSize(width: 343, height: 240),
                             contentMode: .aspectFill,
                             options: options, resultHandler: { (image, dict) in
                                if (dict?["PHImageResultIsDegradedKey"] as? Int) == 0 {
                                    completion(image)
                                }
        })
    }

    func getPhotos(for url: URL) {

        self.allPhotos = []
        let task = URLSession.shared.dataTask(with: url) { (data, _, error) in

            guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: .mutableLeaves) as? [String: AnyObject] else { return }
            guard let postData = json?["data"] as? [String: AnyObject],
                let posts = postData["children"] as? [[String: AnyObject]] else { return }

            var imageUrls = [String]()

            for post in posts {
                guard let postData = post["data"] as? [String: AnyObject] else { return }

                if let url = postData["url"] as? String, url.contains(".jpg") || url.contains(".png") || url.contains(".gif") && !url.contains(".gifv") {
                    imageUrls.append(url)
                }
            }

            let group = DispatchGroup()
            for imageUrlString in imageUrls {
                guard let imageUrl = URL(string: imageUrlString) else { return }
                group.enter()
                let subTask = URLSession.shared.dataTask(with: imageUrl) { (imageData, _, error) in
                    group.leave()
                    guard let imageData = imageData, let image = UIImage(data: imageData) else { return }
                    self.allPhotos.append(image)
                }
                subTask.resume()
            }

            group.notify(queue: DispatchQueue.main, execute: {
                self.initialCollectionSetup()
            })
        }

        task.resume()
    }

}

// MARK: - UIPickerViewDataSource
extension MainViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return SourceOptions.allValues.count
    }
}

// MARK: - UIPickerViewDelegate
extension MainViewController: UIPickerViewDelegate {

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        guard row < SourceOptions.allValues.count else { return nil }

        return SourceOptions.allValues[row].rawValue
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        guard row < SourceOptions.allValues.count else { return }
        let selectedOption = SourceOptions.allValues[row]

        sourceTextField.text = selectedOption.rawValue
        sourceTextField.resignFirstResponder()

        if selectedOption == .local {
            getAllPhotos()
        } else if let url = SourceOptions.url(for: selectedOption) {
            getPhotos(for: url)
        }
    }
}

// MARK: - UICollectionViewDataSource
extension MainViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return allPhotos.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCollectionViewCell.identifier, for: indexPath) as? ImageCollectionViewCell else {
            print("bad cell")
            return UICollectionViewCell()
        }

        cell.imageView.image = allPhotos[indexPath.row]

        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension MainViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        self.imageView.image = allPhotos[indexPath.row]
    }
}
