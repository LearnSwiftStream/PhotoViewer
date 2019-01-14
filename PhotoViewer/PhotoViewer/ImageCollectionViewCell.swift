//
//  ImageCollectionViewCell.swift
//  PhotoViewer
//
//  Created by Matthew Dias on 1/5/19.
//  Copyright © 2019 Matt Dias. All rights reserved.
//

import UIKit

class ImageCollectionViewCell: UICollectionViewCell {

    @IBOutlet var imageView: UIImageView!

    static let identifier = "imageCell"

    override func awakeFromNib() {
        super.awakeFromNib()

    }

    override func prepareForReuse() {
        super.prepareForReuse()
        
        imageView.image = nil
    }

}
