//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Kingfisher
import ReadiumShared
import UIKit

class OPDSPublicationTableViewCell: UITableViewCell {
    @IBOutlet var collectionView: UICollectionView!

    var feed: Feed?
    weak var opdsRootTableViewController: OPDSRootTableViewController?

    static let iPadLayoutNumberPerRow: [ScreenOrientation: Int] = [.portrait: 4, .landscape: 5]
    static let iPhoneLayoutNumberPerRow: [ScreenOrientation: Int] = [.portrait: 3, .landscape: 4]

    lazy var layoutNumberPerRow: [UIUserInterfaceIdiom: [ScreenOrientation: Int]] = [
        .pad: OPDSPublicationTableViewCell.iPadLayoutNumberPerRow,
        .phone: OPDSPublicationTableViewCell.iPhoneLayoutNumberPerRow,
    ]

    override func awakeFromNib() {
        super.awakeFromNib()
        collectionView.register(UINib(nibName: "PublicationCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "publicationCollectionViewCell")
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        collectionView.collectionViewLayout.invalidateLayout()
    }
}

extension OPDSPublicationTableViewCell: UICollectionViewDataSource {
    // MARK: - Collection view data source

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        feed?.publications.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "publicationCollectionViewCell",
                                                      for: indexPath) as! PublicationCollectionViewCell

        cell.isAccessibilityElement = true
        cell.accessibilityHint = NSLocalizedString("opds_show_detail_view_a11y_hint", comment: "Accessibility hint for OPDS publication cell")

        if let publications = feed?.publications, let publication = feed?.publications[indexPath.row] {
            cell.accessibilityLabel = publication.metadata.title

            let titleTextView = OPDSPlaceholderListView(
                frame: cell.frame,
                title: publication.metadata.title,
                author: publication.metadata.authors
                    .map(\.name)
                    .joined(separator: ", ")
            )

            let coverURL: URL? = publication.linkWithRel(.cover)?.url(relativeTo: publication.baseURL).url
                ?? publication.images.first.flatMap { URL(string: $0.href) }

            if let coverURL = coverURL {
                cell.coverImageView.kf.setImage(
                    with: coverURL,
                    placeholder: titleTextView,
                    options: [.transition(ImageTransition.fade(0.5))],
                    progressBlock: nil
                ) { _ in }
            } else {
                cell.coverImageView.addSubview(titleTextView)
            }

            cell.titleLabel.text = publication.metadata.title
            cell.authorLabel.text = publication.metadata.authors
                .map(\.name)
                .joined(separator: ", ")

            if indexPath.row == publications.count - 3 {
                opdsRootTableViewController?.loadNextPage(completionHandler: { feed in
                    self.feed = feed
                    collectionView.reloadData()
                })
            }
        }

        return cell
    }
}

extension OPDSPublicationTableViewCell: UICollectionViewDelegateFlowLayout {
    // MARK: - Collection view delegate

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        let idiom = { () -> UIUserInterfaceIdiom in
            let tempIdion = UIDevice.current.userInterfaceIdiom
            return (tempIdion != .pad) ? .phone : .pad // ignnore carplay and others
        }()

        guard let deviceLayoutNumberPerRow = layoutNumberPerRow[idiom] else { return CGSize(width: 0, height: 0) }
        guard let numberPerRow = deviceLayoutNumberPerRow[.current] else { return CGSize(width: 0, height: 0) }

        let minimumSpacing: CGFloat = 5.0
        let labelHeight: CGFloat = 50.0
        let coverRatio: CGFloat = 1.5

        let itemWidth = (collectionView.frame.width / CGFloat(numberPerRow)) - (CGFloat(minimumSpacing) * CGFloat(numberPerRow)) - minimumSpacing
        let itemHeight = (itemWidth * coverRatio) + labelHeight

        return CGSize(width: itemWidth, height: itemHeight)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let publication = feed?.publications[indexPath.row] {
            let opdsPublicationInfoViewController: OPDSPublicationInfoViewController = OPDSFactory.shared.make(publication: publication)
            opdsRootTableViewController?.navigationController?.pushViewController(opdsPublicationInfoViewController, animated: true)
        }
    }
}
